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

    address public withdrawAddress = address(0x1340);
    address public signer;

    uint256 testMax =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint256 internal signerPrivateKey =
        0x14fc04d5e0773603731ffc332f3a784ad12f01b685ce8fee476406105c010596;

    // address user5 = 0x73eE6527DBb475A718718882Ad53fcd953CB7803;

    uint256 totalTickets;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        pogs = new Pogs(signer, withdrawAddress);
        console.log("signer", signer);

        //set active session
        pogs.setSession(1);

        //setWithdrawAddress
        pogs.setWithdrawAddress(withdrawAddress);
        uint256 bal = withdrawAddress.balance;
        console.log("starting_bal withdrawAddress", bal / 1e18);

        //deal some ether
        hevm.deal(user1, 1 ether);
        hevm.deal(user2, 1 ether);
        hevm.deal(user3, 1 ether);

        //unpause contract
        pogs.setPaused(false);

        totalTickets = pogs.maxSupply();
    }

    function testPublicMint() public {
        //set active session to public mint
        uint256 amount = 5;
        uint256 mintPrice = pogs.mintPrice();
        pogs.setSession(3);
        hevm.prank(user1, user1);
        pogs.mint{value: amount * mintPrice}(1);
    }

    function testInitialMap() public {
        assertEq(pogs.name(), "Pogs");
        assertEq(testMax, type(uint256).max);

        assertEq(pogs.ticketMap(0), type(uint256).max);
        assertEq(pogs.ticketMap(1), type(uint256).max);
        assertEq(pogs.ticketMap(2), type(uint256).max);
        assertEq(pogs.ticketMap(3), type(uint256).max);
        assertEq(pogs.ticketMap(4), type(uint256).max);
        assertEq(pogs.ticketMap(totalTickets / 256), type(uint256).max);
        assertEq(pogs.ticketMap(totalTickets / 256 + 1), 0);
    }

    function testAddTickets() public {
        uint256 tickets = pogs.maxSupply();

        assertEq(pogs.ticketMap(0), type(uint256).max);
        assertEq(pogs.ticketMap(1), type(uint256).max);
        assertEq(pogs.ticketMap(2), type(uint256).max);
        assertEq(pogs.ticketMap(tickets / 256), type(uint256).max);
        assertEq(pogs.ticketMap(tickets / 256 + 1), 0);
    }

    function testHashing() public {
        //signature that will be provided by back end for user 1
        uint256 ticketNumber = 85;
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(user3, ticketNumber, uint8(1)))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        address _signer = ecrecover(hash, v, r, s);
        assertEq(signer, _signer); // [PASS]
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signature;

        //try to use before allowlist has started
        //set active session to NONE
        pogs.setSession(0);
        hevm.expectRevert();
        hevm.prank(user1);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to WAITLIST
        pogs.setSession(2);
        hevm.expectRevert();
        hevm.prank(user1);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to ALLOWLIST
        pogs.setSession(1);

        //revert "not allowed" if wrong user tries to use it
        hevm.expectRevert();
        hevm.prank(user2);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        hevm.prank(user3);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);

        //revert "already minted" if user tries to use it to mint again
        hevm.expectRevert();
        hevm.prank(user1);
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
        hevm.prank(withdrawAddress);
        pogs.withdraw();
        uint256 bal = withdrawAddress.balance;
        console.log("bal withdrawAddress", bal);
        assertEq(withdrawAddress.balance, pogs.mintPrice());
    }

    function testGetTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 0;

        bytes32 tick = pogs.getTicket(user3, ticketNumber, 1);
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
        assertEq(true, pogs.verifyTicket(user3, ticketNumber, 1, signature));

        // test minting with ticket
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signature;

        hevm.prank(user3);
        pogs.mintWithTicket{value: .01 ether}(tickets, sigs);
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
    }

    function testMaxSupply() public {
        hevm.expectRevert();
        pogs.mintForTeam(user2, 4445);

        pogs.mintForTeam(user2, 4444);

        hevm.expectRevert();
        pogs.mintForTeam(user2, 1);
    }

    function testMintForTeam() public {
        pogs.mintForTeam(user2, 5);
        assertEq(pogs.balanceOf(user2), 5);

        // also check totalSupply()
        assertEq(pogs.totalSupply(), 5);
    }

    function testSetMintPrice() public {
        assertEq(pogs.mintPrice(), .01 ether);
        pogs.setMintPrice(1 ether);
        assertEq(pogs.mintPrice(), 1 ether);
    }

    // function testPogs() public {
    //     string memory name = pogs.name();
    //     console.log(name);

    //     string
    //         memory baseUrl = "ipfs://bafybeibewadqajwgmka7357h7k7v2fw4jgekmv5di3vryr6lyfanzv3ioq/";
    //     pogs.setBaseURI(baseUrl);

    //     hevm.prank(user1);
    //     pogs.mint{value: 0.04 ether}(4);

    //     string memory retrievedURI = pogs.tokenURI(1);
    //     console.log(retrievedURI);
    // }
}
