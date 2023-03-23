// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract Deploy is Script {
    // Deployments
    Pogs public pogs;

    address signer = 0x42C7eF198f8aC9888E2B1b73e5B71f1D4535194A;

    uint256 internal signerPrivateKey =
        0x14fc04d5e0773603731ffc332f3a784ad12f01b685ce8fee476406105c010596;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        pogs = new Pogs(signer, signer, signer);

        vm.stopBroadcast();
        // pogs.mintForTeam(signer, 644);
    }
}
