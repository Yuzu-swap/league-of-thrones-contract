const Web3 = require("web3")
const ABI = require('../abi/MultiTransferHelper.json')

function outputReward(type, addressList, reward)
{
    console.log(type)
    let re = []
    for(let i in addressList)
    {
        if(reward[i]!=0){
            re.push({
                address: addressList[i],
                reward: reward[i]
            })
        }
    }
    console.log(re)
}


const rewardStr = {"contractAddressInput":["0xbd7da5cc162ccc58502eb93361e157ce19a32fd8","0x678452d7a5199a0d6216affb3ecf9ff9adb83d80","0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2","0x6f721d423e5b97f9740ad404371c48dce4a9c173","0x19474fde19b47a36cc26ae93d46ebbcde83fa56c","0x7aaa84e9e0f9af03c45f346854a7f336181e89fb","0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2","0x7aaa84e9e0f9af03c45f346854a7f336181e89fb","0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2","0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2","0x44a0ab343ba3c4d86e2eb7835ee995a22c6a72fb","0x7aaa84e9e0f9af03c45f346854a7f336181e89fb","0xb4c18d231d6f50eae516581a385b255b802b9e03"],"contractGloryInput":[922883,219403,187557,177091,106003,103564,99398,84614,63736,52550,44062,38537,30169],"globalGloryRankInfo":[{"glory":922883,"unionId":3,"username":"0xbd7da5cc162ccc58502eb93361e157ce19a32fd8"},{"glory":219403,"unionId":3,"username":"0x678452d7a5199a0d6216affb3ecf9ff9adb83d80"},{"glory":187557,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":177091,"unionId":3,"username":"0x6f721d423e5b97f9740ad404371c48dce4a9c173"},{"glory":106003,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"glory":103564,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":99398,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":84614,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":63736,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":52550,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":44062,"unionId":2,"username":"0x44a0ab343ba3c4d86e2eb7835ee995a22c6a72fb"},{"glory":38537,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":30169,"unionId":3,"username":"0xb4c18d231d6f50eae516581a385b255b802b9e03"}],"gloryRewardResult":[{"count":105,"glory":922883,"unionId":3,"username":"0xbd7da5cc162ccc58502eb93361e157ce19a32fd8"},{"count":80,"glory":219403,"unionId":3,"username":"0x678452d7a5199a0d6216affb3ecf9ff9adb83d80"},{"count":60,"glory":187557,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":50,"glory":177091,"unionId":3,"username":"0x6f721d423e5b97f9740ad404371c48dce4a9c173"},{"count":40,"glory":106003,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"count":30,"glory":103564,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":30,"glory":99398,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":20,"glory":84614,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":20,"glory":63736,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":10,"glory":52550,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":10,"glory":44062,"unionId":2,"username":"0x44a0ab343ba3c4d86e2eb7835ee995a22c6a72fb"},{"count":9,"glory":38537,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":8,"glory":30169,"unionId":3,"username":"0xb4c18d231d6f50eae516581a385b255b802b9e03"}],"id":"rewardglobalstate","seasonEnd":true,"unionGloryRankInfo":[[],[{"glory":44062,"unionId":2,"username":"0x44a0ab343ba3c4d86e2eb7835ee995a22c6a72fb"}],[{"glory":922883,"unionId":3,"username":"0xbd7da5cc162ccc58502eb93361e157ce19a32fd8"},{"glory":219403,"unionId":3,"username":"0x678452d7a5199a0d6216affb3ecf9ff9adb83d80"},{"glory":187557,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":177091,"unionId":3,"username":"0x6f721d423e5b97f9740ad404371c48dce4a9c173"},{"glory":106003,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"glory":103564,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":99398,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":84614,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":63736,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":52550,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":38537,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":30169,"unionId":3,"username":"0xb4c18d231d6f50eae516581a385b255b802b9e03"}],[]],"unionGlorySum":2085505,"unionRewardResult":[{"count":221.26127724460022,"glory":922883,"unionId":3,"username":"0xbd7da5cc162ccc58502eb93361e157ce19a32fd8"},{"count":52.60188779216545,"glory":219403,"unionId":3,"username":"0x678452d7a5199a0d6216affb3ecf9ff9adb83d80"},{"count":44.96680660079932,"glory":187557,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":42.45758221629773,"glory":177091,"unionId":3,"username":"0x6f721d423e5b97f9740ad404371c48dce4a9c173"},{"count":25.414228208515443,"glory":106003,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"count":24.829477752390908,"glory":103564,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":23.83067890031431,"glory":99398,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":20.28621365089031,"glory":84614,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":15.280711386450763,"glory":63736,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":12.598866941100598,"glory":52550,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":9.239249006835275,"glory":38537,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":7.233020299639656,"glory":30169,"unionId":3,"username":"0xb4c18d231d6f50eae516581a385b255b802b9e03"}],"unionWinId":3}
const contractAddressInput = rewardStr["contractAddressInput"]
const gloryReward = rewardStr.gloryRewardResult;
const unionReward = rewardStr.unionRewardResult;
let addressList = []
let rankReward = []
for(let i = 0; i< gloryReward.length; i++ ){
    if( addressList.indexOf(gloryReward[i].username) == -1){
        addressList.push(gloryReward[i].username)
    }
    rankReward.push(gloryReward[i].count)
}
let finalReward = []
let unionCheck = []
let unionOutputReward = new Array(addressList.length).fill(0)
for(let index in addressList){
    finalReward.push(rankReward[index])
}
outputReward("rank reward", addressList, finalReward)
unionCheck = new Array( finalReward.length ).fill( false )
let unionSumGlory = 0
for(let i in unionReward){
    let iOfAddr =  addressList.indexOf(unionReward[i].username)
    if(iOfAddr == -1){
        continue
    }
    if( unionCheck[iOfAddr] == false ){
        unionSumGlory += unionReward[i].glory
        unionCheck[iOfAddr] = true
    }
}
unionCheck = new Array( finalReward.length ).fill( false )
for(let i in unionReward){
    let iOfAddr =  addressList.indexOf(unionReward[i].username)
    if(iOfAddr == -1){
        continue
    }
    if( unionCheck[iOfAddr] == false ){
        finalReward[iOfAddr] += parseInt(((unionReward[i].glory / unionSumGlory ) * 500).toFixed())
        unionOutputReward[iOfAddr] += parseInt(((unionReward[i].glory / unionSumGlory ) * 500).toFixed())
        unionCheck[iOfAddr] = true
    }
}
outputReward("union 3 win reward", addressList, unionOutputReward)
let out = []
for(let i in addressList){
    out.push(
        {
            address: addressList[i],
            rose: finalReward[i]
        }
    )
}
console.log("total reward")
console.log(out)





// const web3 = new Web3('https://emerald.oasis.dev')
// const contractAddress = '0xD839e3eF8f1cD3cA0A851CEc2E82f340863054A3'
// const privateKey = process.env.PK
// // 4. Create contract instance
// const incrementer = new web3.eth.Contract(ABI.abi, contractAddress);

// let conRewardInput = []
// let totalNum = 0
// for(let value of finalReward ){
//     conRewardInput.push( web3.utils.toWei(value.toString(), 'ether') )
//     totalNum += value
// }
// let conTotalinput = web3.utils.toWei(totalNum.toString(), 'ether') 

// // 5. Build increment tx
// const incrementTx = incrementer.methods.transferManyValue( addressList, conRewardInput,  8 ,conTotalinput, "season reward from https://app.leagueofthrones.com/ " );

// // 6. Create increment function
// const increment = async () => {
  
//   // Sign Tx with PK
//   const createTransaction = await web3.eth.accounts.signTransaction(
//     {
//       from: "0x04C535c9F175cB8980B43617fB480412c7E341E4",
//       to: contractAddress,
//       data: incrementTx.encodeABI(),
//       gas: await incrementTx.estimateGas({value: conTotalinput }),
//       value: conTotalinput
//     },
//     privateKey
//   );

//   // Send Tx and Wait for Receipt
//   const createReceipt = await web3.eth.sendSignedTransaction(createTransaction.rawTransaction);
//   console.log(`Tx successful with hash: ${createReceipt.transactionHash}`);
// };

// 9. Call increment function
//increment()