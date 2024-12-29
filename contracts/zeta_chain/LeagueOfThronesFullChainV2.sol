// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './LeagueOfThronesFullChain.sol';
address constant GAS_TOKEN_ADDR = 0x0000000000000000000000000000000000000000;



contract AuctionMapV2 is HexMap {


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

   
    constructor(string memory _seasonId,uint256 _startTs,address _tokenAddr,uint256 _paramsEffect) HexMap(_seasonId,_startTs) {
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


    function buyLand(Point memory p,Point memory rp,uint256 unionId, uint256 value,address from ) internal   {
        (bool ended,, ,) = isGameEnded();
        if (ended) {
            return;
        }
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

contract LotGameV2 is AuctionMapV2 {
    address immutable public proxyAddress;

    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(string memory _seasonId,address _proxyAddress,uint256 _startTs ,address tokenAddr,uint256 paramsEffect ) AuctionMapV2(_seasonId,_startTs,tokenAddr,paramsEffect) {
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


interface IGameFactoryV2 {
    function createGame(string memory seasonId,uint256 startTs,address tokenAddr,uint256 paramsEffect) external returns (LotGameV2);
}

contract GameFactoryV2 is IGameFactoryV2 {

    address public immutable  proxyAddress;
    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Only proxy can call this function");
        _;
    }

    constructor(address _proxyAddress){
        proxyAddress = _proxyAddress;
    }

    function createGame(string memory seasonId,uint256 startTs,address tokenAddr,uint256 paramsEffect) public override onlyProxy returns (LotGameV2)   {
        return new LotGameV2(seasonId,address(proxyAddress),startTs, tokenAddr, paramsEffect);
    }
}

contract LotSeasonManagerV2 {
    address public _owner;

    IGameFactoryV2 public factory;

    mapping(string => LotGameV2) public seasonGameMap;
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

    function setFactory(IGameFactoryV2 _factory) public onlyOwner {
        factory = _factory;
    }

    //TODO: add onlyOwner and init reward
    function createSeason(string memory seasonId,uint256 startTs,uint256 registryFee,address registryFeeTokenAddr,address tokenAddr,uint256 initFinalAmount,uint256 paramsEffect) public payable  {
        require(address(seasonGameMap[seasonId]) == address(0), "Season already exists");
        LotGameV2  game = factory.createGame(seasonId,startTs,tokenAddr,paramsEffect);
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

    // call LotGameV2  function
    function buyLand(string memory seasonId,LotGameV2.Point memory p,LotGameV2.Point memory rp ,uint256 tokenAmount) public payable onlyGame(seasonId) {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
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
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawDividendsByProxy(msg.sender);
    }

    function withdrawFinal(string memory seasonId) public onlyGame(seasonId){
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        uint256 unionId = seasonUnionInfo[seasonId][msg.sender];
        require(unionId != 0, "User not in union");
        game.withdrawFinalByProxy(msg.sender,unionId);
    }

    function withdrawAll(string memory seasonId) public onlyOwner {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        game.withdrawAllByProxy(_owner);
    }

    function withdrawDev(string memory seasonId) public onlyOwner {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        game.withdrawDevByProxy(_owner);
    }

    function withdrawNextPool(string memory seasonId,address nextPoolAddr ) public onlyOwner {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
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

    function getLandInfo(string memory seasonId,LotGameV2.Point memory p) public view returns (uint256 currLandPrice,uint256 nextLandPrice,uint256 ratio,uint256 shares,bool isNewLand,address owner,uint256 unionId,uint256 protectTimeTs,uint256 lastUpdatedAt) {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        return game.getLand(p);
    }

    function getGameInfo(string memory seasonId) public view returns  (bool gameEnded,address winnerAddress,uint256 winnerUnionId,uint256 totalShares,uint256 dividendPerShare,uint256 totalFinalPoolValue,uint256 totalDevPoolValue,uint256 totalNextGamePoolValue,uint256 totalUnionPoolValue,uint256 fortressTakenFinishTs) {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        return game.getGameInfo();
    }

    function getShareInfo(string memory seasonId,address from,uint256 unionId) public view returns  ( uint256 totalShare,uint256 unionTotalShare, uint256 totalDivident){
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        (totalShare,unionTotalShare,totalDivident) = game.getShareInfo(from,unionId);
    }

    function getUnlockedRingTs(string memory seasonId,uint ring) public view returns (uint256) {
        LotGameV2  game = LotGameV2(seasonGameMap[seasonId]);
        return game.getUnlockedRingTs(ring);
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        if (token == GAS_TOKEN_ADDR) {
            payable(to).transfer(value);
        } else {
            IERC20(token).transfer(to, value);
        }
    }

    
}