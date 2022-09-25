import { AbiCoder } from "@ethersproject/abi";
import { sha256 } from "@ethersproject/sha2";
import {encodeParameters} from "./utilities/index"
import { advanceBlockTo } from "./utilities";
import { ethers } from "hardhat";
import { expect } from "chai";


describe("Token contract", function() {
  it("Deployment should assign the total supply of tokens to the owner", async function() {
    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const extraUserNum = 200;

    const extraWallet = []
    
    let playerAddresses = [owner.address, addr1.address, addr2.address ,addr4.address]
    let glorys =  [4, 3, 3, 1 ]
    let unionGlory = 5
    

    const NFT1 = await ethers.getContractFactory("TestNFT");
    const NFT2 = await ethers.getContractFactory("TestNFT");
    const League = await ethers.getContractFactory("contracts/LeagueOfThrones.sol:LeagueOfThrones")
    const YUZUToken = await ethers.getContractFactory("YUZUToken")

    const nft1 = await NFT1.deploy();
    const nft2 = await NFT2.deploy();
    const LeagueCon = await League.deploy();

    LeagueCon.on('signUpInfo', ( seasonId, playerLimit ,address, unionId, generalIds) => {
      // THIS LINE NEVER GETS HIT
      console.log('signUpInfo', seasonId, playerLimit, address, unionId, generalIds)
    })
    LeagueCon.on('sendRankRewardInfo', ( seasonId, playerAddress, rank, amount) => {
      // THIS LINE NEVER GETS HIT
      console.log('sendRankRewardInfo', seasonId, playerAddress, rank, amount)
    })
    LeagueCon.on('sendUnionRewardInfo', ( seasonId, playerAddress, glory, amount) => {
      // THIS LINE NEVER GETS HIT
      console.log('sendUnionRewardInfo', seasonId, playerAddress, glory, amount)
    })

    const yuzu = await YUZUToken.deploy();

    const baseValue = ethers.BigNumber.from("1000000000000000000")
    
    let a = ethers.BigNumber.from("200")
    await yuzu.mint(owner.address, a.mul(baseValue))

    await yuzu.approve(LeagueCon.address, a.mul(baseValue))

    const startTx = await LeagueCon.startSeason(
      "test:one", 300 ,yuzu.address, 5000, 5000, 
      [1, 1, 2, 2, 3, 3, 4, 5, 6, 10, 11, 20], 
      [1100, 800, 500, 300, 200, 100], 
      [1664106109, 1664107109, 1664107109, 1664107109])
    await startTx.wait()

    console.log(" league amount ", await yuzu.balanceOf(LeagueCon.address))

    const TokenId1 = await nft1.mint(owner.address , "test1")
    const TokenId2 = await nft2.mint(owner.address , "test1")
    const recipt1 = await TokenId1.wait()
    const recipt2 = await TokenId2.wait()
    await LeagueCon.setNFTAddress("test:one", nft1.address, nft2.address);
    await LeagueCon.signUpGame("test:one", 1, 12);
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
    console.log("endTx",endTx, recipt.gasUsed)

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



    //console.log( "tokenId1" , recipt1, "tokenId2", recipt2)

    // const ownerBalance = await hardhatToken.totalBalance();
    // console.log(ownerBalance);
    
    // await hardhatToken.ownerAdd({value: 400})

    // var ownerBalance1 = await hardhatToken.totalBalance();
    // console.log(ownerBalance1);

    // // const shaRe = await hardhatToken.testSha("300test");
    // // console.log(shaRe);

    // // const strRe = await hardhatToken.testStr(100, "test");
    // // console.log(strRe);

    // const str = "300test";
    // console.log(encodeParameters(["string"],[str]));
    // console.log(sha256(encodeParameters(["string"],[str])).toString());
    // await hardhatToken.beginGame(0, sha256(encodeParameters(["string"],[str])));

    // await hardhatToken.connect(addr1).bet(0, 200, {value: 100});

    // await advanceBlockTo(50);

    // await hardhatToken.connect(addr1).escape(0);


    // ownerBalance1 = await hardhatToken.totalBalance();
    // console.log(ownerBalance1);

    // const addr1blance1 = await ethers.provider.getBalance(addr1.address);
    // console.log(addr1blance1);

    // await advanceBlockTo(111);

    // await hardhatToken.closeGame(0, 300, "test");

    // const ownerBalance2 = await hardhatToken.totalBalance();
    // console.log(ownerBalance2);

    // const addr1blance = await ethers.provider.getBalance(addr1.address);
    // console.log(addr1blance);

    // const aaa = await hardhatToken.getGameRecords(0);
    // console.log(aaa);

    //expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
    await new Promise(res => setTimeout(() => res(null), 5000));
  });
});

