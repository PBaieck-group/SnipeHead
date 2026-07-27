// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {SnipeHeadNFT} from "../src/SnipeHeadNFT.sol";

contract DeploySnipeHeadNFT is Script {
    function run() external returns (SnipeHeadNFT nft) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address royaltyReceiver = vm.envAddress("ROYALTY_RECEIVER");
        uint96 royaltyFeeBps = uint96(vm.envUint("ROYALTY_FEE_BPS"));

        vm.startBroadcast(deployerPrivateKey);
        nft = new SnipeHeadNFT(initialOwner, royaltyReceiver, royaltyFeeBps);
        vm.stopBroadcast();

        console.log("SnipeHeadNFT deployed at:", address(nft));
        console.log("Owner:", nft.owner());
        console.log("Royalty receiver:", royaltyReceiver);
        console.log("Royalty fee (bps):", royaltyFeeBps);
        console.log("Initial mintPrice (wei):", nft.mintPrice());
    }
}
