const Web3 = require("web3")
const ABI = require('../abi/MultiTransferHelper.json')
const https = require('https');
const { ethers } = require("hardhat");
const {Configs} = require("./config.js")
const Decimals = require("decimal.js");
const fs  = require("fs");


const network = process.env.HARDHAT_NETWORK
console.log("Network ",network)
const config = Configs[network]
if(!config){
  console.log("No config for network ",network)
  return
}


const NativeToken = "0x0000000000000000000000000000000000000000"




async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}


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

function handleRewardInfo(rewardStr){
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
    const singers = await ethers.getSigners()
    const wallet = singers[0].address
    const createTransaction = await web3.eth.accounts.signTransaction(
        {
          from: wallet,
          to: to,
          data: web3.utils.toHex(`Congrats on Winning https://leagueofthrones.com/ 2nd Season. Your rewards are ${unionReward} for the team rewards and ${gloryReward} for glory ranking rewards.`),
          value: web3.utils.toWei((unionReward + gloryReward).toString(), 'ether')
        },
       privateKey
    );
    const createReceipt = await web3.eth.sendSignedTransaction(createTransaction.rawTransaction);
    console.log(`Tx successful with hash: ${createReceipt.transactionHash}`);
    return createReceipt.transactionHash
}

async function transferErc20(tokenAddr, to, unionReward, gloryReward ,decimal,run){
    console.log(`Send ${unionReward} + ${gloryReward} to ${to}`);
    if(run){
        await wait(2000)
    }
    const Erc20 = await ethers.getContractAt("ERC20",tokenAddr);

    if(!decimal){
        decimal = 18
    }
    const total =  new Decimals(unionReward + gloryReward).mul(10**decimal).toFixed(0)
    console.log("transferErc20 total is ", total)
    if ( parseInt(total) == 0){
        return "zero amount"
    }

    if (run){
        const res = await Erc20.transfer(to, web3.utils.toWei((unionReward + gloryReward).toString(), 'ether'))
        console.log(`Tx successful with hash: res`,res)
        return res.hash
    }else{
        return ""
    }
}

async function getContent(url) {
    return new Promise((resolve, reject) => {
      https.get(url, res => {
        let data = '';
        res.on('data', chunk => {
          data += chunk;
        });
        res.on('end', () => {
          resolve(data);
        });
      }).on('error', err => {
        reject(err);
      });
    });
  }




async function sendReward(contractAddr, sid,rewardToken,rewardDecimal, run ){

    const rewardStr = await getContent("https://app.leagueofthrones.com/web/state/rewardglobalstate/" + sid)
    console.log("reward str are ", rewardStr)
    const reward = JSON.parse(rewardStr)

    let out = handleRewardInfo(reward)
    const LOTV2 = await ethers.getContractAt("LeagueOfThronesV2", contractAddr)

    const rewardTokenIns = await ethers.getContractAt("ERC20", rewardToken)
    const singers = await ethers.getSigners()
    const wallet = singers[0].address

    console.log("wallet is ",wallet)
    const rewardBalance = await rewardTokenIns.balanceOf(wallet)
    console.log("reward balance is ", parseFloat(rewardBalance.toString())/1e18)

    const robotWallets = getRobotWallets()

    for(let i = 0; i < out.length; i++)
    {

        console.log(i)
        let txHash = "fake"
        if (rewardToken.toLocaleLowerCase()  == NativeToken){ 
            if (run){
                txHash = await transferETH(out[i].address, out[i].unionReward, out[i].gloryReward)
            }
        }else{
            txHash = await transferErc20(rewardToken,out[i].address, out[i].unionReward, out[i].gloryReward,rewardDecimal,run)
            await sleep(4000)
        }
        out[i].hash = txHash
        out[i].isRobot = robotWallets[out[i].address.toLocaleLowerCase()] ? 1 : 0
    }
    console.log(out)

    const totalRobotReward = out.filter( i=>i.isRobot ).reduce((a,b)=>a+b.unionReward+b.gloryReward,0)
    const totalReward = out.reduce((a,b)=>a+b.unionReward+b.gloryReward,0)
    console.log("total robot reward is ",totalRobotReward)
    console.log("total robot reward is ",totalReward)

}


async function testSend(){
    const yuzu = "0xf02b3e437304892105992512539F769423a515Cb"
    const res= await transferErc20(yuzu,"0x04C535c9F175cB8980B43617fB480412c7E341E4",1,1)
    console.log("Res is ",res)
}


function getRobotWallets() {
    const walletFile = "/data/newproject/league-of-thrones/throne-underlying/src/BotLogic/BotJS/data/wallets.txt"
    const  res  = {}
    fs.readFileSync(walletFile, 'utf8').split('\n').forEach(function(line){
        res[line.split(",")[0].toLocaleLowerCase()] = 1
    });
    return res
}


const {playerLimit,nftsAddrs,contractAddr,rechargeToken,rewardToken,halfRewardAmount,rewardDecimal} = config


sendReward(contractAddr,"prod-bsc-2023-12-25-1-2",rewardToken,rewardDecimal,false)

//prod-bsc-2023-12-22-2-1
//prod-bsc-2023-12-25-1-2