// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract Deploy is Script {
    // Deployments
    Pogs public pogs;

    address signer = vm.envAddress("SIGNER_ADDRESS");
    address withdrawer = vm.envAddress("WITHDRAW_ADDRESS");
    address royalties = vm.envAddress("ROYALTY_ADDRESS");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MIANNET_DEPLOYER");

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        pogs = new Pogs(signer, withdrawer, royalties);

        vm.stopBroadcast();
    }
}
