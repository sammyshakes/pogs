// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/security";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/erc721a/contracts/extensions/ERC721AQueryable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract Pogs is ERC721AQueryable, Ownable, Pausable, ReentrancyGuard {
    // ERRORS
    error MaxAllowedPublicSaleMints();
    
    // PUBLIC VARS
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxSupply = 3000;
    uint16 public maxMints = 9;   
    string private baseURI;

    // PRIVATE VARS
    mapping(address => uint8) private _mints;

    constructor() {}

    function mint(uint256 amount) external payable {
        if(_mints[_msgSender()] + amount > maxMints) revert MaxAllowedPublicSaleMints();

        require(msg.value >= mintPrice * amount, "Did not send enough ether");
        require(totalSupply() + amount <= maxSupply, "Max amount reached");

        //mint
        _safeMint(_msgSender(), amount);
    }

    function tokensOfOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        return _tokensOfOwner(_owner);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721A, IERC721A) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721A, IERC721A) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // OWNER ONLY //
    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function mintForTeam(address receiver, uint16 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max amount reached");
        _safeMint(receiver, amount);
    }

    function withdraw() external {
        require(_msgSender() == owner(), "Owner only");
        uint256 totalAmount = address(this).balance;
        bool sent;

        (sent, ) = owner().call{value: totalAmount}("");
        require(sent, "Main: Failed to send funds");
    }

     function getMintCount(address user) external view returns (uint256) {
        return _mints[user];
    }

    //  ADMIN ONLY //
    mapping(address => bool) private _admins;
    modifier onlyAdmin() {
        require(!_admins[msg.sender], "Only Admins");
        _;
    }

    function burn(uint256 tokenId) external onlyAdmin {
        _burn(tokenId);
    }

    function mintFromAdmin(address receiver, uint16 amount) external onlyAdmin {
        require(totalSupply() + amount <= maxSupply, "Max amount reached");
        _safeMint(receiver, amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
