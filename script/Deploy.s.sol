// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract Deploy is Script {
    // Deployments
    Pogs public pogs;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        pogs = new Pogs();

        vm.stopBroadcast();
    }
}
