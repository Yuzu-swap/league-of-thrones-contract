// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import './IUniswapV2Router01.sol';



enum SeasonStatus { Invalid, Active, End }

enum MappingStatus { Invalid, Valid }


struct ExtraGeneralIds {
    uint256[] generalIds;
    MappingStatus status;
}

//union Record
struct UnionRecord{
    address[] playerAddresses;
    uint256 unionId;
    mapping(address => ExtraGeneralIds) playerExtraGeneralIds;
    MappingStatus status;
}


//season record
struct SeasonRecord{
    mapping(uint256 => UnionRecord) unionRecords;
    mapping(address => uint256) unionIdMapping;
    mapping(address => uint256) unionRewardRecord;
    mapping(address => uint256) gloryRewardRecord;
    mapping(address => uint256) rechargeRecord;
    MappingStatus rechargeStatus;
    address rechargeAddress;
    uint256 sumPlayers;
    address[] nftContractAddress;
    address rewardAddress;
    uint256 playerLimit;
    uint256 reward1Amount;
    uint256 reward2Amount;
    uint256 sumRecharge;
    uint256[] rankConfigFromTo;
    uint256[] rankConfigValue;
    //reservation open ready end
    uint256[] seasonTimeConfig;
    SeasonStatus seasonStatus;
    uint256 maxUnionDiffNum;
    uint256 registeryFee;
    mapping(address => bytes) playerStates;

}

struct SeaSonInfoResult{
    uint256 unionId;
    uint256[] generalIds;
}

struct SeasonStatusResult{
    uint256 sumPlayerNum;
    uint256[] unionsPlayerNum;
    uint256 maxUnionDiffNum;
}


struct NftAndRechargeConfig {
    address []nftAddress;
    address tokenAddress;
    uint256 registeryFee;
}
struct SignUpSimpleInfo {
    address player;
    string seasonId;
    uint256 chainId;
    uint256 []nftTokenIds;
    address tokenAddress;
    uint256 tokenAmount;
    uint256 unionId;
}

contract LeagueOfThronesV2_1 is Ownable,zContract,ReentrancyGuard{

    SystemContract public immutable systemContract;
    uint256 public immutable contractChainId ;

    event OnCrossChainCall( zContext context, address zrc20, uint256 amount, bytes message);
    event PlayerStatesChanged( string seasonId, address player, bytes states);
    event startSeasonInfo( string seasonId, uint256 playerLimit, address rewardAddress, uint256 rewardAmount1, uint256 rewardAmount2, uint256[] rankConfigFromTo, uint256[] rankConfigValue, uint256[] seasonTimeConfig,uint256 registeryFee);
    event endSeasonInfo( string seasonId, uint256 unionId, address[] playerAddresses, uint256[] glorys, uint256 unionSumGlory);
    event signUpInfo( string seasonId, uint256 chainId,address player, uint256 unionId, uint256[] extraGeneralIds,uint256 []originNFTIds,uint256 originUnionId);
    event rechargeInfo( string seasonId,uint256 chainId, address player, uint256 rechargeId,address token, uint256 amount, uint256 totalAmount);
    mapping( string => SeasonRecord) public seasonRecords;
    mapping(address=>mapping(address=>uint256)) public tokenPlayerBalancesMap;
    string public nowSeasonId;

    mapping(address => bool) public oracles;
    IUniswapV2Router01 public swapRouterIns;

    constructor(address systemContractAddress,uint256 _chainId) public onlyOwner{
        systemContract = SystemContract(systemContractAddress);
        contractChainId = _chainId;
        oracles[msg.sender] = true;
    }


    modifier onlyOracle() {
        require(oracles[msg.sender], "Caller is not the oracle");
        _;
    }


    modifier onlySystem() {
        require(
            msg.sender == address(systemContract),
            "Only system contract can call this function"
        );
        _;
    }

    receive() external payable {}
 

    //start season and transfer reward to contract
    function startSeason(
        string memory seasonId,
        uint256 playerLimit,
        address rewardAddress,
        uint256 rewardAmount1, 
        uint256 rewardAmount2, 
        uint256[] memory rankConfigFromTo,
        uint256[] memory rankConfigValue,
        uint256[] memory seasonTimeConfig,
        uint256 maxUnionDiffNum,
        NftAndRechargeConfig memory nftAndRechargeConfig
        ) external onlyOwner payable {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Invalid, "Season can not start repeat");
        require(seasonTimeConfig.length == 4, "time config length error" );
        require(maxUnionDiffNum > 0, "maxUnionDiffNum must above zero" );

        uint256 rewordAmount = rewardAmount1 + rewardAmount2;
        //BSC version modify ,no need to pre transfer
//        if (false) {
        if(rewardAddress == address(0x0)){
            require( msg.value == rewordAmount, "value not equal rewardAmount" );
        }
        else{
            IERC20 token = IERC20(rewardAddress);
            uint256 allowance = token.allowance(msg.sender, address(this));
            require(allowance >= rewordAmount, "Check the token allowance");
            token.transferFrom(msg.sender, address(this), rewordAmount);
        }
 //     }


       
        sRecord.rewardAddress = rewardAddress;
        sRecord.reward1Amount = rewardAmount1;
        sRecord.reward2Amount = rewardAmount2;
        sRecord.playerLimit = playerLimit;
        sRecord.maxUnionDiffNum = maxUnionDiffNum;
        require(rankConfigFromTo.length == rankConfigValue.length * 2, "rewardConfig length error");
        uint256 sumReward = 0;
        bool indexRight = true;
        uint256 lastEnd = 0;
        for(uint256 i = 0; i < rankConfigValue.length; i++){
            if(rankConfigFromTo[i * 2] != lastEnd + 1){
                indexRight = false;
                break;
            }
            lastEnd = rankConfigFromTo[i * 2 + 1];
            sumReward += ((rankConfigFromTo[i * 2 + 1] - rankConfigFromTo[i * 2 ] + 1) * rankConfigValue[i]);
        }
        require(indexRight && sumReward == rewardAmount2, "reward config error");
        sRecord.rankConfigFromTo = rankConfigFromTo;
        sRecord.rankConfigValue = rankConfigValue;
        sRecord.seasonTimeConfig = seasonTimeConfig;


        sRecord.nftContractAddress = nftAndRechargeConfig.nftAddress;
        sRecord.rechargeStatus = MappingStatus.Valid;
        sRecord.rechargeAddress = nftAndRechargeConfig.tokenAddress;
        sRecord.seasonStatus = SeasonStatus.Active;
        sRecord.registeryFee = nftAndRechargeConfig.registeryFee;


        emit startSeasonInfo(seasonId, playerLimit, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue, seasonTimeConfig,nftAndRechargeConfig.registeryFee);
    }


    function setPlayerStates(string memory seasonId,address player, bytes memory states) public {
        //not verify whether the player has signUp
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.unionIdMapping[player] > 0 , "player has not signUp");
        sRecord.playerStates[player] = states;
        emit PlayerStatesChanged(seasonId, player, states);
    }

    function getPlayerStates(string memory seasonId,address player ) public view returns (bytes memory){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        return sRecord.playerStates[player];
    }


    function getNFTAddresses(string memory seasonId ) public view returns (address[] memory){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        return sRecord.nftContractAddress;
    }

    function getPlayerCount(string memory seasonId ) public view returns (uint256){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        return sRecord.sumPlayers;
    }

    function random(uint number) public view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty,  
            msg.sender))) % number;
    }


    function getRechargeToken(string memory seasonId) public view returns( address ) {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        return sRecord.rechargeAddress;
    }

    function testCheckRegisteryFee(address swapRouterAddress,uint256 registeryFee,address tokenAddress,uint256 tokenAmount) public view returns (bool){
        return checkRegisteryFee(IUniswapV2Router01(swapRouterAddress), registeryFee,tokenAddress,tokenAmount);
    }


    function signUpGame(string memory seasonId,uint256 unionId, uint256[] memory nftTokenIds) external payable{
        SignUpSimpleInfo memory sinfo = SignUpSimpleInfo({
            player: msg.sender,
            seasonId: seasonId,
            chainId: contractChainId,
            nftTokenIds:nftTokenIds,
            tokenAddress: address(0x0),
            tokenAmount: msg.value,
            unionId: unionId
        });
        onSignUpGame(sinfo);
    }
    // params: 
    //  unionId:  0 for random
    
    function onSignUpGame(SignUpSimpleInfo memory sinfo) internal {
        // uint256 chainId,address player,string memory seasonId,uint256 unionId, uint256 nft1TokenId, uint256 nft2TokenId,address tokenAddress,uint256 tokenAmount) internal{
        uint256 unionId = sinfo.unionId;
        address player = sinfo.player;
        string memory seasonId = sinfo.seasonId;

        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Active, "Season Status Error");
        require( block.timestamp >= sRecord.seasonTimeConfig[0] && block.timestamp <= sRecord.seasonTimeConfig[3], "It is not signUp time now");
        require( sRecord.sumPlayers < sRecord.playerLimit, "the number of players has reached the limit");
        require( sinfo.unionId >= 0 && sinfo.unionId <= 4, "unionId error");

        require( checkRegisteryFee(swapRouterIns, sRecord.registeryFee,sinfo.tokenAddress,sinfo.tokenAmount), "registeryFee is not enough");


        // Record original unionId to detect whether the player select random unionId
        uint256 orginUnionId = sinfo.unionId;
        uint256[] memory originNFTIds = sinfo.nftTokenIds;




        // find wheather player has signUp and get union's player number
        uint256[] memory unionPlayerNum = new uint256[](5);
        uint256 minumUnionPlayerNum = sRecord.playerLimit;

        bool hasSignUp = false;
        for( uint i = 1 ; i <= 4 ; i ++ ){
            UnionRecord storage unionRecord = sRecord.unionRecords[i];
            if(unionRecord.status != MappingStatus.Invalid ){
                unionPlayerNum[i] = unionRecord.playerAddresses.length;
                ExtraGeneralIds storage extraIds =  unionRecord.playerExtraGeneralIds[player];
                if(extraIds.status == MappingStatus.Valid){
                    hasSignUp = true;
                    break;
                }
            }

            if(unionPlayerNum[i] < minumUnionPlayerNum){
                minumUnionPlayerNum = unionPlayerNum[i];
            }
        }
        require(hasSignUp == false , "player has signUp");
        // random unionId
        if (sinfo.unionId!=0){
            // unionId maxUnionDiffNum check
            require(unionPlayerNum[sinfo.unionId] - minumUnionPlayerNum < sRecord.maxUnionDiffNum, "unionId maxUnionDiffNum check error");
        }else{
            // random unionId of which player number is not above maxUnionDiffNum + currentUnionPlayerNum
            uint256[] memory unionIdsList = new uint256[](4);
            uint256 unionIdsListLen = 0;
            for( uint i = 1 ; i <= 4 ; i ++ ){
                if(unionPlayerNum[i] - minumUnionPlayerNum < sRecord.maxUnionDiffNum){
                    // add to unionIdsList
                    unionIdsList[unionIdsListLen] = i;
                    unionIdsListLen ++ ;
                }
            }

            // random unionId by block.timestamp
            bytes32 randomId = keccak256(abi.encodePacked(block.timestamp,block.difficulty,sinfo.player));
            unionId = unionIdsList[uint(randomId) % unionIdsListLen];
        }

        // update season record
        sRecord.sumPlayers ++ ;
        sRecord.unionIdMapping[player] = unionId;
        UnionRecord storage unionRecord = sRecord.unionRecords[unionId];
        if(unionRecord.status == MappingStatus.Invalid){
            //gen union record
            unionRecord.status = MappingStatus.Valid;
            unionRecord.playerAddresses = new address[](0);
        }
        unionRecord.playerAddresses.push(player);

        //Random extra general
        ExtraGeneralIds storage extraIds = unionRecord.playerExtraGeneralIds[player];
        extraIds.generalIds = new uint256[](0);
        extraIds.status = MappingStatus.Valid;

        for(uint i = 0; i < originNFTIds.length; i++){
            uint256 nftTokenId = originNFTIds[i];
            if(sRecord.nftContractAddress[i] != 0x0000000000000000000000000000000000000000  && nftTokenId != 0){
                IERC721 nftContract = IERC721(sRecord.nftContractAddress[i]);
                try nftContract.ownerOf(nftTokenId) returns(address owner){
                    if(owner == player){
                        extraIds.generalIds.push(random(100));
                    }
                }
                catch{
                }
            }
        }
        emit signUpInfo(sinfo.seasonId ,sinfo.chainId, sinfo.player, unionId, extraIds.generalIds, originNFTIds, orginUnionId);
    }


    function recharge(string memory seasonId, uint256 rechargeId ,uint256 amount) public payable {
        onRecharge(contractChainId,msg.sender,seasonId, rechargeId ,address(0x0),amount);
    }

    function onRecharge(uint256 chainId,address player,string memory seasonId, uint256 rechargeId ,address zrc20,uint256 amount) internal  {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Active, "Season Status Error");
        require(sRecord.rechargeStatus == MappingStatus.Valid, "recharge token have not set");
       // require(sRecord.rechargeAddress == zrc20, "recharge token address error");
        sRecord.rechargeRecord[player] += amount;
        sRecord.sumRecharge += amount;
        emit rechargeInfo(seasonId,chainId, player, rechargeId,zrc20, amount, sRecord.rechargeRecord[player]);
    }


    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem {
        address user = BytesHelperLib.bytesToAddress(context.origin, 0);
        uint8 action;
        string memory seasonId;

        (action,seasonId ) =  abi.decode(message, (uint8,string));
        if (action == 1) { // signUp
            uint256 unionId;
            uint256[] memory nftTokenIds;
            (,, unionId, nftTokenIds)   = abi.decode(message, (uint8,string,uint256,uint256[]));
            SignUpSimpleInfo memory sinfo = SignUpSimpleInfo({
                player: user,
                seasonId: seasonId,
                chainId: context.chainID,
                nftTokenIds:nftTokenIds,
                tokenAddress: zrc20,
                tokenAmount: amount,
                unionId: unionId
            });

            onSignUpGame(sinfo);

        } else if (action ==2) { //recharge
            uint256 rechargeId;
            (,,rechargeId)   = abi.decode(message, (uint8,string,uint256));
            onRecharge(context.chainID,user,seasonId, rechargeId ,zrc20,amount);
        }

        emit OnCrossChainCall(context, zrc20, amount, message);

    }

    function getRechargeInfo( string memory seasonId, address player) public view returns (uint256, uint256){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus != SeasonStatus.Invalid, "Season is not exist");
        return (sRecord.rechargeRecord[player], sRecord.sumRecharge);
    }


    function getSeasonStatus( string memory seasonId ) public view returns ( SeasonStatusResult memory ){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Active, "Season Status Error");
        SeasonStatusResult memory re = SeasonStatusResult( sRecord.sumPlayers , new uint256[](4),sRecord.maxUnionDiffNum);
        for( uint i = 1 ; i <= 4 ; i ++ ){
            UnionRecord storage unionRecord = sRecord.unionRecords[i];
            if(unionRecord.status == MappingStatus.Invalid ){
                re.unionsPlayerNum[i-1] = 0;
            }
            else{
                re.unionsPlayerNum[i-1] = unionRecord.playerAddresses.length;
            }
        }
        return re;
    } 

    function getSignUpInfo( string memory seasonId, address playerAddress) public view returns ( SeaSonInfoResult memory){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        SeaSonInfoResult memory re = SeaSonInfoResult(0, new uint256[](0));
        for( uint i = 1 ; i <= 4 ; i ++ ){
            UnionRecord storage unionRecord = sRecord.unionRecords[i];
            if(unionRecord.status == MappingStatus.Invalid ){
                continue;
            }
            else{
                ExtraGeneralIds storage extraIds = unionRecord.playerExtraGeneralIds[playerAddress];
                if(extraIds.status == MappingStatus.Invalid){
                    continue;
                }
                re.unionId = i;
                re.generalIds = extraIds.generalIds;
            }
        }
        return re;
    }


    function setswapRouterIns(address _swapRouterAddress) external onlyOwner {
        swapRouterIns = IUniswapV2Router01(_swapRouterAddress);
    }

    function setOracle(address _oracle,bool value) public onlyOwner {
        oracles[_oracle] = value;
    }

    function endSeason(  string memory seasonId, uint256 unionId, address[] memory playerAddresses, uint256[] memory glorys, uint256 unionSumGlory) external onlyOracle {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Active,  "Season Status Error");
        require(playerAddresses.length == glorys.length, "input array length do not equal");
        uint fromToIndex = 0;
        uint rankMax = sRecord.rankConfigFromTo[sRecord.rankConfigFromTo.length - 1];
        //IERC20 token = IERC20(sRecord.rewardAddress);
        //MaxUint256
        uint256 lastGory = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        uint256 totalUnionReward = 0;
        uint256 totalRankReward = 0;
        uint256 realUnionGlory = 0;
        for(uint i = 0; i < playerAddresses.length; i++ ){  
            address playerAddress = playerAddresses[i];
            uint256 glory = glorys[i];
            require(sRecord.gloryRewardRecord[playerAddress] == 0, "playerAddresses is not unique");
            require(sRecord.unionIdMapping[playerAddress] > 0, "playerAddresses is not signUp");
            require(glory <= lastGory, "glorys is not in order");
            lastGory = glory;
            if(sRecord.unionIdMapping[playerAddress] == unionId){
               uint256 amount = glory * sRecord.reward1Amount / unionSumGlory;
               sRecord.unionRewardRecord[playerAddress] = amount; 
               _sendReward(sRecord.rewardAddress, playerAddress, amount);
               totalUnionReward += amount;
               realUnionGlory += glory;
            }
            if(i < rankMax){
               uint256 to = sRecord.rankConfigFromTo[fromToIndex * 2 + 1];
               if( i + 1 > to ){
                  fromToIndex += 1;
               }
               uint256 amount = sRecord.rankConfigValue[fromToIndex];
               sRecord.gloryRewardRecord[playerAddress] = amount;
               _sendReward(sRecord.rewardAddress, playerAddress, amount);
               totalRankReward += amount;
            }
        }
        require(realUnionGlory == unionSumGlory, "realUnionGlory is not equal to unionSumGlory");
        require(totalUnionReward<= sRecord.reward1Amount, "totalUnionReward is greator than reward1Amount");
        require(totalRankReward<= sRecord.reward2Amount, "totalUnionReward is greator than reward2Amount");

        sRecord.seasonStatus = SeasonStatus.End;
        emit endSeasonInfo( seasonId,  unionId,  playerAddresses, glorys, unionSumGlory);
    }

    function withdraw( address tokenAddress, uint256 amount) external  onlyOwner{
        if(tokenAddress == address(0x0)){
            require(address(this).balance >=  amount, "balance is not enough");
            payable(msg.sender).transfer(amount);
        }
        else{
            IERC20 token = IERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            require(balance >= amount, "balance is not enough");
            token.transfer(msg.sender, amount);
        }
    }

    function withdrawMyBalance( address tokenAddress) external nonReentrant {
        uint256 amount = tokenPlayerBalancesMap[tokenAddress][msg.sender];
        require(amount > 0, "amount is zero");
        tokenPlayerBalancesMap[tokenAddress][msg.sender] = 0;
        if(tokenAddress == address(0x0)){
            require(address(this).balance >=  amount, "balance is not enough");
            payable(msg.sender).transfer(amount);
        }
        else{
            IERC20 token = IERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            require(balance >= amount, "balance is not enough");
            token.transfer(msg.sender, amount);
        }
    }

    function getSeasonReward(string memory seasonId,address player ) external view returns (uint256 unionReward,uint256 rankReward){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        return (sRecord.unionRewardRecord[player],sRecord.gloryRewardRecord[player]);
    }

    function checkReward(address tokenAddress,address player) external view returns (uint256){
        uint256 amount = tokenPlayerBalancesMap[tokenAddress][player];
        return amount;
    }

    function _sendReward(address rewardAddress, address toAddress, uint256 amount) internal {
        tokenPlayerBalancesMap[rewardAddress][toAddress] += amount;
    }


    function checkRegisteryFee(IUniswapV2Router01 _swapRouter,uint256 registeryFee,address tokenAddress,uint256 tokenAmount) internal view returns (bool){
        if(tokenAddress == address(0x0)){
            return tokenAmount >= registeryFee;
        }
        else{
            if (address(_swapRouter)!=address(0x0)){
                address weth = _swapRouter.WETH();
                  address[] memory path = new address[](2);
                  path[0] = tokenAddress;
                  path[1] = weth;
                  uint[] memory amountsOut = _swapRouter.getAmountsOut(tokenAmount, path);
                  return amountsOut[1] >= registeryFee; 
            }else{
                return false;
            }
        }
    }
 
}





contract MockRouterV1 {
    address public WETH;

    constructor(address _WETH) {
        WETH = _WETH;
    }

    //mock from token(bnb) -> WETH
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory) {
        uint256[] memory amountsOut = new uint256[](2);
        amountsOut[0] = amountIn;
        amountsOut[1] = amountIn * 250; //fix ratio
        return amountsOut;
    }

}


contract MockRouterV2 is Ownable{
    address public WETH;
    uint256 public ratio ;

    constructor(address _WETH,uint256 _ratio) {
        WETH = _WETH;
        ratio = _ratio;
    }

    function setRatio(uint256 _ratio) public onlyOwner {
        ratio = _ratio;
    }

    //mock from token(bnb) -> WETH
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory) {
        uint256[] memory amountsOut = new uint256[](2);
        amountsOut[0] = amountIn;
        amountsOut[1] = amountIn * ratio; //fix ratio
        return amountsOut;
    }

}


