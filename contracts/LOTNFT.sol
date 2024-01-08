pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


// YuzuToken
contract LeagueOfThronesNFTV1 is ERC721("LeagueOfThronesNFTV1", "LOTNFT"), Ownable {
    using SafeMath for uint256;



    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return "https://suxqisugwmi6bcawj5hz2tqlespuarrvg6n6hi473bpdp6brkigq.arweave.net/lS8ESoazEeCIFk9PnU4LJJ9ARjU3m-Ojn9heN_gxUg0";
    }


    function batchMint(address _to, uint256 startTokenId, uint256 _amount) public onlyOwner returns (bool) {
        for(uint256 i = 0; i < _amount; i++) {
            _safeMint(_to, startTokenId.add(i));
        }
    }

}
