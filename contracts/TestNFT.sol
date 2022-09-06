pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract TestNFT is ERC721,ERC721Enumerable, ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;

    constructor() ERC721("The First NFT","FFT") {}
    event logTest(address _recipient, uint _mintTokenId);
    function mint(address _recipient, string memory _tokenUrl) public returns(uint _mintTokenId){
        require(bytes(_tokenUrl).length > 0,"The _tokenUrl must be have");
        _tokenId.increment();
        uint newTokenId = _tokenId.current();
        _mint(_recipient, newTokenId);
        _setTokenURI(newTokenId, _tokenUrl);
        emit logTest(_recipient, newTokenId);
        return newTokenId;
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
   super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}