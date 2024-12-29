// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HexTiles {
    struct Point {
        int x;
        int y;

    }
    modifier validPoint(Point memory p) {
        require( (p.x + p.y) & 1 == 0 , "Invalid point");
        _;
    }
    
    // Check if two points are adjacent
    function areAdjacent(Point memory p1, Point memory p2) public pure  validPoint(p1) validPoint(p2) returns (bool){
        int dx = p1.x - p2.x;
        int dy = p1.y - p2.y;
        
        if (dx == 0 && abs(dy) == 2 ){
            return true;
        }else if (abs(dx) == 1 && abs(dy) == 1){
            return true;
        } else {
            return false;
        }
    }
    
    // Determine which ring the point belongs to
    function ringNumber(Point memory p) public pure validPoint(p)  returns (uint) {
         
        int dx = p.x;
        int dy = p.y;
        if(abs(dx) >= abs(dy)) {
            return uint(abs(dx));
        } else {
            return  uint ((abs(dx)+abs(dy))/2);
        }
    }

    function ringTotalTiles(uint ring) public pure returns (uint) {
        if(ring == 0) {
            return 1;
        }else{
            return ring*6;
        }
    }
    
    // Helper function to find the absolute value of an integer
    function abs(int x) internal pure returns (int) {
        return x >= 0 ? x : -x;
    }
}


contract HexMap is HexTiles {
    enum LandStatus { Unopened,Occupied }
    struct Land {
        LandStatus status;
        address owner;
        uint32 lastUpdated;
        uint32 protectTimeTs;
        uint256 unionId;
        uint initPrice;
        uint currentPrice;
        bool frozen;
    }

    event RingUnlocked(string seasonId, uint ringNumber, uint unlockTs);
    event LandUpdated(string seasonId,Point p, LandStatus status, address owner,uint32 lastUpdated, uint256 unionId, uint256 initPrice,uint256 currentPrice, uint256 protectTimeTs);


    address constant ZERO_ADDRESS = address(0);
    string   public seasonId ;
    uint256  constant maxRing = 5;

    mapping(int => Land) public lands;
    mapping(uint256=>uint32) public ringUnlockTs;
    mapping(uint256=>uint256) public ringUnlockTileCount;




    constructor(string memory _seasonId,uint256 startTs) {
        seasonId = _seasonId;
        setInitPos(Point(5,5),1);
        setInitPos(Point(-5,5),2);
        setInitPos(Point(-5,-5),3);
        setInitPos(Point(5,-5),4);

        for(uint i = 0; i < maxRing; i++) {
            ringUnlockTs[i] = uint32(startTs + calcRingUnlockedTs(i,maxRing));
        }
        ringUnlockTs[maxRing] = uint32(startTs + calcRingUnlockedTs(maxRing,maxRing));
    }


    function encodePoint(Point memory p) public pure returns (int) {
        return (p.x << 32) | (p.y & 0xFFFFFFFF);
    }


    function unlockLand(Point memory p,Point memory rp,address owner,uint256 unionId,uint256 currentPrice,uint256 protectTimeTs) internal {
        // Check p not exceed maxRing
        require(ringNumber(p) <= maxRing, "Ring exceeds maxRing");
        // Check if the ring is unlocked
        require(ringUnlockTs[ringNumber(rp)] <= block.timestamp, "Ring is locked");
        // Check if the land is adjacent
        require(areAdjacent(p,rp), "Land is not adjacent");
        // Check if the land is not frozen
        require(!lands[encodePoint(p)].frozen, "Land is frozen");

        Land storage refland = lands[encodePoint(rp)];
        require(refland.status == LandStatus.Occupied, "Land is not occupied");
        require(refland.unionId  == unionId, "UnionId is not correct");

        Land storage land = lands[encodePoint(p)];
        if(land.status == LandStatus.Occupied) {
            require( land.lastUpdated + land.protectTimeTs  <= block.timestamp, "Land is in protect time");
        }


        // 
        if(land.status == LandStatus.Unopened) {
            uint ring = ringNumber(p);
            ringUnlockTileCount[ring] += 1;
            if (ringUnlockTileCount[ring] > ringTotalTiles(ring) *6/10 ) {
                if(ring >0 && ringUnlockTs[ring-1] == 0) {
                    //unlock next ring
                    ringUnlockTs[ring-1] = uint32(block.timestamp);
                    emit RingUnlocked(seasonId,ring-1,block.timestamp);
                }
            }
            land.status = LandStatus.Occupied;
            land.initPrice = currentPrice;
        }
        //DO occupy
        land.owner = owner;
        land.unionId = unionId;
        land.lastUpdated = uint32(block.timestamp);
        land.currentPrice = currentPrice;
        land.protectTimeTs = uint32(protectTimeTs * ringNumber(p));

        emit LandUpdated(seasonId,p, land.status, land.owner,land.lastUpdated,land.unionId,land.initPrice,land.currentPrice,land.protectTimeTs);
    }

    function setInitPos(Point memory p,uint256 unionId) internal {
        //init pos
        Land storage land = lands[encodePoint(p)];
        land.status = LandStatus.Occupied;
        land.owner = ZERO_ADDRESS;
        land.unionId = unionId;
        land.lastUpdated = uint32(block.timestamp);
        land.frozen = true;
    }

    function calcRingUnlockedTs(uint ring,uint256 _maxRing) internal pure returns (uint256) {
        return  (_maxRing-ring) * 1800  + 300;
    }
}

contract AuctionMap is HexMap {


   // 总股权数
    uint256 public totalShares;
    // 每股分红系数
    uint256 public dividendPerShare;

    uint256 public constant decayInterval = 300; // 600 seconds
    uint256 public constant decayFactor = 10; // price is divided by 10 each interval
    uint256 public constant maxPriceFactor = 90; // minimum price is 0.1x of initial price

    uint256 public constant dividentPoolRatio = 35;
    uint256 public constant unionPoolRatio = 10;
    uint256 public constant finalPoolRatio = 45;
    uint256 public constant devPoolRatio = 5;
    uint256 public constant nextGamePoolRatio = 5;


    uint256 public  fortressTakenSecond = 3600 * 8 ;



    uint256 public immutable startTime;

    uint256 public totalFinalPoolValue;
    uint256 public totalDevPoolValue;
    uint256 public totalNextGamePoolValue;
    uint256 public totalUnionPoolValue;

    address public winnerAddress;
    uint256 public winnerUnionId;


    // 每个用户的股权
    mapping(address => uint256) public userShares;
    // 每个用户的调整值
    mapping(address => int256) public userDividendAdjust;

    //
    mapping(address => uint256) public userWithdrawedFinalAt;
    mapping(uint256 => uint256) public unionTotalShares;
    // 分红提取事件
    event DividendWithdrawn(string seasonId,address indexed user, uint256 amount);

    event DividendAdded(string seasonId,uint256 amount);

    // 股权转让事件
    event SharesTransferred(string seasonId,address indexed from, address indexed to, uint256 amount);

    event GameEnded(string seasonId,address winnerAddress,uint256 winnerUnionId);

    event FortressTakenSecondChanged(string seasonId,uint256 beforeValue,uint256 afterValue);

   
    constructor(string memory _seasonId,uint256 _startTs) HexMap(_seasonId,_startTs) {
        startTime = _startTs;
    }

    function getPoolConfig() public view returns (uint256,uint256,uint256,uint256,uint256) {
        return (dividentPoolRatio,unionPoolRatio,finalPoolRatio,devPoolRatio,nextGamePoolRatio);
    }
    function getPoolValue() public view returns (uint256,uint256,uint256,uint256) {
        return (totalFinalPoolValue,totalDevPoolValue,totalUnionPoolValue,totalNextGamePoolValue);
    }

    function buyLand(Point memory p,Point memory rp,uint256 unionId, uint256 value,address from ) internal   {
        (bool ended,, ,) = isGameEnded();
        if (ended) {
            return;
        }
        (uint256 lastLandPrice, uint256 landPrice,uint256 ratio,uint256 shares,bool isNewLand,address lastOwner,uint256 lastUnionId) = getlandInfo(p);
        require(value >= landPrice, "Insufficient payment");
        // transfer back reset 
        if(value > landPrice) {
            payable(from).transfer(value - landPrice);
        }
        uint256 restValue = landPrice;
        if(!isNewLand) {
            restValue -= lastLandPrice;
            //transfer back last owner
            payable(lastOwner).transfer(lastLandPrice);
        }

        unlockLand(p,rp,from,unionId,landPrice,300 * ratio / 100 );
        addToPools(restValue);

        transferShares(lastOwner,from,shares);

        // update union shares
        if (lastOwner != ZERO_ADDRESS) {
            unionTotalShares[lastUnionId] -= shares;
        }
        unionTotalShares[unionId] += shares;

        if(p.x == 0 && p.y == 0) {
            uint256 before = fortressTakenSecond;
            uint256 elapsed = block.timestamp - startTime;
            fortressTakenSecond =  (120 ether) * 3600 * 8 * 9000 / ( elapsed ) / landPrice /1;
            emit FortressTakenSecondChanged(seasonId,before,fortressTakenSecond);
        }
    }


    // 提取分红
    function withdrawDividends(address from) internal {
        uint256 withdrawableDividend = calculateWithdrawableDividend(from);
        require(withdrawableDividend > 0, "No dividends to withdraw");

        // 更新用户的调整值
        userDividendAdjust[from] = int256(userShares[from] * dividendPerShare);

        payable(from).transfer(withdrawableDividend);
        emit DividendWithdrawn(seasonId,from, withdrawableDividend);
    }

     function withdrawFinal(address from,uint256 unionId) internal {
        (bool ended,address _winnerAddress ,uint256 _winnerUnionId,) = isGameEnded();
        if (ended){
            //not set
            if (winnerAddress == ZERO_ADDRESS || winnerUnionId == 0) {
                winnerAddress = _winnerAddress;
                winnerUnionId =  _winnerUnionId;

                emit GameEnded(seasonId, winnerAddress,winnerUnionId);
            }

            require(unionId == winnerUnionId, "Not winner union");
            require(userWithdrawedFinalAt[from] == 0, "Already withdrawed");

            uint256 totalUnionShares = unionTotalShares[unionId];
            uint256 value = userShares[from] * totalUnionPoolValue / totalUnionShares;
            if (from == winnerAddress) {
                value += totalFinalPoolValue;
            }

            payable(from).transfer(value);
            userWithdrawedFinalAt[from] = block.timestamp;
        }

    }



    function isGameEnded() internal view returns (bool, address,uint256,uint256) {
        Land storage land = lands[encodePoint(Point(0,0))];
        if(land.status == LandStatus.Occupied && block.timestamp - land.lastUpdated > fortressTakenSecond) {
            return (true,land.owner,land.unionId,0);
        }else{
            return (false,ZERO_ADDRESS,0,land.lastUpdated + fortressTakenSecond);
        }
    }

    // 查询可提取的分红
    function calculateWithdrawableDividend(address user) internal view returns (uint256) {
        return uint256(int256(userShares[user] * dividendPerShare) - userDividendAdjust[user]);
    }

    // 股权转让
    function transferShares(address from,address to, uint256 amount) internal {
        // 更新调整值
        if (from != ZERO_ADDRESS){
            require(userShares[from] >= amount, "Insufficient shares");
            userShares[from] -= amount;
            userDividendAdjust[from] -= int256(amount * dividendPerShare);
        }else{
            totalShares += amount;
        }

        userShares[to] += amount;
        userDividendAdjust[to] += int256(amount * dividendPerShare);

        emit SharesTransferred(seasonId,from, to, amount);
    }

    function addToPools(uint256 amount) internal {
        uint256 dividends = amount * dividentPoolRatio / 100;
        uint256 finalPool = amount * finalPoolRatio / 100;
        uint256 devPool = amount * devPoolRatio / 100;
        uint256 nextGamePool = amount * nextGamePoolRatio / 100;
        uint256 unionPool = amount * unionPoolRatio / 100;

        totalFinalPoolValue += finalPool;
        totalNextGamePoolValue += nextGamePool;
        totalDevPoolValue += devPool;
        totalUnionPoolValue += unionPool;

        addDividends(dividends);
    }
    // 内部函数：处理分红
    function addDividends(uint256 amount) internal {
        if (totalShares > 0) {
            dividendPerShare += amount / totalShares;
            emit DividendAdded(seasonId,amount);
        }
    }



    function getlandInfo(Point memory p) internal view returns (uint256,uint256,uint256,uint256,bool,address,uint256) {
        Land storage land = lands[encodePoint(p)];
        uint256 ring = ringNumber(p);
        uint256 elapsed;
        if( land.status == LandStatus.Unopened) {
            elapsed = block.timestamp - ringUnlockTs[ring];
        }else{
            if (block.timestamp > land.lastUpdated + land.protectTimeTs) {
                elapsed = block.timestamp - land.lastUpdated- land.protectTimeTs;
            }else{
                elapsed = 0; //not expired
            }
        }
        uint256 decaySteps = elapsed / decayInterval;
        uint256 currentPriceFactor = decayFactor*decaySteps;
        if (currentPriceFactor > maxPriceFactor) {
            currentPriceFactor = maxPriceFactor;
        }

        uint256 landShare =  40*(maxRing - ring) + 10;


        uint256 ratio = 100 - currentPriceFactor;
        if(land.status == LandStatus.Occupied) {
            return (land.currentPrice,land.currentPrice * (ratio+100) / 100 ,ratio,landShare,false,land.owner,land.unionId);
        }else{
            return  (land.currentPrice, (( 4 ether* (maxRing - ring) + 10 ether)* ratio/ 100 )/1, ratio,landShare,true,ZERO_ADDRESS,0);
        }
    }
    
    function withdrawAll(address to) internal {
        payable(to).transfer(address(this).balance);
    }

}

contract LotGame is AuctionMap {
    address immutable public proxyAddress;

    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(string memory _seasonId,address _proxyAddress,uint256 _startTs ) AuctionMap(_seasonId,_startTs) {
        proxyAddress = _proxyAddress;
        //init map
    }

    function buyLandByProxy(Point memory p,Point memory rp,uint256 unionId, uint256 value,address from ) public payable onlyProxy {
        buyLand(p,rp,unionId,value,from);
    }

    function withdrawDividendsByProxy(address from) public onlyProxy {
        withdrawDividends(from);
    }

    function withdrawFinalByProxy(address from,uint256 unionId) public onlyProxy {
        withdrawFinal(from,unionId);
    }

    function withdrawAllByProxy(address to) public onlyProxy {
        withdrawAll(to);
    }

    function addFinalPool() public payable onlyProxy {
        totalFinalPoolValue += msg.value;
    }

    // helper function

    function getLand(Point memory p) public view returns (uint256 currLandPrice,uint256 nextLandPrice,uint256 ratio,uint256 shares,bool isNewLand,address owner,uint256 unionId,uint256 protectTimeTs,uint256 lastUpdatedAt) {
        (currLandPrice,nextLandPrice,ratio,shares,isNewLand,owner,unionId )= getlandInfo(p);
        Land storage land = lands[encodePoint(p)];
        protectTimeTs = land.protectTimeTs;
        lastUpdatedAt = land.lastUpdated;
    }

    function getGameInfo() public view returns  (bool _gameEnded,address _winnerAddress,uint256 _winnerUnionId,uint256 _totalShares,uint256 _dividendPerShare,uint256 _totalFinalPoolValue,uint256 _totalDevPoolValue,uint256 _totalNextGamePoolValue,uint256 _totalUnionPoolValue,uint256 _fortressTakenFinishTs) {
        (_gameEnded,_winnerAddress,_winnerUnionId,_fortressTakenFinishTs) = isGameEnded();
        _totalShares = totalShares;
        _dividendPerShare = dividendPerShare;
        _totalFinalPoolValue = totalFinalPoolValue;
        _totalDevPoolValue = totalDevPoolValue;
        _totalNextGamePoolValue = totalNextGamePoolValue;
        _totalUnionPoolValue = totalUnionPoolValue;
    }

    function getShareInfo(address from,uint256 unionId) public view returns  ( uint256 totalShare,uint256 unionTotalShare, uint256 totalDivident){
        totalShare = userShares[from];
        unionTotalShare = unionTotalShares[unionId];
        totalDivident = calculateWithdrawableDividend(from);
    }

    function getUnlockedRingTs(uint ring) public view returns (uint256) {
        return ringUnlockTs[ring];
    }
}


interface IGameFactory {
    function createGame(string memory seasonId,uint256 startTs) external returns (LotGame);
}

contract GameFactory is IGameFactory {

    address public immutable  proxyAddress;
    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(address _proxyAddress){
        proxyAddress = _proxyAddress;
    }

    function createGame(string memory seasonId,uint256 startTs) public override onlyProxy returns (LotGame)   {
        return new LotGame(seasonId,address(proxyAddress),startTs);
    }
}

contract LotSeasonManager {
    address public _owner;

    IGameFactory public factory;

    mapping(string => LotGame) public seasonGameMap;
    mapping(string => mapping(address=>uint)) public seasonUnionInfo;
    mapping(string => mapping(uint=>uint)) public seasonUnionMemberCnt;
    mapping(string=> uint256) seasonRegistryFee;

    event SeasonCreated(string seasonId,address gameAddress,uint256 startTs,uint256 registryFee);
    event PlayerJoined(string seasonId,address user,uint256 unionId);
    event PlayerBuyLand(string seasonId,address user,HexMap.Point p,uint256 value);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner can call this function");
        _;
    }

    modifier onlyGame(string memory seasonId) {
        require(address(seasonGameMap[seasonId]) != address(0), "Season not exists");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function setFactory(IGameFactory _factory) public onlyOwner {
        factory = _factory;
    }

    //TODO: add onlyOwner and init reward
    function createSeason(string memory seasonId,uint256 startTs,uint256 registryFee) public payable  {
        require(address(seasonGameMap[seasonId]) == address(0), "Season already exists");
        LotGame game = factory.createGame(seasonId,startTs);
        seasonGameMap[seasonId] = game;
        seasonRegistryFee[seasonId] = registryFee;

        game.addFinalPool{value: msg.value}();

        emit SeasonCreated(seasonId,address(game),startTs,registryFee);
    }


    function joinUnion(string memory seasonId,uint256 unionId)  public payable onlyGame(seasonId) {
        require(unionId >0 && unionId < 5, "Invalid unionId");
        require(seasonUnionInfo[seasonId][msg.sender] == 0, "User already in union");
        seasonUnionInfo[seasonId][msg.sender] = unionId;
        seasonUnionMemberCnt[seasonId][unionId] += 1;

        uint256 registryFee = seasonRegistryFee[seasonId];
        require(msg.value >= registryFee, "Insufficient registry fee");
        if(msg.value > registryFee) {
            payable(msg.sender).transfer(msg.value - registryFee);
        }
        
        emit PlayerJoined(seasonId,msg.sender,unionId);
    }

    // call LotGame function
    function buyLand(string memory seasonId,LotGame.Point memory p,LotGame.Point memory rp ) public payable onlyGame(seasonId) {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.buyLandByProxy{value: msg.value}(p,rp,unionId,msg.value,msg.sender);

        emit PlayerBuyLand(seasonId,msg.sender,p,msg.value);
    }

    function withdrawDividends(string memory seasonId) public onlyGame(seasonId) {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawDividendsByProxy(msg.sender);
    }

    function withdrawFinal(string memory seasonId) public onlyGame(seasonId){
        LotGame game = LotGame(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawFinalByProxy(msg.sender,unionId);
    }

    function withdrawAll(string memory seasonId) public onlyOwner {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        game.withdrawAllByProxy(_owner);
    }

    function withdrawAllFee() public onlyOwner {
        payable(_owner).transfer(address(this).balance);
    }

    function getUnionInfo(string memory seasonId,address from) public view returns (uint256 unionId,uint256[] memory unionMemberCnt) {

        unionId = seasonUnionInfo[seasonId][from];
        unionMemberCnt = new uint256[](4);
        for(uint i = 0; i < 4; i++) {
            unionMemberCnt[i] = seasonUnionMemberCnt[seasonId][i+1];
        }
    }

    function getLandInfo(string memory seasonId,LotGame.Point memory p) public view returns (uint256 currLandPrice,uint256 nextLandPrice,uint256 ratio,uint256 shares,bool isNewLand,address owner,uint256 unionId,uint256 protectTimeTs,uint256 lastUpdatedAt) {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        return game.getLand(p);
    }

    function getGameInfo(string memory seasonId) public view returns  (bool gameEnded,address winnerAddress,uint256 winnerUnionId,uint256 totalShares,uint256 dividendPerShare,uint256 totalFinalPoolValue,uint256 totalDevPoolValue,uint256 totalNextGamePoolValue,uint256 totalUnionPoolValue,uint256 fortressTakenFinishTs) {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        return game.getGameInfo();
    }

    function getShareInfo(string memory seasonId,address from,uint256 unionId) public view returns  ( uint256 totalShare,uint256 unionTotalShare, uint256 totalDivident){
        LotGame game = LotGame(seasonGameMap[seasonId]);
        (totalShare,unionTotalShare,totalDivident) = game.getShareInfo(from,unionId);
    }

    function getUnlockedRingTs(string memory seasonId,uint ring) public view returns (uint256) {
        LotGame game = LotGame(seasonGameMap[seasonId]);
        return game.getUnlockedRingTs(ring);
    }

    
}