// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Pogs.sol";

interface HEVM {
    function warp(uint256 time) external;

    function roll(uint256) external;

    function prank(address) external;

    function prank(address, address) external;

    function startPrank(address) external;

    function startPrank(address, address) external;

    function stopPrank() external;

    function deal(address, uint256) external;

    function expectRevert(bytes calldata) external;

    function expectRevert() external;
}

contract PogsTest is Test {
    Pogs public pogs;

    // Cheatcodes
    HEVM public hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = address(1);
    address public user2 = address(0x1338);
    address public user3 = address(0x1339);
    address public payee1 = address(0x1340);
    address public payee2 = address(0x1341);

    address public withdrawAddress = address(0x1342);
    address public royaltyAddress = address(0x1343);
    address public signer;

    uint256 testMax =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint256 internal signerPrivateKey =
        0x14fc04d5e0773603731ffc332f3a784ad12f01b685ce8fee476406105c010596;

    // address user5 = 0x73eE6527DBb475A718718882Ad53fcd953CB7803;

    uint256 totalTickets;

    bytes testTicket;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        pogs = new Pogs(signer, withdrawAddress, royaltyAddress);
        console.log("signer", signer);

        //set active session
        pogs.setSession(1);

        //set mint price
        uint256 mintPrice = .01 ether;
        pogs.setMintPrice(mintPrice);

        //setWithdrawAddress
        pogs.setWithdrawAddress(withdrawAddress);
        uint256 bal = withdrawAddress.balance;
        console.log("starting_bal withdrawAddress", bal / 1e18);

        //deal some ether
        hevm.deal(user1, 1 ether);
        hevm.deal(user2, 1 ether);
        hevm.deal(user3, 1 ether);

        totalTickets = pogs.totalTickets();

        //team mint of 664
        pogs.mintForTeam(user1, 664);

        ///----------------------//
        //for testAllowlistMint()
        bytes32 tick = pogs.getTicket(userTest, 1, 1);
        bytes32 hash = hashGetTicket(tick);

        // // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(hash);
        testTicket = abi.encodePacked(r, s, v);
        ///----------------------//
    }

    address userTest = 0x1d07A15DafdD46247C4Aea1C77d1F2c08F4544A2;

    function testAllowlistMint() public {
        //deal some ether
        hevm.deal(userTest, 1 ether);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 1;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = testTicket;
        //mint from allowlist
        hevm.prank(userTest);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);
    }

    function testAddTickets() public {
        pogs.addTickets(1000);
    }

    function testInitialMap() public {
        assertEq(pogs.name(), "Pogs");
        assertEq(testMax, type(uint256).max);

        uint ticketMapBins = totalTickets / 256 + 1;

        for (uint i; i < ticketMapBins; i++) {
            assertEq(pogs.ticketMap(i), type(uint256).max);
        }

        assertEq(pogs.ticketMap(totalTickets / 256), type(uint256).max);
        assertEq(pogs.ticketMap(totalTickets / 256 + 1), 0);
    }

    function hashTicket(
        address user,
        uint256 ticketNumber,
        uint8 session
    ) private pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(user, ticketNumber, session))
            )
        );
    }

    function hashGetTicket(bytes32 _tick) private pure returns (bytes32 _hash) {
        _hash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _tick)
        );
    }

    function signTicket(
        bytes32 _hash
    ) private view returns (uint8 v, bytes32 r, bytes32 s) {
        (v, r, s) = vm.sign(signerPrivateKey, _hash);
    }

    function encodeParams(
        address user,
        uint256 ticketNumber,
        uint8 session
    ) private pure returns (bytes memory) {
        return abi.encodePacked(user, ticketNumber, session);
    }

    function hashWithParams(
        bytes memory _tick
    ) private pure returns (bytes32 _hash) {
        _hash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _tick)
        );
    }

    function testCLI() public {
        address user = 0x1d07A15DafdD46247C4Aea1C77d1F2c08F4544A2;
        uint256 ticketNumber = 1;
        uint8 session = 1;

        // bytes memory params = encodeParams(user, ticketNumber, session);
        // bytes32 __hash = hashWithParams(params);

        bytes32 tick = pogs.getTicket(user, ticketNumber, session);
        bytes32 hash = hashGetTicket(tick);

        // // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(hash);
        bytes memory signedTicket = abi.encodePacked(r, s, v);

        // recover signer
        address _signer = ecrecover(hash, v, r, s);
        assertEq(signer, _signer); // [PASS]

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signedTicket;

        //set active session to ALLOWLIST
        pogs.setSession(1);

        //deal some ether
        hevm.deal(user, 1 ether);
        //mint from allowlist
        hevm.prank(user);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);
    }

    function testAllowlist() public {
        // vm.assume(ticketNumber <= pogs.totalTickets());
        //signature that will be provided by back end for user 1
        uint256 ticketNumber = 2;
        address user = 0x1d07A15DafdD46247C4Aea1C77d1F2c08F4544A2;
        //deal some ether
        hevm.deal(user, 1 ether);

        // //hash ticket
        bytes32 hash = hashTicket(user, ticketNumber, uint8(1));
        // // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(hash);
        bytes memory signedTicket = abi.encodePacked(r, s, v);

        // recover signer
        address _signer = ecrecover(hash, v, r, s);
        assertEq(signer, _signer); // [PASS]

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signedTicket;

        //try to use before allowlist has started
        //set active session to NONE
        pogs.setSession(0);
        hevm.expectRevert();
        hevm.prank(user1);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to WAITLIST
        pogs.setSession(2);
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to ALLOWLIST
        pogs.setSession(1);

        //revert "not allowed" if wrong user tries to use it
        hevm.expectRevert();
        hevm.prank(user2, user2);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        hevm.prank(user, user);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //revert "already minted" if user tries to use it to mint again
        hevm.expectRevert();
        hevm.prank(user3, user3);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //check user 1 balance
        pogs.balanceOf(user1);
        pogs.tokensOfOwner(user1);

        // test withdraw function
        // try to withdraw from non authorized account
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.withdraw();

        // now from proper address
        uint256 bal = withdrawAddress.balance;
        console.log("bal withdrawAddress before = ", bal);
        uint256 ctxBal = pogs.getWithdrawBalance();
        console.log("bal contract Address before = ", ctxBal);
        hevm.prank(withdrawAddress);
        pogs.withdraw();
        assertTrue(withdrawAddress.balance > bal);
        bal = withdrawAddress.balance;
        console.log("bal withdrawAddress after = ", bal);
        assertEq(withdrawAddress.balance, pogs.mintPrice());
        ctxBal = pogs.getWithdrawBalance();
        console.log("bal contract Address after = ", ctxBal);

        // try to mint with three tickets
        tickets = new uint256[](3);
        tickets[0] = 1;
        tickets[1] = 2;
        tickets[2] = 3;
        sigs = new bytes[](3);
        sigs[0] = testTicket;
        for (uint i = 1; i < 3; i++) {
            bytes32 tick = pogs.getTicket(user2, i, 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.mintWithTicket{value: .03 ether}(tickets, sigs);

        // try to mint with mismatched arrays
        tickets = new uint256[](2);
        tickets[0] = 1;
        tickets[1] = 2;
        sigs = new bytes[](3);
        sigs[0] = testTicket;
        for (uint i = 1; i < 3; i++) {
            bytes32 tick = pogs.getTicket(user2, i, 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.mintWithTicket{value: .02 ether}(tickets, sigs);

        tickets = new uint256[](2);
        tickets[0] = 4;
        tickets[1] = 5;
        sigs = new bytes[](2);
        sigs[0] = testTicket;
        for (uint i; i < 2; i++) {
            bytes32 tick = pogs.getTicket(user2, tickets[i], 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        //try to mint without sending enough ether
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.mintWithTicket{value: 0}(tickets, sigs);

        //try to mint more than max supply
        pogs.mintForTeam(user3, 3778);
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.mintWithTicket{value: .02 ether}(tickets, sigs);
    }

    function testGetTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 1;

        bytes32 tick = pogs.getTicket(user3, ticketNumber, 1);

        bytes32 _tick = hashGetTicket(tick);

        // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(_tick);
        bytes memory signedTicket = abi.encodePacked(r, s, v);

        address _signer = ecrecover(
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)
            ),
            v,
            r,
            s
        );
        // bytes memory signedTicket = abi.encodePacked(r, s, v);
        assertEq(signer, _signer); // [PASS]

        //test verify sig
        assertEq(true, pogs.verifyTicket(user3, ticketNumber, 1, signedTicket));

        // test minting with ticket
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signedTicket;

        hevm.prank(user3, user3);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //test verify sig after mint
        assertEq(
            false,
            pogs.verifyTicket(user3, ticketNumber, 1, signedTicket)
        );
    }

    function testVerifyTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 1;
        uint8 session = 1;

        bytes32 tick = pogs.getTicket(user3, ticketNumber, session);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)
            )
        );
        address _signer = ecrecover(
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)
            ),
            v,
            r,
            s
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signer, _signer); // [PASS]

        //test verify sig
        assertEq(
            true,
            pogs.verifyTicket(user3, ticketNumber, session, signature)
        );

        //try with invalid ticketnumber
        assertTrue(!pogs.verifyTicket(user3, 15_000, session, signature));
    }

    function testPublicMint() public {
        uint256 amount = 1;
        uint256 mintPrice = pogs.mintPrice();

        //try to mint before setting active session
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pogs.mint{value: amount * mintPrice}(amount);

        //try to mint from contract
        pogs.setSession(3);
        hevm.expectRevert();
        //this is equivalent to sending from contract
        hevm.prank(user1);
        pogs.mint{value: amount * mintPrice}(amount);

        //set active session to public mint
        pogs.setSession(3);
        hevm.prank(user1, user1);
        pogs.mint{value: amount * mintPrice}(amount);

        //try to mint without sending enough value
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pogs.mint{value: 1 * mintPrice}(2);

        //try to mint more than max supply
        pogs.mintForTeam(user3, 3775);
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pogs.mint{value: 10 * mintPrice}(10);
    }

    function testMaxSupply() public {
        hevm.expectRevert();
        pogs.mintForTeam(user2, 4445);

        pogs.mintForTeam(user2, 4444 - 664);

        hevm.expectRevert();
        pogs.mintForTeam(user2, 1);
    }

    function testMintForTeam() public {
        uint16 amount = 664;
        uint256 currentSupply = pogs.totalSupply();
        pogs.mintForTeam(user2, amount);
        assertEq(pogs.balanceOf(user2), amount);

        // also check totalSupply()
        assertEq(pogs.totalSupply(), currentSupply + amount);

        //try to exceed maxsupply
        hevm.expectRevert();
        pogs.mintForTeam(user2, 5000);
    }

    function testSetMintPrice() public {
        assertEq(pogs.mintPrice(), .01 ether);
        pogs.setMintPrice(1 ether);
        assertEq(pogs.mintPrice(), 1 ether);
    }

    function testPogs() public {
        string memory name = pogs.name();
        console.log(name);

        // set base uri
        string
            memory baseUrl = "ipfs://bafybeibewadqajwgmka7357h7k7v2fw4jgekmv5di3vryr6lyfanzv3ioq/";
        pogs.setBaseURI(baseUrl);

        // hevm.prank(user1);
        pogs.mintForTeam(user1, 1);
        string memory retrievedURI = pogs.tokenURI(1);
        console.log(retrievedURI);

        //retrieve uri for token that does not exist
        hevm.expectRevert();
        pogs.tokenURI(7000);
    }

    function testUnrevealed() public {
        // set unrevealed uri
        string memory setUnrevealedUrl = "https://unrevealed.com";
        pogs.setUnrevealedURI(setUnrevealedUrl);

        // set base uri
        string
            memory baseUrl = "ipfs://bafybeibewadqajwgmka7357h7k7v2fw4jgekmv5di3vryr6lyfanzv3ioq/";
        pogs.setBaseURI(baseUrl);

        //get uri before revealed
        string memory retrievedURI = pogs.tokenURI(1);
        console.log("retrieved url for token 1 before reveal", retrievedURI);

        bool isRevealed = pogs.isRevealed();
        assertEq(isRevealed, false);
        pogs.setIsRevealed(true);
        isRevealed = pogs.isRevealed();
        assertEq(isRevealed, true);

        // hevm.prank(user1);
        pogs.mintForTeam(user1, 1);
        retrievedURI = pogs.tokenURI(1);
        console.log(retrievedURI);

        //retrieve uri for token that does not exist
        hevm.expectRevert();
        pogs.tokenURI(7000);
    }

    function testRoyalties() public {
        //try to set with zero address
        hevm.expectRevert();
        pogs.setRoyaltyAddress(address(0x00));

        (address receiver, ) = pogs.royaltyInfo(1, 1 ether);
        assertEq(receiver, pogs.royaltyAddress());
        pogs.setRoyaltyPermille(100);

        pogs.setRoyaltyAddress(address(0x5555));
        assertEq(address(0x5555), pogs.royaltyAddress());
    }

    function testSetWithdrawAddress() public {
        //try to set with zero address
        hevm.expectRevert();
        pogs.setWithdrawAddress(address(0x00));

        pogs.setWithdrawAddress(address(0x5555));
        assertEq(address(0x5555), pogs.withdrawAddress());
    }

    function testAllowListSigner() public {
        //try to set with address zero
        hevm.expectRevert();
        pogs.setAllowListSigner(address(0x00));
        // assertEq(address(0x5555), pogs.allowListSigner());

        pogs.setAllowListSigner(address(0x5555));
        assertEq(address(0x5555), pogs.allowListSigner());
    }

    function testAdmins() public {
        // try to burn without setting admin address
        assertEq(pogs.isAdmin(address(this)), false);
        hevm.expectRevert();
        pogs.burn(1);

        //try to set with zero address
        hevm.expectRevert();
        pogs.addAdmin(address(0x00));

        pogs.addAdmin(address(0x5555));
        assertEq(pogs.isAdmin(address(0x5555)), true);

        hevm.prank(address(0x5555));
        pogs.burn(1);

        // remove admin
        pogs.removeAdmin(address(0x5555));
        assertEq(pogs.isAdmin(address(0x5555)), false);

        // try to burn without after removing admin address
        hevm.expectRevert();
        pogs.burn(1);
    }

    function testInterface() public {
        assertTrue(pogs.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(pogs.supportsInterface(0x01ffc9a7));
        assertTrue(pogs.supportsInterface(0x80ac58cd));
        assertTrue(pogs.supportsInterface(0x5b5e139f));
    }

    // function testPaymentSplitter() public {
    //     // get payees
    //     address[] memory payees = new address[](2);
    //     payees[0] = payee1;
    //     payees[1] = payee2;
    //     //get shares
    //     uint256 shares1 = 40;
    //     uint256 shares2 = 60;
    //     uint256[] memory shares = new uint256[](2);
    //     shares[0] = shares1;
    //     shares[1] = shares2;

    //     signer = vm.addr(signerPrivateKey);
    //     Pogs pogs1 = new Pogs(signer, withdrawAddress, payees, shares);

    //     assertEq(payee1, pogs1.payee(0));
    //     assertEq(payee2, pogs1.payee(1));

    //     uint256 totalShares = pogs1.totalShares();
    //     assertEq(totalShares, shares1 + shares2);
    //     console.log("totalShares", totalShares);

    //     uint256 totalReleased = pogs1.totalReleased();
    //     console.log("totalReleased", totalReleased);

    //     uint256 sharesPayee1 = pogs1.shares(payee1);
    //     assertEq(sharesPayee1, shares1);
    //     console.log("sharesPayee1", sharesPayee1);

    //     uint256 sharesPayee2 = pogs1.shares(payee2);
    //     assertEq(sharesPayee2, shares2);
    //     console.log("sharesPayee2", sharesPayee2);

    //     uint256 releaseAmountPayee1 = pogs1.releasable(payee1);
    //     assertEq(releaseAmountPayee1, 0);
    //     console.log("releaseAmountPayee1", releaseAmountPayee1);

    //     uint256 releaseAmountPayee2 = pogs1.releasable(payee2);
    //     assertEq(releaseAmountPayee2, 0);
    //     console.log("releaseAmountPayee2", releaseAmountPayee2);

    //     //set public sale
    //     pogs1.setSession(3);
    //     uint256 mintPrice = pogs1.mintPrice();
    //     uint256 amount = 5;

    //     hevm.prank(user1, user1);
    //     pogs1.mint{value: amount * mintPrice}(amount);

    //     uint256 expectedSplit1 = (amount * mintPrice * shares1) /
    //         (shares1 + shares2);
    //     uint256 expectedSplit2 = (amount * mintPrice * shares2) /
    //         (shares1 + shares2);

    //     releaseAmountPayee1 = pogs1.releasable(payee1);
    //     assertEq(releaseAmountPayee1, expectedSplit1);
    //     console.log("releaseAmountPayee1 after mint", releaseAmountPayee1);

    //     releaseAmountPayee2 = pogs1.releasable(payee2);
    //     assertEq(releaseAmountPayee2, expectedSplit2);
    //     console.log("releaseAmountPayee2 after mint", releaseAmountPayee2);
    // }
}
