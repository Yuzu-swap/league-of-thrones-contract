import { AbiCoder } from "@ethersproject/abi";
import { sha256 } from "@ethersproject/sha2";
import {encodeParameters} from "./utilities/index"
import { advanceBlockTo } from "./utilities";
import { ethers } from "hardhat";
import { expect } from "chai";


describe("Token contract", function() {
  it("Deployment should assign the total supply of tokens to the owner", async function() {
    const [owner, addr1] = await ethers.getSigners();

    const NFT1 = await ethers.getContractFactory("TestNFT");
    const NFT2 = await ethers.getContractFactory("TestNFT");
    const League = await ethers.getContractFactory("LeagueOfThrones")

    const nft1 = await NFT1.deploy();
    const nft2 = await NFT2.deploy();
    const LeagueCon = await League.deploy();

    const TokenId1 = await nft1.mint(owner.address , "test1")
    const TokenId2 = await nft2.mint(owner.address , "test1")
    const recipt1 = await TokenId1.wait()
    const recipt2 = await TokenId2.wait()
    nft1.on('logTest', (address , tokenId) => {
      // THIS LINE NEVER GETS HIT
      console.log('###########', address, tokenId)
    })
    await LeagueCon.setNFTAddress(1, nft1.address, nft2.address);
    await LeagueCon.signUpGame(1, 1, 12);
    const result1 = await LeagueCon.getSeasonStatus(1);
    console.log( "getSeasonStatus",  result1)

    const result2 = await LeagueCon.getSignUpInfo(1, owner.address)
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

