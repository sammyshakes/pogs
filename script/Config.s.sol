// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Pogs.sol";

contract Config is Script {
    // Deployments
    Pogs public pogs;

    address _pogsAddy = vm.envAddress("POGS_CONTRACT_ADDRESS");
    address payable pogsAddy = payable(_pogsAddy);

    address mintForTeamAddress = vm.envAddress("MINT_FOR_TEAM_ADDRESS");
    uint16 mintForTeamAmount = 644;

    string unrevealedUri = vm.envString("UNREVEALED_URI");

    function run() external {
        // Testent
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        pogs = Pogs(pogsAddy);

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        // set uris
        pogs.setUnrevealedURI(unrevealedUri);
        pogs.mintForTeam(mintForTeamAddress, mintForTeamAmount);

        // set session to Allowlist
        pogs.setSession(1);

        vm.stopBroadcast();
    }
}
