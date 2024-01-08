const { ethers } = require("hardhat")
const {Configs} = require("./config.js")

const network = process.env.HARDHAT_NETWORK
console.log("Network ",network)
const config = Configs[network]
if(!config){
  console.log("No config for network ",network)
  return
}


async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function toTokenAmount(value,decimal){
  return parseInt(value).toString() + "0".repeat(decimal)
}

function generateReward(BaseAmount,decimal) {
  decimal = decimal || 18
  const rewardAmount1 = toTokenAmount(BaseAmount,decimal)
  const rewardAmount2 = toTokenAmount(BaseAmount,decimal)
  const rankConfigFromTo = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20]
  const rankConfigValue = [100,80,60,50,40,30,30,20,20,10,10,10,8,8,6,6,4,4,2,2].map(a => toTokenAmount(parseInt(a)*BaseAmount*1000000 / 500 ,decimal-6))
  return {rewardAmount1,rewardAmount2,rankConfigFromTo,rankConfigValue }
}



function convertToTimestamp(dateString) {
  // 将字符串解析为 Date 对象
  const date = new Date(dateString);
  // 将本地时间转换为 UTC 时间并获取其时间戳
  const utcTimestamp = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
    date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getUTCMilliseconds());
  // 将 UTC 时间戳转换为 Unix 时间戳（即秒数）
  const unixTimestamp = Math.floor(utcTimestamp / 1000);
  return unixTimestamp;
}


async function StartSeason(env,config,run) {

    const {playerLimit,nftsAddrs,contractAddr,rechargeToken,rewardToken,halfRewardAmount,rewardDecimal} = config
    const time = "2024-01-06-1"
    const suffix = "1"
    const seasonId =  `${env}-${network}-${time}-${suffix}`
    console.log("season id is ",seasonId)
    const rewardAddress = rewardToken//fake



    const applyTime = "2024-01-06:03:00:00+08:00"
    const startTime = "2024-01-07:22:00:00+08:00"
    const endTime =   "2024-01-22:22:00:00+08:00"


    const seasonTimeConfig = [ 
      convertToTimestamp(applyTime),
      convertToTimestamp(startTime),
      convertToTimestamp(startTime),
      convertToTimestamp(endTime),
    ]

    const {rewardAmount1,rewardAmount2,rankConfigFromTo,rankConfigValue} = generateReward(halfRewardAmount,rewardDecimal) 
    const maxUnionPlayerNumDiff = 5

    const lot = await ethers.getContractAt("LeagueOfThronesV2",contractAddr)
    if (run){
      console.log("before start season",seasonId, playerLimit, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue, seasonTimeConfig,maxUnionPlayerNumDiff)
      await lot.startSeason(seasonId, playerLimit, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue, seasonTimeConfig,maxUnionPlayerNumDiff)
      await sleep(5000)
    }



    const [firstNft,secondNft] =  [nftsAddrs[Object.keys(nftsAddrs)[0]],nftsAddrs[Object.keys(nftsAddrs)[1]]]
    console.log("firstNft",firstNft,"secondNft",secondNft)

    if (run){
      await lot.setNFTAddress(seasonId,firstNft,secondNft)
      await sleep(5000)
    }

    const getNftaddrs = await lot.getNFTAddresses(seasonId)
    console.log("nftaddrs",getNftaddrs)


    if (run){
      if (network == "zetatest"){
        await sleep(5000)
      }
      await lot.setRechargeToken(seasonId,rechargeToken)
      await sleep(5000)
    }
    const getRechargeToken = await lot.getRechargeToken(seasonId)
    console.log("recharege Token is ",getRechargeToken)

}


//StartSeason("test",config,true)
StartSeason("prod",config,true)

//test mongodb://mongouser:hB1SXfKZJP@172.19.16.3:27017/league_of_thrones_chains_test_env?replicaSet=cmgo-o46i3i9t_0&authSource=admin
//prod mongodb://mongouser:KcGJjvUxitL98@172.19.0.14:27017/league_of_thrones_multi_chains_prod?authSource=admin
//npx hardhat run scripts/startBSCSeason.js --network  bsc

//prod-bsc-2024-01-06-1-1