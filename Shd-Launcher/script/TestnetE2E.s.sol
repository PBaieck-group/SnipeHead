// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {SHDLaunchFactoryTestnet} from "../src/testnet/SHDLaunchFactoryTestnet.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

/// @notice LIVE end-to-end run on PulseChain V4 testnet (real transactions, costs a little tPLS).
///         It creates demo data so the frontend has something to show:
///           - "Demo Instant"  : Instant token, created+launched in one tx with 100k SHD
///           - "Demo Curve"    : bonding-curve token, partially bought, one holder sold half (open)
///           - "Demo Graduated": bonding-curve token bought to the 5M target (graduated, pool seeded)
///
///         NOTE: Instant mode no longer has a separate "pending/locked" state after createToken —
///         createToken(Instant, shdAmount) launches immediately. Use BondingCurve for a locked
///         pre-graduation token.
///
///         Required env:  PRIVATE_KEY, FACTORY_ADDRESS, SHD_ADDRESS
///         Test wallets (alice/bob/whale) are derived deterministically from fixed strings —
///         PUBLICLY KNOWN keys. Use them on TESTNET ONLY.
///
///   Dry run:  forge script script/TestnetE2E.s.sol:TestnetE2E --rpc-url pulsechain_testnet -vvv
///   Live:     forge script script/TestnetE2E.s.sol:TestnetE2E --rpc-url pulsechain_testnet \
///               --broadcast --slow --legacy --with-gas-price 10000000000 -vvv
contract TestnetE2E is Script {
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant FEE = 10 ether;

    function run() external {
        require(block.chainid == 943, "TestnetE2E: not PulseChain V4 testnet (943)");

        address factoryAddr = vm.envAddress("FACTORY_ADDRESS");
        address shdAddr = vm.envAddress("SHD_ADDRESS");
        SHDLaunchFactoryTestnet F = SHDLaunchFactoryTestnet(factoryAddr);
        IERC20Min SHD = IERC20Min(shdAddr);

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 aliceKey = uint256(keccak256("snipehead-testnet-alice"));
        uint256 bobKey = uint256(keccak256("snipehead-testnet-bob"));
        uint256 whaleKey = uint256(keccak256("snipehead-testnet-whale"));
        address alice = vm.addr(aliceKey);
        address bob = vm.addr(bobKey);
        address whale = vm.addr(whaleKey);

        console2.log("Factory:", factoryAddr);
        console2.log("SHD    :", shdAddr);
        console2.log("alice (curve creator):", alice);
        console2.log("bob   (instant creator / curve buyer):", bob);
        console2.log("whale (graduation buyer):", whale);

        // ---------------------------------------------------------- 1. fund wallets
        vm.startBroadcast(deployerKey);
        _sendPls(alice, 2 ether);
        _sendPls(bob, 2 ether);
        _sendPls(whale, 2 ether);
        // alice: fee x2 for two curves
        SHD.transfer(alice, 2 * FEE);
        // bob: fee + 100k instant seed + 20k curve buy
        SHD.transfer(bob, FEE + 100_000 ether + 20_000 ether);
        // whale: full graduation target
        SHD.transfer(whale, TARGET);
        vm.stopBroadcast();

        // ---------------------------------------------------------- 2. alice creates two curve tokens
        address demoCurve;
        address demoGraduated;
        vm.startBroadcast(aliceKey);
        SHD.approve(address(F), type(uint256).max);
        demoCurve = F.createToken(
            "Demo Curve",
            "DCURVE",
            bytes32("e2e"),
            TokenMetadata("Bonding curve, in progress", "https://example.com", ""),
            SHDLaunchFactoryTestnet.Mode.BondingCurve,
            0,
            0
        );
        demoGraduated = F.createToken(
            "Demo Graduated",
            "DGRAD",
            bytes32("e2e"),
            TokenMetadata("Bonding curve, graduated", "https://example.com", ""),
            SHDLaunchFactoryTestnet.Mode.BondingCurve,
            0,
            0
        );
        vm.stopBroadcast();

        // ---------------------------------------------------------- 3. bob: Instant (launches in createToken) + buys on curve
        address demoInstant;
        vm.startBroadcast(bobKey);
        SHD.approve(address(F), type(uint256).max);
        demoInstant = F.createToken(
            "Demo Instant",
            "DINST",
            bytes32("e2e"),
            TokenMetadata("Instant launch, live", "https://example.com", ""),
            SHDLaunchFactoryTestnet.Mode.Instant,
            100_000 ether,
            0
        );

        // bob buys 20k SHD of Demo Curve
        uint256 q = F.quoteBuy(demoCurve, 20_000 ether);
        F.buy(demoCurve, 20_000 ether, (q * 99) / 100, 0);
        vm.stopBroadcast();

        // ---------------------------------------------------------- 4. whale: graduate one curve
        vm.startBroadcast(whaleKey);
        SHD.approve(address(F), type(uint256).max);
        uint256 qg = F.quoteBuy(demoGraduated, TARGET);
        F.buy(demoGraduated, TARGET, (qg * 99) / 100, 0);
        vm.stopBroadcast();

        // ---------------------------------------------------------- 5. bob sells half of his Demo Curve tokens
        vm.startBroadcast(bobKey);
        uint256 half = LaunchToken(demoCurve).balanceOf(bob) / 2;
        LaunchToken(demoCurve).approve(address(F), half);
        F.sell(demoCurve, half, 0, 0);
        vm.stopBroadcast();

        console2.log("=========== E2E DEMO DATA (chain 943) ===========");
        console2.log("Demo Instant   (launched) :", demoInstant);
        console2.log("Demo Curve     (open)     :", demoCurve);
        console2.log("Demo Graduated (graduated):", demoGraduated);
        (uint256 c1, uint256 s1, bool g1,) = F.getCurve(demoCurve);
        (uint256 c2,, bool g2,) = F.getCurve(demoGraduated);
        console2.log("Demo Curve   collected SHD:", c1);
        console2.log("Demo Curve   tokens sold  :", s1);
        console2.log("Demo Curve   graduated    :", g1);
        console2.log("Demo Graduated collected  :", c2);
        console2.log("Demo Graduated graduated  :", g2);
        console2.log("Demo Instant launched     :", LaunchToken(demoInstant).isLaunched());
    }

    function _sendPls(address to, uint256 amount) internal {
        (bool ok,) = payable(to).call{value: amount}("");
        require(ok, "PLS transfer failed");
    }
}
