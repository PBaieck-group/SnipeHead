// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {SnipeHeadNFT} from "../src/SnipeHeadNFT.sol";

/**
 * Mainnet deployment for SnipeHeadNFT on PulseChain.
 *
 * Steps performed:
 * 1. Deploy the contract
 * 2. setMintingActive(true)
 * 3. transferOwnership to the final owner
 *
 * Required .env variables:
 *   PRIVATE_KEY=0x...          (deployer key – must have enough PLS for gas)
 *   INITIAL_OWNER=0x...        (temporary owner = the deployer address)
 *   ROYALTY_RECEIVER=0x...     (usually same as final owner or a treasury)
 *   ROYALTY_FEE_BPS=100        (or whatever you want, e.g. 100 = 1%)
 *
 * Run:
 *   forge script script/DeployMainnetSnipeHeadNFT.s.sol:DeployMainnetSnipeHeadNFT \
 *     --rpc-url https://rpc.pulsechain.com \
 *     --broadcast \
 *     -vvvv
 */
contract DeployMainnetSnipeHeadNFT is Script {
    // Final owner after deployment
    address constant FINAL_OWNER = 0x53c06B1748885c34AA224AB395d9846E675a3bE1;

    function run() external returns (SnipeHeadNFT nft) {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address royaltyReceiver = vm.envAddress("ROYALTY_RECEIVER");
        uint96 royaltyFeeBps = uint96(vm.envUint("ROYALTY_FEE_BPS"));

        // Safety checks
        require(initialOwner != address(0), "INITIAL_OWNER not set");
        require(royaltyReceiver != address(0), "ROYALTY_RECEIVER not set");
        require(FINAL_OWNER != address(0), "FINAL_OWNER is zero");

        console2.log("Deployer / temporary owner :", vm.addr(deployerPk));
        console2.log("INITIAL_OWNER              :", initialOwner);
        console2.log("ROYALTY_RECEIVER           :", royaltyReceiver);
        console2.log("ROYALTY_FEE_BPS            :", royaltyFeeBps);
        console2.log("FINAL_OWNER                :", FINAL_OWNER);

        vm.startBroadcast(deployerPk);

        // 1. Deploy
        nft = new SnipeHeadNFT(initialOwner, royaltyReceiver, royaltyFeeBps);
        console2.log("\nContract deployed at:", address(nft));

        // 2. Turn public minting ON
        nft.setMintingActive(true);
        console2.log("mintingActive set to true");

        // 3. Transfer ownership to the final owner
        nft.transferOwnership(FINAL_OWNER);
        console2.log("Ownership transferred to:", FINAL_OWNER);

        vm.stopBroadcast();

        // Final summary
        console2.log("\n=== DEPLOYMENT COMPLETE ===");
        console2.log("Contract address :", address(nft));
        console2.log("Current owner    :", nft.owner());
        console2.log("mintingActive    :", nft.mintingActive());
        console2.log("mintPrice (wei)  :", nft.mintPrice());
        console2.log("MAX_SUPPLY       :", nft.MAX_SUPPLY());
        console2.log("MAX_PER_WALLET   :", nft.MAX_PER_WALLET());
    }
}
