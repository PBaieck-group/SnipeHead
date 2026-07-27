// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SnipeHeadNFT} from "../src/SnipeHeadNFT.sol";

/**
 * Reliable smoke-test script for PulseChain Testnet v4.
 * Only performs successful actions (no expected reverts).
 *
 * Usage:
 *   forge script script/SmokeTestSnipeHeadNFT.s.sol:SmokeTestSnipeHeadNFT \
 *     --rpc-url https://pulsechain-testnet.publicnode.com \
 *     --broadcast \
 *     -vvvv
 */
contract SmokeTestSnipeHeadNFT is Script {
    uint256 constant TEST_PRICE  = 1_000_000_000_000; // 0.000001 tPLS
    uint256 constant FUND_AMOUNT = 0.01 ether;

    function run() external {
        uint256 pk1 = vm.envUint("PRIVATE_KEY");
        uint256 pk2 = vm.envUint("SECOND_PRIVATE_KEY");
        address nftAddr = vm.envAddress("NFT_ADDRESS");

        SnipeHeadNFT nft = SnipeHeadNFT(nftAddr);
        address me    = vm.addr(pk1);
        address other = vm.addr(pk2);

        console2.log("Main tester  :", me);
        console2.log("Second wallet:", other);
        console2.log("NFT          :", address(nft));

        // 1. Fund second wallet
        console2.log("\n=== FUNDING SECOND WALLET ===");
        vm.startBroadcast(pk1);
        (bool ok,) = other.call{value: FUND_AMOUNT}("");
        require(ok, "funding failed");
        console2.log("Sent", FUND_AMOUNT, "tPLS to second wallet");
        vm.stopBroadcast();

        // 2. Ensure price + minting are ready
        console2.log("\n=== PREPARE ===");
        vm.startBroadcast(pk1);
        if (nft.mintPrice() != TEST_PRICE) {
            nft.setMintPrice(TEST_PRICE);
            console2.log("Set test price");
        }
        if (!nft.mintingActive()) {
            nft.setMintingActive(true);
            console2.log("Activated minting");
        }
        vm.stopBroadcast();

        // 3. Mint from the second wallet
        console2.log("\n=== MINT FROM SECOND WALLET ===");
        uint256 supplyBefore = nft.totalSupply();

        vm.startBroadcast(pk2);
        nft.mint{value: TEST_PRICE}(1);
        vm.stopBroadcast();

        uint256 newId = supplyBefore + 1;
        require(nft.totalSupply() == newId, "supply did not increase");
        require(nft.ownerOf(newId) == other, "wrong owner");

        console2.log("Minted token", newId);
        console2.log("Owner       :", nft.ownerOf(newId));
        console2.log("tokenURI    :", nft.tokenURI(newId));

        // 4. Withdraw any funds sitting in the contract
        console2.log("\n=== WITHDRAW ===");
        uint256 bal = address(nft).balance;
        console2.log("Contract balance before:", bal);

        if (bal > 0) {
            vm.startBroadcast(pk1);
            nft.withdraw();
            vm.stopBroadcast();
            require(address(nft).balance == 0, "withdraw failed");
            console2.log("Withdrawn successfully");
        } else {
            console2.log("Nothing to withdraw");
        }

        // Final state
        console2.log("\n=== FINAL STATE ===");
        console2.log("totalSupply     :", nft.totalSupply());
        console2.log("contract balance:", address(nft).balance);
        console2.log("\nScript finished successfully");
    }
}