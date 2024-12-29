// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}

contract ERC721Mock is ERC721Enumerable {
    string private _baseTokenURI;
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public ERC721(name, symbol) {
         _baseTokenURI = baseTokenURI;
    }

    function mint(address to,uint256 nftId) public {
        _mint(to, nftId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory tokenIdStr = Strings.toString(tokenId);

        return string(abi.encodePacked(_baseTokenURI, tokenIdStr));
    }
}


