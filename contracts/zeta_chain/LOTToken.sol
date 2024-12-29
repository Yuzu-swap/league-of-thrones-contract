// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract LeagueOfThronesToken is ERC20 ,Ownable{
    uint256 public constant supply = 10 ** 27;

    mapping(address => bool) private whitelist;
    bool public allowAllTransfers = false;

    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event AllowAllTransfersUpdated(bool isAllowed);

    constructor() ERC20("LeagueOfThronesToken", "LOT") {
        _mint(msg.sender, supply);
        whitelist[msg.sender] = true;
    }

    modifier onlyWhitelisted() {
        require(allowAllTransfers || whitelist[msg.sender], "Transfers are restricted to whitelisted addresses");
        _;
    }

    function setWhitelist(address account, bool isWhitelisted) external onlyOwner {
        whitelist[account] = isWhitelisted;
        emit WhitelistUpdated(account, isWhitelisted);
    }

    function setAllowAllTransfers(bool _allowAllTransfers) external onlyOwner {
        allowAllTransfers = _allowAllTransfers;
        emit AllowAllTransfersUpdated(_allowAllTransfers);
    }

    function transfer(address recipient, uint256 amount) public override onlyWhitelisted returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override onlyWhitelisted returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

}
