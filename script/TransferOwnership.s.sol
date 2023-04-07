// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract TransferOwnership is Script {
    // Deployments
    Pogs public pogs;

    address _pogsAddy = vm.envAddress("POGS_CONTRACT_ADDRESS");
    address payable pogsAddy = payable(_pogsAddy);

    address newOwner = vm.envAddress("TRANSFER_OWNERSHIP_ADDRESS");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MAINNET_DEPLOYER");

        pogs = Pogs(pogsAddy);

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        // set revealed uri
        pogs.transferOwnership(newOwner);

        vm.stopBroadcast();
    }
}
