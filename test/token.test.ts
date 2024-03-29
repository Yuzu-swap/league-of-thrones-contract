import { AbiCoder } from "@ethersproject/abi";
import { sha256 } from "@ethersproject/sha2";
import {ADDRESS_ZERO, encodeParameters} from "./utilities/index"
import { advanceBlockTo } from "./utilities";
import { ethers } from "hardhat";
import { expect } from "chai";


describe("Token contract", function() {
  it("Deployment should assign the total supply of tokens to the owner", async function() {
    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const extraUserNum = 10;

    const extraWallet = []
    
    let playerAddresses = [owner.address, addr1.address, addr2.address ,addr4.address]
    let glorys =  [4, 3, 3, 1 ]
    let unionGlory = 5
    

    const NFT1 = await ethers.getContractFactory("TestNFT");
    const NFT2 = await ethers.getContractFactory("TestNFT");
    //const League = await ethers.getContractFactory("contracts/LeagueOfThrones.sol:LeagueOfThrones")
    const League = await ethers.getContractFactory("contracts/LeagueOfThronesV2.sol:LeagueOfThrones")
    const YUZUToken = await ethers.getContractFactory("YUZUToken")

    const nft1 = await NFT1.deploy();
    const nft2 = await NFT2.deploy();
    const LeagueCon = await League.deploy();
    LeagueCon.on('rechargeInfo', ( seasonId, playerAddress, amount, totalAmount) => {
      // THIS LINE NEVER GETS HIT
      console.log('rechargeInfo', seasonId, playerAddress, amount, totalAmount)
    })

    LeagueCon.on('signUpInfo', ( seasonId, address, unionId, generalIds) => {
      // THIS LINE NEVER GETS HIT
      console.log('signUpInfo', seasonId, address, unionId, generalIds)
    })
    LeagueCon.on('sendRankRewardInfo', ( seasonId, playerAddress, rank, amount) => {
      // THIS LINE NEVER GETS HIT
      console.log('sendRankRewardInfo', seasonId, playerAddress, rank, amount)
    })
    LeagueCon.on('sendUnionRewardInfo', ( seasonId, playerAddress, glory, amount) => {
      // THIS LINE NEVER GETS HIT
      console.log('sendUnionRewardInfo', seasonId, playerAddress, glory, amount)
    })

    await new Promise(res => setTimeout(() => res(null), 4000));

    const yuzu = await YUZUToken.deploy();

    const baseValue = ethers.BigNumber.from("1000000000000000000")
    
    let a = ethers.BigNumber.from("200")
    await yuzu.mint(owner.address, a.mul(baseValue))

    await yuzu.approve(LeagueCon.address, a.mul(baseValue))
    let now = parseInt(new Date().getTime() / 1000 + '')

    const startTx = await LeagueCon.startSeason(
      "test:one", 300 ,/*yuzu.address*/ "0x0000000000000000000000000000000000000000" , 5000, 5000, 
      [1, 1, 2, 2, 3, 3, 4, 5, 6, 10, 11, 20], 
      [1100, 800, 500, 300, 200, 100], 
      [now, now+ 3600 , now+ 3600, now+ 3600], { value: 10000 })
    await startTx.wait()

  
    console.log(" league amount ", await yuzu.balanceOf(LeagueCon.address))

    const TokenId1 = await nft1.mint(owner.address , "test1")
    const TokenId2 = await nft2.mint(owner.address , "test1")
    const recipt1 = await TokenId1.wait()
    const recipt2 = await TokenId2.wait()
    await LeagueCon.setNFTAddress("test:one", nft1.address, nft2.address);
    
    expect( (await LeagueCon.getNFTAddresses("test:one")).toString()).to.equal([nft1.address, nft2.address].toString())

    await LeagueCon.signUpGame("test:one", 1, 12);
    await LeagueCon.setRechargeToken("test:one", yuzu.address)
    console.log("recharge info", await LeagueCon.getRechargeToken("test:one"))
    console.log(
      "before recharge",
      await yuzu.balanceOf(owner.address)
      )

    let rechargeTx = await LeagueCon.recharge("test:one", 1 ,10000000000, {value: 100000000})
    let receipt = await rechargeTx.wait()

    for (const event of receipt.events) {
      console.log(`Event ${event.event} with args ${event.args}`);
    }
    console.log(
      "after recharge",
      await yuzu.balanceOf(owner.address)
      )

    console.log("recharge Info", await LeagueCon.getRechargeInfo("test:one", owner.address))
    await LeagueCon.connect(addr1).signUpGame("test:one", 1, 12);
    await LeagueCon.connect(addr2).signUpGame("test:one", 1, 12);
    await LeagueCon.connect(addr3).signUpGame("test:one", 1, 12);
    await LeagueCon.connect(addr4).signUpGame("test:one", 1, 12);
    let unionId = 1;
    for( let i=0; i < extraUserNum; i++){
      // Get a new wallet
      unionId ++ 
      if(unionId == 5){
        unionId = 1
      }
      let wallet = ethers.Wallet.createRandom();
      // add the provider from Hardhat
      wallet =  wallet.connect(ethers.provider);
      // send ETH to the new wallet so it can perform a tx
      await owner.sendTransaction({to: wallet.address, value: ethers.utils.parseEther("1")});
      await LeagueCon.connect(wallet).signUpGame("test:one", 1, 12)
      extraWallet.push( wallet )
      if(unionId == 1){
        playerAddresses.push(wallet.address)
        glorys.push(1)
        unionGlory += 1
      }
    }
   
    const endTx = await LeagueCon.endSeason(
      "test:one", 
      1,
      playerAddresses,
      glorys,
      unionGlory)
   
    const recipt = await endTx.wait()
    console.log("endTx",endTx, recipt)

    console.log(
      "end query",
      await yuzu.balanceOf(owner.address),
      await yuzu.balanceOf(addr1.address), 
      await yuzu.balanceOf(addr2.address), 
      await yuzu.balanceOf(addr4.address),
      await yuzu.balanceOf(LeagueCon.address)
      )

    const result1 = await LeagueCon.getSeasonStatus("test:one");
    console.log( "getSeasonStatus",  result1)

    const result2 = await LeagueCon.getSignUpInfo("test:one", owner.address)
    console.log( "getSignUpInfo",  result2)

    // const withdrawTx =  await LeagueCon.withdraw(yuzu.address, 5000001801)
    // const wdRecipt = await withdrawTx.wait()
    // console.log(
    //   "end withdraw",
    //   await yuzu.balanceOf(LeagueCon.address)
    //   )
    // await owner.sendTransaction({to: LeagueCon.address, value: ethers.utils.parseEther("1")});
    // console.log("before eth withdraw", await owner.provider?.getBalance(LeagueCon.address))
    // const withdrawTx1 =  await LeagueCon.withdraw( ADDRESS_ZERO , 60000000)
    // const wdRecipt1 = await withdrawTx1.wait()
    // console.log("after eth withdraw", await owner.provider?.getBalance(LeagueCon.address))


    await new Promise(res => setTimeout(() => res(null), 4000));
  });
});

