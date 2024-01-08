const { ethers } = require("hardhat")


const playerLimit = 200
const FakeTestToken = "0xb4044b02c862a0bbadc3965a880d4989e2e61b00"







function toTokenAmount(value,decimal){
  return parseInt(value).toString() + "0".repeat(decimal)
}



function generateReward(BaseAmount,decimal) {
  decimal = decimal || 18
  console.log("decimals is ",decimal)
  const rewardAmount1 = toTokenAmount(BaseAmount,decimal)
  const rewardAmount2 = toTokenAmount(BaseAmount,decimal)
  const rankConfigFromTo = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20]
  const rankConfigValue = [100,80,60,50,40,30,30,20,20,10,10,10,8,8,6,6,4,4,2,2].map(a => toTokenAmount(parseInt(a)*BaseAmount*1000000 / 500 ,decimal-6))

  return {rewardAmount1,rewardAmount2,rankConfigFromTo,rankConfigValue }
}


const nftsAddrs = {"Airose": "0x0f4c5a429166608f9225e094f7e66b0bf68a53b9", "Apex": "0x99f43f11CC6b5C378eBc2Cb4eEd7CC4F5F0006C0", "SeibaraClub": "0xA8C343905212449e079B191A83fE42bfEba024B3", "TestNFT": "0xb54ab3091bDF13f01AA2f0aCE0D80e715084e502"}
const yuzu = "0xf02b3e437304892105992512539F769423a515Cb"
const wrose = ""
const rose = "0x0000000000000000000000000000000000000000"
const LOTV2Addr = "0x9A43e76Bf6361de1a80325A319cDB4f1927c0841"

const usdt ="0xdC19A122e268128B5eE20366299fc7b5b199C8e3"




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


async function StartSeason() {
   let rewardAddress ;
    //const HalfRewardAmount = 10000
    let HalfRewardAmount = 50
    let RewardDeciaml = 18


    const time = "2023-12-5-4"
//    const env = "prod"
    const env = "test"
    const network = "oasis"
    const suffix = "fixed" //db.lot_seasons.update({ "_id" : ObjectId("6530116ebff32648d2d454c0")},{$set:{"mapInfo.mapResult":2}}
    //

    if(env == "test") {
      rewardAddress = FakeTestToken//fake
      HalfRewardAmount =  10000
    }else{
      rewardAddress = usdt//fake
      if(/*test*/1){
        rewardAddress = FakeTestToken//fake
        HalfRewardAmount =  10000
      }
      if (rewardAddress == usdt ){
        RewardDeciaml = 6
      }else{
        RewardDeciaml = 18
      }
    }


    const applyTime = "2023-12-05:23:00:00+08:00"
    const startTime = "2023-12-05:23:30:00+08:00"
    const endTime =   "2023-12-14:22:00:00+08:00"

    const seasonId =  `${env}-${network}-${time}-${suffix}`

    const seasonTimeConfig = [ 
      convertToTimestamp(applyTime),
      convertToTimestamp(startTime),
      convertToTimestamp(startTime),
      convertToTimestamp(endTime),
    ]

    const {rewardAmount1,rewardAmount2,rankConfigFromTo,rankConfigValue} = generateReward(HalfRewardAmount,RewardDeciaml) 
    console.log("rewardAmount1",rewardAmount1,"rewardAmount2",rewardAmount2,"rankConfigFromTo",rankConfigFromTo,"rankConfigValue",rankConfigValue)

    //check should allowlance
    if (rewardAddress != rose) {
      const tokenIns = await ethers.getContractAt("IERC20", rewardAddress)
      const singers = await ethers.getSigners()
      const wallet = singers[0]
      const allowance = await tokenIns.allowance( wallet.address, LOTV2Addr)
      const totalReward = parseInt(rewardAmount1) + parseInt(rewardAmount2) 
      console.log("allowance ",allowance, " totalReward ",totalReward)
      if( parseInt(allowance) < totalReward) {
        await tokenIns.approve(LOTV2Addr, "1000000000000000000000000000000000") //very large
      }
    }
    const maxUnionPlayerNumDiff = 5

    const lot = await ethers.getContractAt("LeagueOfThronesV2",LOTV2Addr)
    await lot.startSeason(seasonId, playerLimit, rewardAddress, rewardAmount1, rewardAmount2, rankConfigFromTo, rankConfigValue, seasonTimeConfig,maxUnionPlayerNumDiff)
 //  await lot.setNFTAddress(seasonId,nftsAddrs.Airose,nftsAddrs.SeibaraClub)


    await lot.setNFTAddress(seasonId,nftsAddrs.Apex,nftsAddrs.SeibaraClub)
    const nftaddrs = await lot.getNFTAddresses(seasonId)
    console.log("nftaddrs",nftaddrs)


    await lot.setRechargeToken(seasonId,rose)
    const rechargeToken = await lot.getRechargeToken(seasonId)
    console.log("recharege Token is ",rechargeToken)

}


StartSeason()

//npx hardhat run scripts/startSeason.js --network emerald
//test mongodb://mongouser:hB1SXfKZJP@172.19.16.3:27017/league_of_thrones_chains_test_env?replicaSet=cmgo-o46i3i9t_0&authSource=admin
//prod mongodb://mongouser:KcGJjvUxitL98@172.19.0.14:27017/league_of_thrones_multi_chains_prod?authSource=admin
//db.lot_seasons.update({"sid":"test-oasis-2023-11-27-3-fixed"},{$set:{"mapInfo.mapResult":3}})