// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SnipeheadMiningDecentralizedV2.sol";

contract SnipeheadMiningDecentralizedV2Script is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the mining contract
        SnipeheadMiningDecentralizedV2 mining = new SnipeheadMiningDecentralizedV2();

        vm.stopBroadcast();

        // Log the deployed address (helpful for verification)
        console.log("SnipeheadMiningDecentralizedV2 deployed at:", address(mining));
    }
}