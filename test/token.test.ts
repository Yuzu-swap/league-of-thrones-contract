import { AbiCoder } from "@ethersproject/abi";
import { sha256 } from "@ethersproject/sha2";
import {encodeParameters} from "./utilities/index"
import { advanceBlockTo } from "./utilities";
import { ethers } from "hardhat";
import { expect } from "chai";


describe("Token contract", function() {
  it("Deployment should assign the total supply of tokens to the owner", async function() {
    const [owner, addr1] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("BurstPoint");

    const hardhatToken = await Token.deploy();
    await hardhatToken.deployed();

    const ownerBalance = await hardhatToken.totalBalance();
    console.log(ownerBalance);
    
    await hardhatToken.ownerAdd({value: 400})

    var ownerBalance1 = await hardhatToken.totalBalance();
    console.log(ownerBalance1);

    // const shaRe = await hardhatToken.testSha("300test");
    // console.log(shaRe);

    // const strRe = await hardhatToken.testStr(100, "test");
    // console.log(strRe);

    const str = "300test";
    console.log(sha256(encodeParameters(["string"],[str])));
    await hardhatToken.beginGame(0, sha256(encodeParameters(["string"],[str])));

    await hardhatToken.connect(addr1).bet(0, 200, {value: 100});

    await advanceBlockTo(50);

    await hardhatToken.connect(addr1).escape(0);


    ownerBalance1 = await hardhatToken.totalBalance();
    console.log(ownerBalance1);

    const addr1blance1 = await ethers.provider.getBalance(addr1.address);
    console.log(addr1blance1);

    await advanceBlockTo(111);

    await hardhatToken.closeGame(0, 300, "test");

    const ownerBalance2 = await hardhatToken.totalBalance();
    console.log(ownerBalance2);

    const addr1blance = await ethers.provider.getBalance(addr1.address);
    console.log(addr1blance);

    //expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
  });
});

