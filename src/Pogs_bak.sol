// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/erc721a/contracts/extensions/ERC721AQueryable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract Pogs is ERC721AQueryable, Ownable, ERC2981 {
    using ECDSA for bytes32;

    enum ActiveSession {
        INACTIVE,
        ALLOWLIST,
        WAITLIST,
        PUBLIC
    }

    // CONSTANTS
    uint256 constant MAX_SUPPLY = 4_444;
    uint256 constant TICKETS_PER_BIN = 256;
    uint256 constant TICKET_BINS = 50; // Starting Amount of Bins: STARTING_TICKETS / 256 + 1
    uint256 constant STARTING_TICKETS = 12_800; // TICKET_BINS * TICKETS_PER_BIN

    // PRIVATE VARS
    string private baseURI;
    string private unrevealedURI;
    uint256 private _royaltyPermille = 40; // supports 1 decimal place ex. 40 = 4.0%

    // PUBLIC VARS
    bool public isRevealed = false;
    address public allowListSigner;
    address public withdrawAddress;
    address public royaltyAddress;
    uint256 public mintPrice = 0.01 ether;
    uint256 public totalTickets;
    mapping(uint256 => uint256) public ticketMap;
    ActiveSession public activeSession = ActiveSession.INACTIVE;

    constructor(
        address _signer,
        address _withdrawer,
        address _royalties
    ) ERC721A("Pogs", "POG") {
        require(_signer != address(0x00), "Cannot be zero address");
        require(_withdrawer != address(0x00), "Cannot be zero address");
        require(_royalties != address(0x00), "Cannot be zero address");
        allowListSigner = _signer;
        withdrawAddress = _withdrawer;
        royaltyAddress = _royalties;
        //initialize tickets
        _addTickets(STARTING_TICKETS);
    }

    function mint(uint256 amount) external payable {
        require(msg.sender == tx.origin, "EOA Only");
        require(activeSession == ActiveSession.PUBLIC, "Minting Not Active");
        require(msg.value >= mintPrice * amount, "Did not send enough ether");
        require(totalSupply() + amount <= MAX_SUPPLY, "Max amount reached");

        //mint
        _mint(_msgSender(), amount);
    }

    function mintWithTicket(
        uint256[] calldata ticketNumbers,
        bytes[] calldata signatures
    ) external payable {
        require(ticketNumbers.length == signatures.length, "Mismatch Arrays");
        require(
            totalSupply() + ticketNumbers.length <= MAX_SUPPLY,
            "Max amount reached"
        );
        require(ticketNumbers.length < 3, "Max 2 Tickets");
        require(
            msg.value >= mintPrice * ticketNumbers.length,
            "Did not send enough ether"
        );

        for (uint256 i; i < ticketNumbers.length; i++) {
            require(
                verifyTicket(
                    _msgSender(), // ensures only verified user can mint
                    ticketNumbers[i], // ensures a ticket cant be used twice
                    uint8(activeSession), // ensures ticket can only be used for current session
                    signatures[i]
                ),
                "Can not verify ticket"
            );
            _claimTicket(ticketNumbers[i]); // account for used ticket
        }

        //mint
        _mint(_msgSender(), ticketNumbers.length);
    }

    function verifyTicket(
        address user,
        uint256 ticketNumber,
        uint8 session,
        bytes memory signature
    ) public view returns (bool isValid) {
        if (
            allowListSigner ==
            getTicket(user, ticketNumber, session)
                .toEthSignedMessageHash()
                .recover(signature)
        ) isValid = true;
    }

    function _claimTicket(uint256 ticketNumber) private {
        require(ticketNumber <= totalTickets, "Invalid Ticket Number");
        //get ticket bin and ticket bit
        uint256 ticketBin;
        uint256 ticket;
        unchecked {
            ticketBin = ticketNumber / TICKETS_PER_BIN;
            ticket = ticketNumber % TICKETS_PER_BIN;
        }

        uint256 ticketBit = (ticketMap[ticketBin] >> ticket) & uint256(1);
        require(ticketBit == 1, "ticket already claimed");

        ticketMap[ticketBin] = ticketMap[ticketBin] & ~(uint256(1) << ticket);
    }

    // This can be used to create the unsigned tickets
    function getTicket(
        address user,
        uint256 ticketNumber,
        uint8 session
    ) public pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(user, ticketNumber, session));
        return hash;
    }

    function addTickets(uint256 amount) external onlyOwner {
        _addTickets(amount);
    }

    function _addTickets(uint256 amount) private {
        //store how many current bins exist
        uint256 currentBins;
        if (totalTickets > 0) currentBins = totalTickets / 256 + 1;

        //calc new amount of bins needed with new tickets added
        totalTickets += amount;
        uint256 requiredBins = totalTickets / 256 + 1;

        //check if we need to add bins
        if (requiredBins > currentBins) {
            uint256 binsToAdd = requiredBins - currentBins;
            for (uint256 i; i < binsToAdd; i++) {
                ticketMap[currentBins + i] = type(uint256).max;
            }
        }
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
        if (!isRevealed) return unrevealedURI;
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view override returns (address receiver, uint256 royaltyAmount) {
        return (royaltyAddress, (salePrice * _royaltyPermille) / 1000);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721A, IERC721A, ERC2981) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // OWNER ONLY //
    function setRoyaltyPermille(uint256 number) external onlyOwner {
        _royaltyPermille = number;
    }

    function setRoyaltyAddress(address addr) external onlyOwner {
        royaltyAddress = addr;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        unrevealedURI = uri;
    }

    function setIsRevealed(bool _isRevealed) external onlyOwner {
        isRevealed = _isRevealed;
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function mintForTeam(address receiver, uint16 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max amount reached");
        _safeMint(receiver, amount);
    }

    function setAllowListSigner(address _signer) external onlyOwner {
        require(_signer != address(0x00), "Cannot be zero address");
        allowListSigner = _signer;
    }

    // session input should be:
    // 0 = Inactive, 1 = AllowList, 2 = Waitlist, 3 = Public Sale
    function setSession(uint8 session) external onlyOwner {
        activeSession = ActiveSession(session);
    }

    function withdraw() external {
        require(withdrawAddress != address(0x00), "Withdraw address not set");
        require(_msgSender() == withdrawAddress, "Withdraw address only");
        uint256 totalAmount = address(this).balance;
        bool sent;

        (sent, ) = withdrawAddress.call{value: totalAmount}("");
        require(sent, "Main: Failed to send funds");
    }

    function setWithdrawAddress(address addr) external onlyOwner {
        require(addr != address(0x00), "Cannot be zero address");
        withdrawAddress = addr;
    }

    function getWithdrawBalance() external view returns (uint256) {
        // To access the amount of ether the contract has
        return address(this).balance;
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

    receive() external payable {}

    fallback() external payable {}
}