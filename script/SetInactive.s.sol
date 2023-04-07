// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract SetInactive is Script {
    // Deployments
    Pogs public pogs;

    address _pogsAddy = vm.envAddress("POGS_CONTRACT_ADDRESS");
    address payable pogsAddy = payable(_pogsAddy);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        pogs = Pogs(pogsAddy);

        vm.startBroadcast(deployerPrivateKey);

        // set session inactive
        pogs.setSession(0);

        vm.stopBroadcast();
    }
}
