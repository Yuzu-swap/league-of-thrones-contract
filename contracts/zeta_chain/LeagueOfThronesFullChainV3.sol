// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './LeagueOfThronesFullChain.sol';
address constant GAS_TOKEN_ADDR = 0x0000000000000000000000000000000000000000;


contract LandPointHexMap is HexMap {
    mapping(address => uint256 ) public userLandPoints;
    mapping(int => uint256 ) public userLandPointsLastUpdated;

    event LandPointAdded(address indexed user,uint256 delta,uint256 afterValue,HexMap.Point p);
    constructor(string memory _seasonId,uint256 _startTs) HexMap(_seasonId,_startTs) {
    }


    function getPendingLandPoint(Point memory p) public view returns (uint256) {
        if (lands[encodePoint(p)].status == LandStatus.Occupied) {  
            uint256 lastUpdated = userLandPointsLastUpdated[encodePoint(p)];
            return getLandPointIncrValue(p,block.timestamp-lastUpdated);
        }
        return 0;
    }
    //claim land point
    function claimLandPoint(address user,Point memory p) internal {
        //check user has land
        require(lands[encodePoint(p)].status == LandStatus.Occupied, "Land not occupied");
        require(lands[encodePoint(p)].owner == user, "User not owner");

        uint256 lastUpdated = userLandPointsLastUpdated[encodePoint(p)];
        addLandPoint(user,p,block.timestamp-lastUpdated);
        userLandPointsLastUpdated[encodePoint(p)] = block.timestamp;
    }

    function claimLandPoints(address user,Point[] memory ps) internal {
        for(uint i = 0; i < ps.length; i++) {
            claimLandPoint(user,ps[i]);
        }
    }

    function addLandPoint(address user,Point memory p,uint256 secondDelta) internal {
        uint256 incrValue = getLandPointIncrValue(p,secondDelta);
        userLandPoints[user] += incrValue;
        emit LandPointAdded(user,incrValue,userLandPoints[user],p);
    }   
    //get land point increment speed
    //地块积分数量（每分钟）=向下取整[4*（5-地块所在当前的圈）+1]
    function getLandPointIncrValue(Point memory p,uint256 secondDelta) internal view returns (uint256) {
        return (4*(5-ringNumber(p)) + 1) * secondDelta / 60;
    }
}

contract AuctionMapV3 is LandPointHexMap {


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

    address public immutable tokenAddr;
    uint256 public immutable paramsEffect ;

    uint256 public withdrawedDevAt;
    uint256 public withdrawedNextPoolAt;

    
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

   
    constructor(string memory _seasonId,uint256 _startTs,address _tokenAddr,uint256 _paramsEffect) LandPointHexMap(_seasonId,_startTs) {
        startTime = _startTs;
        tokenAddr = _tokenAddr;
        paramsEffect = _paramsEffect;
    }

    function getPoolConfig() public view returns (uint256,uint256,uint256,uint256,uint256) {
        return (dividentPoolRatio,unionPoolRatio,finalPoolRatio,devPoolRatio,nextGamePoolRatio);
    }
    function getPoolValue() public view returns (uint256,uint256,uint256,uint256) {
        return (totalFinalPoolValue,totalDevPoolValue,totalUnionPoolValue,totalNextGamePoolValue);
    }


    function buyLand(Point memory p,Point memory rp,uint256 unionId, uint256 value,address from ) internal virtual {
        (bool ended,, ,) = isGameEnded();
        require(!ended, "Game ended");

        (uint256 lastLandPrice, uint256 landPrice,uint256 ratio,uint256 shares,bool isNewLand,address lastOwner,uint256 lastUnionId) = getlandInfo(p);
        require(value >= landPrice, "Insufficient payment");
        // transfer back rest 
        if(value > landPrice) {
//            payable(from).transfer(value - landPrice);
            safeTransfer(tokenAddr,from,value - landPrice);
        }
        uint256 restValue = landPrice;
        if(!isNewLand) {
            restValue -= lastLandPrice;
            //transfer back last owner
//            payable(lastOwner).transfer(lastLandPrice);
            safeTransfer(tokenAddr,lastOwner,lastLandPrice);
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
            fortressTakenSecond =  (120 ether) * 3600 * 8 * 9000 / ( elapsed ) / landPrice / paramsEffect;
            emit FortressTakenSecondChanged(seasonId,before,fortressTakenSecond);
        }

        onUpdateLandPoint(isNewLand,p,lastOwner);
    }


    // 提取分红
    function withdrawDividends(address from) internal {
        uint256 withdrawableDividend = calculateWithdrawableDividend(from);
        require(withdrawableDividend > 0, "No dividends to withdraw");

        // 更新用户的调整值
        userDividendAdjust[from] = int256(userShares[from] * dividendPerShare);

        safeTransfer(tokenAddr,from,withdrawableDividend);
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

            safeTransfer(tokenAddr,from,value);
            userWithdrawedFinalAt[from] = block.timestamp;
        }

    }


    function onUpdateLandPoint(bool isNewLand,Point memory p,address lastOwner) internal  {
        if(!isNewLand) {
            uint256 lastLandPointsLastUpdated = userLandPointsLastUpdated[encodePoint(p)];
            addLandPoint(lastOwner,p,block.timestamp-lastLandPointsLastUpdated);
        }
        userLandPointsLastUpdated[encodePoint(p)] = block.timestamp;
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
            return  (land.currentPrice, (( 4 ether* (maxRing - ring) + 10 ether)* ratio/ 100 )/paramsEffect, ratio,landShare,true,ZERO_ADDRESS,0);
        }
    }
    
    function withdrawAll(address to) internal {
        if( tokenAddr == GAS_TOKEN_ADDR) {
            payable(to).transfer(address(this).balance);
        }else{
            IERC20 token = IERC20(tokenAddr);
            token.transfer(to, token.balanceOf(address(this)));
        }
    }

    function withdrawDev(address to) internal {
        (bool ended,address _winnerAddress ,uint256 _winnerUnionId,) = isGameEnded();
        require(ended, "Game not ended");
        require(withdrawedDevAt == 0, "Already withdrawed");
        withdrawedDevAt = block.timestamp;
        safeTransfer(tokenAddr,to,totalDevPoolValue);
    }

    function withdrawNextPool(address to) internal {
        (bool ended,address _winnerAddress ,uint256 _winnerUnionId,) = isGameEnded();
        require(ended, "Game not ended");
        require(withdrawedNextPoolAt == 0, "Already withdrawed");
        withdrawedNextPoolAt = block.timestamp;
        safeTransfer(tokenAddr,to,totalNextGamePoolValue);
    }


    function safeTransfer(address token, address to, uint256 value) internal {
        if (token == GAS_TOKEN_ADDR) {
            payable(to).transfer(value);
        } else {
            IERC20(token).transfer(to, value);
        }
    }

}

contract VoteGame is AuctionMapV3 {
    uint256 constant voteDuration = 600;

    mapping(uint256 => mapping(uint256 => uint256)) public unionVoteValue;
    mapping(uint256 => uint256) public maxVoteUnionId;
    
    uint256 public buyLandCnt;
    uint256 public buyLandCntWhenVoteFinished;

    uint256 public voteStartAtTs;
    uint256 public voteId = 0;
    uint256 public handledFinishedVoteId = 0;

    event LandPointConsumed(address indexed user,uint256 delta,uint256 afterValue);
    event Vote(uint256 voteId, address indexed user,uint256 unionId,uint256 value);
    event VoteFinished(uint256 voteId,uint256 buyLandCnt);
    event VoteStarted(uint256 voteId,uint256 voteDuration);


    constructor(string memory _seasonId,uint256 _startTs ,address tokenAddr,uint256 paramsEffect ) AuctionMapV3(_seasonId,_startTs,tokenAddr,paramsEffect) {
        voteStartAtTs = 0;
    }

    modifier onlyVoteTime() {
        require(voteStartAtTs != 0 && block.timestamp >= voteStartAtTs && block.timestamp - voteStartAtTs <= voteDuration, "Invalid vote time");
        _;
    }


    function getVoteStatus() public view returns (uint256,uint256,uint256,uint256,uint256) {
        return (buyLandCnt,buyLandCntWhenVoteFinished,voteStartAtTs,handledFinishedVoteId,voteId);
    }

    function getVoteInfo(uint256 voteId) public view returns (uint256[] memory _voteValues,uint256 _maxVoteUnionId) {
        _voteValues = new uint256[](4);
        for(uint i = 0; i < 4; i++) {
            _voteValues[i] = unionVoteValue[voteId][i+1];
        }
        return (_voteValues,maxVoteUnionId[voteId]);
    }

    function vote(address user,uint256 unionId,uint256 value) internal onlyVoteTime {
        //check user has landPoint
        require(userLandPoints[user] >= value, "Insufficient land point");
        //check current ring

        unionVoteValue[voteId][unionId] += value;
        if (unionVoteValue[voteId][unionId] > unionVoteValue[voteId][maxVoteUnionId[voteId]]) {
            maxVoteUnionId[voteId] = unionId;
        }   

        //minus user land point
        userLandPoints[user] -= value;
        emit Vote(voteId,user,unionId,value);
        emit LandPointConsumed(user,value,userLandPoints[user]);
    }

    function buyLand(Point memory p,Point memory rp,uint256 unionId, uint256 value,address from )  internal override  {
        //debuf check
        if (unionId == lastVotedUnionId()) {
            uint256 ring = ringNumber(p);
            uint256 currentRing = getCurrentRing();
            require(ring > currentRing, "can't buy land in current ring");
        }

        super.buyLand(p,rp,unionId,value,from);
        //set buyLandCntWhenVoteFinished
        // check if vote finished
        if (voteStartAtTs != 0 && block.timestamp - voteStartAtTs >= voteDuration && handledFinishedVoteId < voteId   ) {
            buyLandCntWhenVoteFinished = buyLandCnt;
            handledFinishedVoteId = voteId;

            emit VoteFinished(voteId,buyLandCntWhenVoteFinished);
        }

        buyLandCnt += 1;
        // check if next vote should start
        if (block.timestamp - voteStartAtTs >= voteDuration && buyLandCnt - buyLandCntWhenVoteFinished >= getVoteNeedBuyLandCnt(voteId)) {
            voteId += 1;
            voteStartAtTs = block.timestamp;
            emit VoteStarted(voteId,voteDuration);
        }
    }

    function getVoteNeedBuyLandCnt(uint256 voteId) internal view returns (uint256) {
        if (voteId < 4) {
            return (5-voteId)*10;
        }else if (voteId < 7) {
            return 10;
        }else{
            return 100000000000;
        }
    }
  

   

    //get current ring
    function getCurrentRing() internal view returns (uint256) {
        uint256 currentTs = block.timestamp;
        for(uint i = 0; i < maxRing; i++) {
            if(currentTs >= ringUnlockTs[i]) {
                return i;
            }
        }
        return maxRing;
    }

    function lastVotedUnionId() internal view returns (uint256) {
        //not started
        if (voteStartAtTs == 0) {
            return 0;
        } // not finished
        else if (block.timestamp - voteStartAtTs < voteDuration) {
            return 0;
        }else{
            // voting
            return maxVoteUnionId[voteId];
        }
    }

}




contract LotGameV3 is VoteGame {
    address immutable public proxyAddress;

    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(string memory _seasonId,address _proxyAddress,uint256 _startTs ,address tokenAddr,uint256 paramsEffect ) VoteGame(_seasonId,_startTs,tokenAddr,paramsEffect) {
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

    function withdrawDevByProxy(address to) public onlyProxy {
        withdrawDev(to);
    }

    function withdrawNextPoolByProxy(address to) public onlyProxy {
        withdrawNextPool(to);
    }

    function addFinalPool(uint256 amount) public payable onlyProxy {
        totalFinalPoolValue += amount;
    }

    function voteByProxy(address user,uint256 unionId,uint256 value) public onlyProxy {
        vote(user,unionId,value);
    }

    function claimLandPointByProxy(address user,Point memory p) public onlyProxy {
        claimLandPoint(user,p);
    }

    function claimLandPointsByProxy(address user,Point[] memory ps) public onlyProxy {
        claimLandPoints(user,ps);
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


interface IGameFactoryV3 {
    function createGame(string memory seasonId,uint256 startTs,address tokenAddr,uint256 paramsEffect) external returns (LotGameV3);
}

contract GameFactoryV3 is IGameFactoryV3 {

    address public immutable  proxyAddress;
    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(address _proxyAddress){
        proxyAddress = _proxyAddress;
    }

    function createGame(string memory seasonId,uint256 startTs,address tokenAddr,uint256 paramsEffect) public override onlyProxy returns (LotGameV3)   {
        return new LotGameV3(seasonId,address(proxyAddress),startTs, tokenAddr, paramsEffect);
    }
}

contract LotSeasonManagerV3 {
    address public _owner;

    IGameFactoryV3 public factory;

    mapping(string => LotGameV3) public seasonGameMap;
    mapping(string => mapping(address=>uint)) public seasonUnionInfo;
    mapping(string => mapping(uint=>uint)) public seasonUnionMemberCnt;
    mapping(string=> uint256) seasonRegistryFee;
    mapping(string=> address) seasonRegistryFeeToken;

    event SeasonCreated(string seasonId,address gameAddress,uint256 startTs,uint256 registryFee, address registryFeeTokenAddr, address tokenAddr,uint256 paramsEffect);
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

    function setFactory(IGameFactoryV3 _factory) public onlyOwner {
        factory = _factory;
    }

    //TODO: add onlyOwner and init reward
    function createSeason(string memory seasonId,uint256 startTs,uint256 registryFee,address registryFeeTokenAddr,address tokenAddr,uint256 initFinalAmount,uint256 paramsEffect) public payable  {
        require(address(seasonGameMap[seasonId]) == address(0), "Season already exists");
        LotGameV3  game = factory.createGame(seasonId,startTs,tokenAddr,paramsEffect);
        seasonGameMap[seasonId] = game;
        seasonRegistryFee[seasonId] = registryFee;
        seasonRegistryFeeToken[seasonId] = registryFeeTokenAddr;

        if(tokenAddr == GAS_TOKEN_ADDR) {
            require(msg.value >= initFinalAmount, "Insufficient init final pool value");
            game.addFinalPool{value: initFinalAmount}(initFinalAmount);
            uint256 restValue = msg.value - initFinalAmount;
            if( restValue > 0) {
                //transfer back
                payable(msg.sender).transfer(restValue);
            }
        }else{
            IERC20 token = IERC20(tokenAddr);
            require(token.transferFrom(msg.sender,address(game),initFinalAmount), "Transfer token failed");
            game.addFinalPool(initFinalAmount);
            if (msg.value > 0) {
                payable(msg.sender).transfer(msg.value);
            }
        }
       

        emit SeasonCreated(seasonId,address(game),startTs,registryFee,registryFeeTokenAddr,tokenAddr,paramsEffect);
    }


    function joinUnion(string memory seasonId,uint256 unionId)  public payable onlyGame(seasonId) {
        require(unionId >0 && unionId < 5, "Invalid unionId");
        require(seasonUnionInfo[seasonId][msg.sender] == 0, "User already in union");
        seasonUnionInfo[seasonId][msg.sender] = unionId;
        seasonUnionMemberCnt[seasonId][unionId] += 1;

        uint256 registryFee = seasonRegistryFee[seasonId];
        if (seasonRegistryFeeToken[seasonId] == GAS_TOKEN_ADDR) {
            require(msg.value >= registryFee, "Insufficient registry fee");
            if(msg.value > registryFee) {
                payable(msg.sender).transfer(msg.value - registryFee);
            }
        }else{
            IERC20 token = IERC20(seasonRegistryFeeToken[seasonId]);
            require(token.transferFrom(msg.sender,address(this),registryFee), "Transfer token failed");
        }

        emit PlayerJoined(seasonId,msg.sender,unionId);
    }

    // call LotGameV3  function
    function buyLand(string memory seasonId,LotGameV3.Point memory p,LotGameV3.Point memory rp ,uint256 tokenAmount) public payable onlyGame(seasonId) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        if  (game.tokenAddr() != GAS_TOKEN_ADDR ){
            //transfer token to game
            IERC20 token = IERC20(game.tokenAddr());
            require(token.transferFrom(msg.sender,address(game),tokenAmount), "Transfer token failed");
            game.buyLandByProxy(p,rp,unionId,tokenAmount,msg.sender);
        }else{
            require(msg.value >= tokenAmount, "Insufficient payment");
            if(msg.value > tokenAmount) {
                payable(msg.sender).transfer(msg.value - tokenAmount);
            }
            game.buyLandByProxy{value: tokenAmount}(p,rp,unionId,tokenAmount,msg.sender);
        }

        emit PlayerBuyLand(seasonId,msg.sender,p,tokenAmount);
    }

    function withdrawDividends(string memory seasonId) public onlyGame(seasonId) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawDividendsByProxy(msg.sender);
    }

    function withdrawFinal(string memory seasonId) public onlyGame(seasonId){
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawFinalByProxy(msg.sender,unionId);
    }

    function withdrawAll(string memory seasonId) public onlyOwner {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.withdrawAllByProxy(_owner);
    }

    function withdrawDev(string memory seasonId) public onlyOwner {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.withdrawDevByProxy(_owner);
    }

    function withdrawNextPool(string memory seasonId,address nextPoolAddr ) public onlyOwner {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.withdrawNextPoolByProxy(nextPoolAddr);
    }

    function withdrawAllFee( address tokenAddr ) public onlyOwner {
        if (tokenAddr == GAS_TOKEN_ADDR) {
            payable(_owner).transfer(address(this).balance);
        } else {
            IERC20(tokenAddr).transfer(_owner, IERC20(tokenAddr).balanceOf(address(this)));
        }
    }

    function getUnionInfo(string memory seasonId,address from) public view returns (uint256 unionId,uint256[] memory unionMemberCnt) {

        unionId = seasonUnionInfo[seasonId][from];
        unionMemberCnt = new uint256[](4);
        for(uint i = 0; i < 4; i++) {
            unionMemberCnt[i] = seasonUnionMemberCnt[seasonId][i+1];
        }
    }

    function getLandInfo(string memory seasonId,LotGameV3.Point memory p) public view returns (uint256 currLandPrice,uint256 nextLandPrice,uint256 ratio,uint256 shares,bool isNewLand,address owner,uint256 unionId,uint256 protectTimeTs,uint256 lastUpdatedAt) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        return game.getLand(p);
    }

    function getGameInfo(string memory seasonId) public view returns  (bool gameEnded,address winnerAddress,uint256 winnerUnionId,uint256 totalShares,uint256 dividendPerShare,uint256 totalFinalPoolValue,uint256 totalDevPoolValue,uint256 totalNextGamePoolValue,uint256 totalUnionPoolValue,uint256 fortressTakenFinishTs) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        return game.getGameInfo();
    }

    function getShareInfo(string memory seasonId,address from,uint256 unionId) public view returns  ( uint256 totalShare,uint256 unionTotalShare, uint256 totalDivident){
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        (totalShare,unionTotalShare,totalDivident) = game.getShareInfo(from,unionId);
    }

    function getUnlockedRingTs(string memory seasonId,uint ring) public view returns (uint256) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        return game.getUnlockedRingTs(ring);
    }

    function vote(string memory seasonId,uint256 unionId,uint256 value) public onlyGame(seasonId) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.voteByProxy(msg.sender,unionId,value);
    }

    function claimLandPoint(string memory seasonId,LotGameV3.Point memory p) public onlyGame(seasonId) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.claimLandPointByProxy(msg.sender,p);
    }

    function claimLandPoints(string memory seasonId,LotGameV3.Point[] memory ps) public onlyGame(seasonId) {
        LotGameV3  game = LotGameV3(seasonGameMap[seasonId]);
        game.claimLandPointsByProxy(msg.sender,ps);
    }



    function safeTransfer(address token, address to, uint256 value) internal {
        if (token == GAS_TOKEN_ADDR) {
            payable(to).transfer(value);
        } else {
            IERC20(token).transfer(to, value);
        }
    }

    
}