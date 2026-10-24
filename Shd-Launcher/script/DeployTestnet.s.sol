// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Token as SnipeHeadToken} from "../src/SnipeHead.sol";
import {SHDLaunchFactoryTestnet} from "../src/testnet/SHDLaunchFactoryTestnet.sol";
import {MockV2Factory} from "../test/mocks/MockPulseX.sol";

/// @notice Deploys the full stack to PulseChain V4 testnet (chain id 943):
///           1. test SHD   - the REAL SnipeHead `Token` source, launched, then ownership renounced
///                           (mirrors mainnet SHD: unlocked, no owner, no fee on transfer)
///           2. V2 factory - MockV2Factory (2-arg PulseX-style mint) unless V2_FACTORY is set
///           3. BuyAndBurn - a dummy sink address unless BUY_AND_BURN is set
///           4. SHDLaunchFactoryTestnet wired to the three addresses above
///
///         Required env:  PRIVATE_KEY (0x-prefixed, TESTNET-ONLY key)
///         Optional env:  SHD_ADDRESS, V2_FACTORY, BUY_AND_BURN, SHD_SUPPLY (wei, default 1e9 SHD)
///
///   Dry run:  forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url pulsechain_testnet -vvv
///   Deploy:   forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url pulsechain_testnet --broadcast --slow -vvv
contract DeployTestnet is Script {
    uint256 internal constant TESTNET_CHAIN_ID = 943;

    function run() external {
        require(block.chainid == TESTNET_CHAIN_ID, "DeployTestnet: not PulseChain V4 testnet (943)");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        address shd = vm.envOr("SHD_ADDRESS", address(0));
        address v2Factory = vm.envOr("V2_FACTORY", address(0));
        address buyAndBurn = vm.envOr("BUY_AND_BURN", address(0));
        uint256 shdSupply = vm.envOr("SHD_SUPPLY", uint256(1_000_000_000 ether));

        if (shd != address(0)) require(shd.code.length > 0, "SHD_ADDRESS has no code");
        if (v2Factory != address(0)) require(v2Factory.code.length > 0, "V2_FACTORY has no code");
        if (buyAndBurn == address(0)) {
            // dummy sink so creation fees are visible on-chain but not held by the deployer
            buyAndBurn = address(uint160(uint256(keccak256("snipehead-testnet-buy-and-burn"))));
        }

        console2.log("Deployer      :", deployer);
        console2.log("Deployer tPLS :", deployer.balance);
        require(deployer.balance > 0, "deployer has no tPLS - use the faucet first");

        vm.startBroadcast(pk);

        if (shd == address(0)) {
            SnipeHeadToken t = new SnipeHeadToken("SnipeHead (testnet)", "tSHD", shdSupply);
            t.launch(); // unlock transfers, exactly like mainnet SHD
            t.renounceOwnership(); // no owner, exactly like mainnet SHD
            shd = address(t);
        }

        if (v2Factory == address(0)) {
            v2Factory = address(new MockV2Factory());
            console2.log("NOTE: using MockV2Factory (NOT real PulseX). Real-pair behaviour was verified on the mainnet fork.");
        }

        SHDLaunchFactoryTestnet factory = new SHDLaunchFactoryTestnet(shd, buyAndBurn, v2Factory);

        vm.stopBroadcast();

        // post-deploy sanity (read-only)
        require(address(factory.SHD()) == shd, "wiring: SHD");
        require(factory.BUY_AND_BURN() == buyAndBurn, "wiring: BUY_AND_BURN");
        require(address(factory.FACTORY()) == v2Factory, "wiring: FACTORY");

        console2.log("=========== DEPLOYED (chain 943) ===========");
        console2.log("SHD (test)        :", shd);
        console2.log("V2 factory        :", v2Factory);
        console2.log("BuyAndBurn sink   :", buyAndBurn);
        console2.log("SHDLaunchFactory  :", address(factory));
        console2.log("Deployer SHD bal  :", SnipeHeadToken(shd).balanceOf(deployer));
        console2.log("Explorer: https://scan.v4.testnet.pulsechain.com/address/", address(factory));
        console2.log("");
        console2.log("Set for E2E / frontend:");
        console2.log("  export FACTORY_ADDRESS=", address(factory));
        console2.log("  export SHD_ADDRESS=", shd);
    }
}
