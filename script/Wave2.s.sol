// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract Wave2 is Script {
    // Deployments
    Pogs public pogs;

    address _pogsAddy = vm.envAddress("POGS_CONTRACT_ADDRESS");
    address payable pogsAddy = payable(_pogsAddy);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        pogs = Pogs(pogsAddy);

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        // set session to Waitlist
        pogs.setSession(2);

        vm.stopBroadcast();
    }
}
