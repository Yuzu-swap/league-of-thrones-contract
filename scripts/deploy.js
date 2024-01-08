const { ethers } = require("hardhat")

async function deployLotContract() {

    const LotContract = await ethers.getContractFactory("LeagueOfThronesV2");
    const ins = await LotContract.deploy()
    await ins.deployed();
    console.log(`LotContract deployed to ${ins.address}`);

    const fakeToken = "0xb4044b02c862a0bbadc3965a880d4989e2e61b00"
    const tokenIns = await ethers.getContractAt("IERC20", fakeToken)
    await tokenIns.approve(ins.address, "1000000000000000000000000000000")
    console.log("approve success")
}


//deployLotContract()


async function deployLotContractToChain() {
    const LotContract = await ethers.getContractFactory("LeagueOfThronesV2");
    const ins = await LotContract.deploy()
    await ins.deployed();
    console.log(`LotContract deployed to ${ins.address}`);
}


async function deployFakeToken() {
    const FakeToken = await ethers.getContractFactory("ERC20Mock");
    const ins = await FakeToken.deploy("DummyLOTToken","DummyLOTToken","100000000000000000000000000")
    console.log("FakeToken deployed to ",ins.address)
}

//0x81B6304102c2d6baBd599c2557d1A8b4Bdc9521B
async function deployFakeNFT() {
    const FakeToken = await ethers.getContractFactory("ERC721Mock");
    const ins = await FakeToken.deploy("Binance Regular NFT","BRNFT","https://public.nftstatic.com/static/nft/BSC/BRNFT/")
    console.log("DummyLOTNFT deployed to ",ins.address)
}

//0xbC18233857d906BCA391F3f642783745Da4dCF40
async function deployFakeNFT2() {
    const FakeToken = await ethers.getContractFactory("ERC721Mock");
    const ins = await FakeToken.deploy("The CR7 NFT Collection","CR7NFT","https://public.nftstatic.com/static/nft/BSC/CR7NFT/")
    console.log("DummyLOTNFT deployed to ",ins.address)
}


async function deployLotNFT() {
    const lotNFT = await ethers.getContractFactory("LeagueOfThronesNFTV1");
    const ins = await lotNFT.deploy()
    console.log("DummyLOTNFT deployed to ",ins.address)
}
//deployFakeToken()

//deployFakeNFT()
//Noneed to pre transfer reward
//deployLotContractToChain()
deployLotNFT()