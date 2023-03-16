const Web3 = require("web3")
const ABI = require('../abi/MultiTransferHelper.json')


const rewardStr = {"contractAddressInput":["0x7aaa84e9e0f9af03c45f346854a7f336181e89fb","0x19474fde19b47a36cc26ae93d46ebbcde83fa56c","0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2","0xa37b1a6905dfb2686ad0f6104d7358dfb1464b09","0x32aef35d6d3da5bdf8a008c42a5591694dac966c","0x92c9d3836f9f503355f234dec846b65786ab07be","0x0b4509f330ff558090571861a723f71657a26f78","0x4600086f015d3c995bbaeb61a978524268a8cae7"],"contractGloryInput":[558674,555960,338877,116514,45553,22742,14394,3910],"globalGloryRankInfo":[{"glory":558674,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":555960,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"glory":338877,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":116514,"unionId":3,"username":"0xa37b1a6905dfb2686ad0f6104d7358dfb1464b09"},{"glory":45553,"unionId":1,"username":"0x32aef35d6d3da5bdf8a008c42a5591694dac966c"},{"glory":22742,"unionId":4,"username":"0x92c9d3836f9f503355f234dec846b65786ab07be"},{"glory":14394,"unionId":1,"username":"0x0b4509f330ff558090571861a723f71657a26f78"},{"glory":3910,"unionId":4,"username":"0x4600086f015d3c995bbaeb61a978524268a8cae7"}],"gloryRewardResult":[{"count":105,"glory":558674,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":80,"glory":555960,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"count":60,"glory":338877,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":50,"glory":116514,"unionId":3,"username":"0xa37b1a6905dfb2686ad0f6104d7358dfb1464b09"},{"count":40,"glory":45553,"unionId":1,"username":"0x32aef35d6d3da5bdf8a008c42a5591694dac966c"},{"count":30,"glory":22742,"unionId":4,"username":"0x92c9d3836f9f503355f234dec846b65786ab07be"},{"count":30,"glory":14394,"unionId":1,"username":"0x0b4509f330ff558090571861a723f71657a26f78"},{"count":20,"glory":3910,"unionId":4,"username":"0x4600086f015d3c995bbaeb61a978524268a8cae7"}],"id":"rewardglobalstate","seasonEnd":true,"unionGloryRankInfo":[[{"glory":45553,"unionId":1,"username":"0x32aef35d6d3da5bdf8a008c42a5591694dac966c"},{"glory":14394,"unionId":1,"username":"0x0b4509f330ff558090571861a723f71657a26f78"}],[],[{"glory":558674,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"glory":555960,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"glory":338877,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"glory":116514,"unionId":3,"username":"0xa37b1a6905dfb2686ad0f6104d7358dfb1464b09"}],[{"glory":22742,"unionId":4,"username":"0x92c9d3836f9f503355f234dec846b65786ab07be"},{"glory":3910,"unionId":4,"username":"0x4600086f015d3c995bbaeb61a978524268a8cae7"}]],"unionGlorySum":1570025,"unionRewardResult":[{"count":177.91882294867915,"glory":558674,"unionId":3,"username":"0x7aaa84e9e0f9af03c45f346854a7f336181e89fb"},{"count":177.05450550150476,"glory":555960,"unionId":3,"username":"0x19474fde19b47a36cc26ae93d46ebbcde83fa56c"},{"count":107.92089297941115,"glory":338877,"unionId":3,"username":"0x76d339e8db09d0e0aebd1a1330e5ec10f2634ca2"},{"count":37.10577857040493,"glory":116514,"unionId":3,"username":"0xa37b1a6905dfb2686ad0f6104d7358dfb1464b09"}],"unionWinId":3}


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

function handleRewardInfo(){
    const contractAddressInput = rewardStr["contractAddressInput"]
    const gloryReward = rewardStr.gloryRewardResult;
    const unionReward = rewardStr.unionRewardResult;
    let out = []
    let addressList = []
    for(let i = 0; i< gloryReward.length; i++ ){
        if( addressList.indexOf(gloryReward[i].username) == -1){
            addressList.push(gloryReward[i].username)
        }
        out.push(
            {
                address: gloryReward[i].username,
                unionId: gloryReward[i].unionId,
                gloryReward: gloryReward[i].count,
                unionReward: 0,
                hash: '0x4301447c708635ee123cd4818940435db8e7801d8d324908dbbe932a3c150f13'
            }
        )
    }
    for(let i in unionReward){
        let iOfAddr =  addressList.indexOf(unionReward[i].username)
        if(iOfAddr == -1){
            continue
        }
        out[iOfAddr].unionReward = parseFloat(unionReward[i].count.toFixed(6))
    }
    //console.log("total reward")
    //console.log(out)
    return out
}








const web3 = new Web3('https://emerald.oasis.dev')
//const contractAddress = '0xD839e3eF8f1cD3cA0A851CEc2E82f340863054A3'
const privateKey = process.env.PK
// 4. Create contract instance
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

function wait(ms) {
    return new Promise(resolve =>setTimeout(() =>resolve(), ms));
};

async function transferETH( to, unionReward, gloryReward ){
    console.log(`Send ${unionReward} + ${gloryReward} to ${to}`);
    await wait(2000)
    const createTransaction = await web3.eth.accounts.signTransaction(
        {
          from: "0x04C535c9F175cB8980B43617fB480412c7E341E4",
          to: to,
          data: web3.utils.toHex(`Congrats on Winning https://leagueofthrones.com/ 2nd Season. Your rewards are ${unionReward} for the team rewards and ${gloryReward} for glory ranking rewards.`),
          gas: 50000,
          value: web3.utils.toWei((unionReward + gloryReward).toString(), 'ether')
        },
       privateKey
    );
    const createReceipt = await web3.eth.sendSignedTransaction(createTransaction.rawTransaction);
    console.log(`Tx successful with hash: ${createReceipt.transactionHash}`);
    return createReceipt.transactionHash
}

//transferETH()

async function send(){
    let out = handleRewardInfo()
    for(let i = 0; i < out.length; i++)
    {
        console.log(i)
        let txHash = await transferETH(out[i].address, out[i].unionReward, out[i].gloryReward)
        out[i].hash = txHash
    }
    console.log(out)
}

send()