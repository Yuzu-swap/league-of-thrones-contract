// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


enum SeasonStatus { Invalid, WaitForNTF ,Pending, End }

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
    address ntf1ContractAddress;
    address ntf2ContractAddress;
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
}

struct SeaSonInfoResult{
    uint256 unionId;
    uint256[] generalIds;
}

struct SeasonStatusResult{
    uint256 sumPlayerNum;
    uint256[] unionsPlayerNum;
}

contract LeagueOfThrones is Ownable{

    event signUpInfo( string seasonId, address player, uint256 unionId, uint256[] extraGeneralIds);
    event startSeasonInfo( string seasonId, uint256 playerLimit, address rewardAddress, uint256 rewardAmount1, uint256 rewardAmount2, uint256[] rankConfigFromTo, uint256[] rankConfigValue, uint256[] seasonTimeConfig);
    event endSeasonInfo( string seasonId, uint256 unionId, address[] playerAddresses, uint256[] glorys, uint256 unionSumGlory);
    event sendRankRewardInfo( string seasonId, address player, uint256 rank, uint256 amount);
    event sendUnionRewardInfo( string seasonId, address player, uint256 glory, uint256 amount);
    event rechargeInfo( string seasonId, address player, uint256 rechargeId,uint256 amount, uint256 totalAmount);
    mapping( string => SeasonRecord) seasonRecords;
    string public nowSeasonId;

    constructor() public onlyOwner{
        nowSeasonId = "";
    }

    //start season and transfer reward to contract
    function startSeason(
        string memory seasonId,
        uint256 playerLimit,
        address rewardAddress,
        uint256 rewardAmount1, 
        uint256 rewardAmount2, 
        uint256[] memory rankConfigFromTo,
        uint256[] memory rankConfigValue,
        uint256[] memory seasonTimeConfig
        ) external onlyOwner payable {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Invalid, "Season can not start repeat");
        require(seasonTimeConfig.length == 4, "time config length error" );

        uint256 rewordAmount = rewardAmount1 + rewardAmount2;
        if(rewardAddress == address(0x0)){
            require( msg.value == rewordAmount, "Check the ETH amount" );
        }
        else{
            IERC20 token = IERC20(rewardAddress);
            uint256 allowance = token.allowance(msg.sender, address(this));
            require(allowance >= rewordAmount, "Check the token allowance");
            token.transferFrom(msg.sender, address(this), rewordAmount);
        }

        sRecord.seasonStatus = SeasonStatus.WaitForNTF;
        sRecord.rewardAddress = rewardAddress;
        sRecord.reward1Amount = rewardAmount1;
        sRecord.reward2Amount = rewardAmount2;
        sRecord.playerLimit = playerLimit;
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
        emit startSeasonInfo(seasonId, playerLimit, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue, seasonTimeConfig);
    }

    //set nft address of season
    function setNFTAddress(string memory seasonId, address ntf1Address, address ntf2Address) external onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.WaitForNTF, "Season Haven't begin or NTF have set");
        sRecord.seasonStatus = SeasonStatus.Pending;
        sRecord.ntf1ContractAddress = ntf1Address;
        sRecord.ntf2ContractAddress = ntf2Address;
        sRecord.seasonStatus = SeasonStatus.Pending;
    }

    function getNFTAddresses(string memory seasonId ) public view returns (address[] memory){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        address[] memory addresses = new address[](2);
        addresses[0] = sRecord.ntf1ContractAddress;
        addresses[1] = sRecord.ntf2ContractAddress;
        return addresses;
    }

    function random(uint number) public view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty,  
            msg.sender))) % number;
    }

    function signUpGame(string memory seasonId, uint256 ntf1TokenId, uint256 ntf2TokenId) external{
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        require( block.timestamp >= sRecord.seasonTimeConfig[0] && block.timestamp <= sRecord.seasonTimeConfig[3], "It is not signUp time now");
        require( sRecord.sumPlayers < sRecord.playerLimit, "the number of players has reached the limit");
        bool hasSignUp = false;
        for( uint i = 1 ; i <= 4 ; i ++ ){
            UnionRecord storage unionRecord = sRecord.unionRecords[i];
            if(unionRecord.status == MappingStatus.Invalid ){
                continue;
            }
            else{
                ExtraGeneralIds storage extraIds =  unionRecord.playerExtraGeneralIds[msg.sender];
                if(extraIds.status == MappingStatus.Valid){
                    hasSignUp = true;
                    break;
                }
            }
        }
        require(hasSignUp == false , "player has signUp");
        sRecord.sumPlayers ++ ;
        uint unionId = sRecord.sumPlayers % 4 ;
        if(unionId == 0) {
            unionId = 4;
        }
        sRecord.unionIdMapping[msg.sender] = unionId;
        UnionRecord storage unionRecord = sRecord.unionRecords[unionId];
        if(unionRecord.status == MappingStatus.Invalid){
            //gen union record
            unionRecord.status = MappingStatus.Valid;
            unionRecord.playerAddresses = new address[](0);
        }
        unionRecord.playerAddresses.push(msg.sender);
        IERC721 ntf1Contract = IERC721(sRecord.ntf1ContractAddress);
        IERC721 ntf2Contract = IERC721(sRecord.ntf2ContractAddress);
        ExtraGeneralIds storage extraIds = unionRecord.playerExtraGeneralIds[msg.sender];
        extraIds.generalIds = new uint256[](0);
        extraIds.status = MappingStatus.Valid;
        try ntf1Contract.ownerOf(ntf1TokenId) returns(address owner){
            if(owner == msg.sender){
                extraIds.generalIds.push(random(4) + 7);
            }
        }
        catch{

        }
        try ntf2Contract.ownerOf(ntf2TokenId) returns(address owner){
            if(owner == msg.sender){
                extraIds.generalIds.push(random(4) + 11);
            }
        }
        catch{
            
        }
        emit signUpInfo(seasonId , msg.sender, unionId, extraIds.generalIds);
    }

    function setRechargeToken(string memory seasonId, address tokenAddress) public onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        require(sRecord.rechargeStatus == MappingStatus.Invalid, "recharge token have set");
        sRecord.rechargeStatus = MappingStatus.Valid;
        sRecord.rechargeAddress = tokenAddress;
    }

    function getRechargeToken(string memory seasonId) public view returns( address ) {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        require(sRecord.rechargeStatus == MappingStatus.Valid, "recharge token have not set");
        return sRecord.rechargeAddress;
    }

    function recharge(string memory seasonId, uint256 rechargeId ,uint256 amount) public payable {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        require(sRecord.rechargeStatus == MappingStatus.Valid, "recharge token have not set");
        // bool hasSignUp = false;
        // for( uint i = 1 ; i <= 4 ; i ++ ){
        //     UnionRecord storage unionRecord = sRecord.unionRecords[i];
        //     if(unionRecord.status == MappingStatus.Invalid ){
        //         continue;
        //     }
        //     else{
        //         ExtraGeneralIds storage extraIds =  unionRecord.playerExtraGeneralIds[msg.sender];
        //         if(extraIds.status == MappingStatus.Valid){
        //             hasSignUp = true;
        //             break;
        //         }
        //     }
        // }
        // require(hasSignUp == true , "player have not signUp");
        if(sRecord.rechargeAddress == address(0x0)){
            sRecord.rechargeRecord[msg.sender] += msg.value;
            sRecord.sumRecharge += msg.value;
            emit rechargeInfo(seasonId, msg.sender, rechargeId, msg.value, sRecord.rechargeRecord[msg.sender]);
        }
        else{
            IERC20 token = IERC20(sRecord.rechargeAddress);
            uint256 allowance = token.allowance(msg.sender, address(this));
            require(allowance >= amount, "Check the token allowance");
            token.transferFrom(msg.sender, address(this), amount);
            sRecord.rechargeRecord[msg.sender] += amount;
            sRecord.sumRecharge += amount;
            emit rechargeInfo(seasonId, msg.sender, rechargeId, amount, sRecord.rechargeRecord[msg.sender]);
        }
    }

    function getRechargeInfo( string memory seasonId, address player) public view returns (uint256, uint256){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus != SeasonStatus.Invalid, "Season is not exist");
        return (sRecord.rechargeRecord[player], sRecord.sumRecharge);
    }


    function getSeasonStatus( string memory seasonId ) public view returns ( SeasonStatusResult memory ){
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
        SeasonStatusResult memory re = SeasonStatusResult( sRecord.sumPlayers , new uint256[](4));
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
        require(sRecord.seasonStatus != SeasonStatus.Invalid, "Season Status Error");
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

    function endSeason(  string memory seasonId, uint256 unionId, address[] memory playerAddresses, uint256[] memory glorys, uint256 unionSumGlory) external onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending,  "Season Status Error");
        require(playerAddresses.length == glorys.length, "input array length do not equal");
        uint fromToIndex = 0;
        uint rankMax = sRecord.rankConfigFromTo[sRecord.rankConfigFromTo.length - 1];
        //IERC20 token = IERC20(sRecord.rewardAddress);
        for(uint i = 0; i < playerAddresses.length; i++ ){  
            address playerAddress = playerAddresses[i];
            uint256 glory = glorys[i];
            if(sRecord.unionIdMapping[playerAddress] == unionId){
               uint256 amount = glory * sRecord.reward1Amount / unionSumGlory;
               sRecord.unionRewardRecord[playerAddress] = amount; 
               transferReward(sRecord.rewardAddress, playerAddress, amount);
               //if( token.transfer(playerAddress, amount)){
               emit sendUnionRewardInfo(seasonId, playerAddress, glory, amount);
               //}
            }
            if(i < rankMax){
               uint256 to = sRecord.rankConfigFromTo[fromToIndex * 2 + 1];
               if( i + 1 > to ){
                  fromToIndex += 1;
               }
               uint256 amount = sRecord.rankConfigValue[fromToIndex];
               sRecord.gloryRewardRecord[playerAddress] = amount;
               transferReward(sRecord.rewardAddress, playerAddress, amount);
               //if( token.transfer(playerAddress, amount)){
               emit sendRankRewardInfo(seasonId, playerAddress, i + 1, amount);
               //}
            }
        }
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

    function transferReward(address rewardAddress, address toAddress, uint256 amount) internal {
        if(rewardAddress == address(0x0)){
            require(address(this).balance >=  amount, "balance is not enough");
            payable(toAddress).transfer(amount);
        }
        else{
            IERC20 token = IERC20(rewardAddress);
            uint256 balance = token.balanceOf(address(this));
            require(balance >= amount, "balance is not enough");
            token.transfer(toAddress, amount);
        }
    }
}

