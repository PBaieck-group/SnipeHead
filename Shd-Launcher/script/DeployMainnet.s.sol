// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";

contract DeployMainnet is Script {
    uint256 internal constant MAINNET_CHAIN_ID = 369;

    address internal constant EXPECTED_SHD =
        0xB95bC84f9B6D0373642D586b81979B067572f7bc;

    address internal constant EXPECTED_BUY_AND_BURN =
        0x3677e61A7a9E79Fe45a882C201365C5165A5540e;

    address internal constant EXPECTED_PULSEX_FACTORY =
        0x29eA7545DEf87022BAdc76323F373EA1e707C523;

    function run() external {
        require(
            block.chainid == MAINNET_CHAIN_ID,
            "Wrong network: PulseChain mainnet required"
        );

        // Check that production dependencies exist.
        require(EXPECTED_SHD.code.length > 0, "SHD has no code");
        require(
            EXPECTED_BUY_AND_BURN.code.length > 0,
            "BuyAndBurn has no code"
        );
        require(
            EXPECTED_PULSEX_FACTORY.code.length > 0,
            "PulseX factory has no code"
        );

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer PLS balance:", deployer.balance);

        require(deployer.balance > 0, "No PLS for deployment");

        // Production contract only. No mock or testnet contracts.
        vm.startBroadcast(pk);
        SHDLaunchFactory factory = new SHDLaunchFactory();
        vm.stopBroadcast();

        // Verify the deployed contract configuration.
        require(
            address(factory.SHD()) == EXPECTED_SHD,
            "Unexpected SHD"
        );
        require(
            factory.BUY_AND_BURN() == EXPECTED_BUY_AND_BURN,
            "Unexpected BuyAndBurn"
        );
        require(
            address(factory.FACTORY()) == EXPECTED_PULSEX_FACTORY,
            "Unexpected PulseX factory"
        );

        console2.log("===== MAINNET DEPLOYMENT =====");
        console2.log("SHDLaunchFactory:", address(factory));
        console2.log("SHD:", address(factory.SHD()));
        console2.log("BuyAndBurn:", factory.BUY_AND_BURN());
        console2.log("PulseX factory:", address(factory.FACTORY()));
        console2.log("Explorer:");
        console2.log(
            string.concat(
                "https://ipfs.scan.pulsechain.com/address/",
                vm.toString(address(factory))
            )
        );
    }
}

 