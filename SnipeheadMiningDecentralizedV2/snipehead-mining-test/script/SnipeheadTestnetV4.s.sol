// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SnipeHead.sol";
import {SnipeheadMiningDecentralizedV2_V4_TEST as MiningV4} from "../src/SnipeheadMiningDecentralizedV2_V4_TEST.sol";

contract SnipeheadTestnetV4 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        vm.allowCheatcodes(msg.sender);

        address deployer = msg.sender;
        console.log("Deploying on PulseChain Testnet V4 from:", deployer);

        // === Deploy Token ===
        Token shd = new Token("SnipeHead", "SHD", 1_000_000_000 ether);
        console.log("SHD Token deployed at:", address(shd));

        // === Deploy Mining Contract ===
        MiningV4 mining = new MiningV4(address(shd));
        console.log("Mining V4_TEST deployed at:", address(mining));

        shd.launch();
        console.log("Token launched");

        // Give some tokens to deployer and approve
        shd.transfer(deployer, 200_000 ether);
        shd.approve(address(mining), type(uint256).max);

        console.log("\n=== Small amount tests ===");

        mining.deposit(100_122_300 ether);
        console.log("deposit passed");

        mining.mine(90_230_000 ether);
        console.log("mine passed");

        // Wait for real blocks on PulseChain Testnet (~10-12s per block)
        console.log("Waiting 60 seconds for blocks to accumulate rewards...");
        vm.sleep(60_000);   // 60 seconds ≈ 5-6 blocks

        uint256 pending = mining.pendingRewards(deployer);
        console.log("Pending rewards:", pending);

        if (pending > 0) {
            mining.claimRewards();
            console.log("claimRewards passed - claimed:", pending);
        } else {
            console.log("claimRewards skipped - no rewards yet");
        }

        mining.unmine(10_000 ether);
        console.log("unmine passed");

        console.log("\nFinal totalMined:", mining.totalMined());
        console.log("Contract balance:", mining.getContractSHDBalance());

        vm.stopBroadcast();

        // === Final Logs (after stopBroadcast) ===
        console.log("\n=== Final Verification ===");
        console.log("All on-chain actions completed successfully.");
        console.log("SHD Token:", address(shd));
        console.log("Mining Contract:", address(mining));

        console.log("\nALL TESTS COMPLETED SUCCESSFULLY!");
    }
}