pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;
import "hardhat/console.sol";
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
    uint256 sumPlayers;
    address ntf1ContractAddress;
    address ntf2ContractAddress;
    address rewardAddress;
    uint256 reward1Amount;
    uint256 reward2Amount;
    uint256[] rankConfigFromTo;
    uint256[] rankConfigValue;
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

    event signUpInfo(uint256 seasonId, address player, uint256 unionId, uint256[] extraGeneralIds);
    event seasonStartInfo(uint256 seasonId , address rewardAddress, uint256 rewardAmount1, uint256 rewardAmount2, uint256[] rankConfigFromTo, uint256[] rankConfigValue);
    event endSeasonInfo( uint256 seasonId, uint256 unionId, address[] playerAddresses, uint256[] glorys, uint256 unionSumGlory);
    event sendRankRewardInfo( uint256 seasonId, address player, uint256 rank, uint256 amount);
    event sendUnionRewardInfo( uint256 seasonId, address player, uint256 glory, uint256 amount);
    mapping(uint256 => SeasonRecord) seasonRecords;
    uint256 public nowSeasonId;

    constructor() public onlyOwner{
        nowSeasonId = 0;
    }

    //start season and transfer reward to contract
    function startSeason(
        uint256 seasonId ,
        address rewardAddress,
        uint256 rewardAmount1, 
        uint256 rewardAmount2, 
        uint256[] memory rankConfigFromTo,
        uint256[] memory rankConfigValue
        ) external onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Invalid, "Season can not start repeat");
        IERC20 token = IERC20(rewardAddress);
        uint256 rewordAmount = rewardAmount1 + rewardAmount2;
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= rewordAmount, "Check the token allowance");
        token.transferFrom(msg.sender, address(this), rewordAmount);
        sRecord.seasonStatus = SeasonStatus.WaitForNTF;
        sRecord.rewardAddress = rewardAddress;
        sRecord.reward1Amount = rewardAmount1;
        sRecord.reward2Amount = rewardAmount2;
        sRecord.rankConfigFromTo = rankConfigFromTo;
        sRecord.rankConfigValue = rankConfigValue;
        emit seasonStartInfo(seasonId, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue);
    }

    //set nft address of season
    function setNFTAddress(uint256 seasonId, address ntf1Address, address ntf2Address) external onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.WaitForNTF, "Season Haven't begin or NTF have set");
        sRecord.seasonStatus = SeasonStatus.Pending;
        sRecord.ntf1ContractAddress = ntf1Address;
        sRecord.ntf2ContractAddress = ntf2Address;
        sRecord.seasonStatus = SeasonStatus.Pending;
    }

    function random(uint number) public view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty,  
            msg.sender))) % number;
    }

    function signUpGame(uint256 seasonId, uint256 ntf1TokenId, uint256 ntf2TokenId) external{
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending, "Season Status Error");
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

    function getSeasonStatus( uint256 seasonId ) public view returns ( SeasonStatusResult memory ){
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

    function getSignUpInfo( uint256 seasonId, address playerAddress) public view returns ( SeaSonInfoResult memory){
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

    function endSeason( uint256 seasonId, uint256 unionId, address[] memory playerAddresses, uint256[] memory glorys, uint256 unionSumGlory) external onlyOwner {
        SeasonRecord storage sRecord = seasonRecords[seasonId];
        require(sRecord.seasonStatus == SeasonStatus.Pending,  "Season Status Error");
        require(playerAddresses.length == glorys.length, "input array length do not equal");
        uint fromToIndex = 0;
        uint rankMax = sRecord.rankConfigFromTo[sRecord.rankConfigFromTo.length - 1];
        IERC20 token = IERC20(sRecord.rewardAddress);
        for(uint i = 0; i < playerAddresses.length; i++ ){  
            address playerAddress = playerAddresses[i];
            uint256 glory = glorys[i];
            if(sRecord.unionIdMapping[playerAddress] == unionId){
               uint256 amount = glory * sRecord.reward1Amount / unionSumGlory;
               sRecord.unionRewardRecord[playerAddress] = amount; 
               if( token.transfer(playerAddress, amount)){
                emit sendUnionRewardInfo(seasonId, playerAddress, glory, amount);
               }
            }
            if(i < rankMax){
               uint256 to = sRecord.rankConfigFromTo[fromToIndex * 2 + 1];
               if( i + 1 > to ){
                  fromToIndex += 1;
               }
               uint256 amount = sRecord.rankConfigValue[fromToIndex];
               sRecord.gloryRewardRecord[playerAddress] = amount;
               if( token.transfer(playerAddress, amount)){
                emit sendRankRewardInfo(seasonId, playerAddress, i + 1, amount);
               }
            }
        }
        emit endSeasonInfo( seasonId,  unionId,  playerAddresses, glorys, unionSumGlory);
    }
}

