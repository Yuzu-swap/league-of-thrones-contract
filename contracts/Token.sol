// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.6.12;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";



struct Record{
    uint256 amount;
    uint256 multi;
    bool isValid;
}


struct BeginRecord{
    bool isValid;
    bytes32 beginBytes;
    mapping(address => Record) balances;
    address [] userInfos;
}

// This is the main building block for smart contracts.
contract Token {



    // An address type variable is used to store ethereum accounts.
    address public owner;

    // A mapping is a key/value map. Here we store each account balance.
    mapping(uint256 => BeginRecord) beginRecords;
    

    /**
     * 合约构造函数
     *
     * The `constructor` is executed only once when the contract is created.
     * The `public` modifier makes a function callable from outside the contract.
     */
    constructor() public payable{
        owner = msg.sender;
    }

    /**
     * 代币转账.
     *
     * The `external` modifier makes a function *only* callable from outside
     * the contract.
     */

    function ownerAdd() external payable {
        require(msg.sender == owner);
    }

    function add(uint256 blockNum, uint256 multi) external payable {
        BeginRecord storage rb =  beginRecords[blockNum];
        require(rb.isValid == true, "have not begin");
        Record memory r = Record(msg.value, multi, true);
        rb.balances[msg.sender] = r;
        rb.userInfos.push(msg.sender);
    }

    function totalBalance() external view returns (uint256){
        return address(this).balance;
    }


    function begin(uint256 blockNum, bytes32 sign) external{
        require(msg.sender == owner);
        address[] memory userInfos = new address[](0);
        BeginRecord memory rb  = BeginRecord(true, sign, userInfos);
        beginRecords[blockNum] = rb;
       // beginBytes = sha256(abi.encodePacked(Strings.toString(multi)));
    }

    // function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
    //     uint8 i = 0;
    //     while(i < 32 && _bytes32[i] != 0) {
    //         i++;
    //     }
    //     bytes memory bytesArray = new bytes(i);
    //     for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
    //         bytesArray[i] = _bytes32[i];
    //     }
    //     return string(bytesArray);
    // }

    // function testSha(string memory password) external pure returns(bytes32){
    //     bytes32 gen = sha256(abi.encode(password));
    //     return gen;
    // }

    // function testStr(uint multi, string memory password) external pure returns(string memory){
    //     string memory gen = string(abi.encodePacked(Strings.toString(multi), password));
    //     return gen;
    // }

    function userEnd(uint256 blockNum) external {
        require(block.number >= blockNum);
        BeginRecord storage rb =  beginRecords[blockNum];
        require(rb.isValid == true, "have not begin");
        Record storage r = rb.balances[msg.sender];
        require(r.isValid == true, "have not begin");
        r.multi = (block.number - blockNum) * (r.multi - 100) / 100 + 100;
        console.log(block.number);
    }

    function end(uint256 blockNum, uint256 multi, string memory password) external {
        require(multi > 100);
        require(msg.sender == owner);
        BeginRecord storage rb =  beginRecords[blockNum];
        require(rb.isValid == true, "have not begin");
        bytes32 gen = sha256(abi.encode(string(abi.encodePacked(Strings.toString(multi), password))));
        require(gen == rb.beginBytes);
        address[] memory userInfos = rb.userInfos;
        for(uint i = 0; i < userInfos.length; i++){
            console.log(userInfos[i]);
            Record memory r = rb.balances[userInfos[i]];
            if(r.multi <= multi){
                uint re = r.amount * r.multi / 100;
                payable(userInfos[i]).transfer(re);
                console.log(re);
            }
        }
        delete beginRecords[blockNum];
    }

    // function userEnd(uint256 blockNum) external{
    //     Record memory r = balances[msg.sender];
    //     uint256 re = r.amount * r.multi / 100;
    //     payable(msg.sender).transfer(re);
    // }


    /**
     * 读取某账号的代币余额
     *
     * The `view` modifier indicates that it doesn't modify the contract's
     * state, which allows us to call it without executing a transaction.
     */
    function balanceOf(uint256 blockNum, address account) external view returns (uint256) {
        return beginRecords[blockNum].balances[account].amount;
    }
}

