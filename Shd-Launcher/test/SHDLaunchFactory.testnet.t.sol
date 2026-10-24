// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactoryTestnet} from "../src/testnet/SHDLaunchFactoryTestnet.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";
import {MockV2Factory} from "./mocks/MockPulseX.sol";

interface ISHD {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function launched() external view returns (bool);
    function owner() external view returns (address);
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function sync() external;
}

contract SHDLaunchFactoryTestnetForkTest is Test {
    ISHD internal constant SHD = ISHD(0x60eB086a1b15eDADd73351d6Da128F3fB64F6Cb0);
    address internal constant DEPLOYER = 0x60ceA27f3323288e15244030E4E4511c60a3ac14;
    address internal constant BAB_SINK = 0x163c077ef5eED651718dB5D50A1EF65F5D2FB462;
    address internal constant V2F_ADDR = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;

    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CREATOR_ALLOC = 1_050_000 ether;
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether;
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant REWARD = 50_000 ether;
    uint256 internal constant FEE = 10 ether;

    SHDLaunchFactoryTestnet internal F;

    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal whale = makeAddr("whale");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        if (!vm.envOr("RUN_TESTNET", false)) vm.skip(true);
        vm.createSelectFork("pulsechain_testnet");
        require(block.chainid == 943, "not PulseChain V4 testnet");

        vm.etch(V2F_ADDR, address(new MockV2Factory()).code);
        F = new SHDLaunchFactoryTestnet(address(SHD), BAB_SINK, V2F_ADDR);
    }

    function _fund(address who, uint256 amount) internal {
        vm.prank(DEPLOYER);
        SHD.transfer(who, amount);
        vm.prank(who);
        SHD.approve(address(F), type(uint256).max);
    }

    function _createBonding(address who) internal returns (address t) {
        _fund(who, FEE);
        vm.prank(who);
        t = F.createToken(
            "Fork Test", "FTS", bytes32("fork"),
            TokenMetadata("desc", "https://example.com", ""),
            SHDLaunchFactoryTestnet.Mode.BondingCurve, 0, 0
        );
    }

    function _createInstant(address who, uint256 shdAmount) internal returns (address t) {
        _fund(who, FEE + shdAmount);
        vm.prank(who);
        t = F.createToken(
            "Fork Test", "FTS", bytes32("fork"),
            TokenMetadata("desc", "https://example.com", ""),
            SHDLaunchFactoryTestnet.Mode.Instant, shdAmount, 0
        );
    }

    function _reserves(address t) internal view returns (uint256 tokenRes, uint256 shdRes, address pair) {
        pair = F.FACTORY().getPair(t, address(SHD));
        (uint112 r0, uint112 r1,) = IPair(pair).getReserves();
        (tokenRes, shdRes) = IPair(pair).token0() == t ? (r0, r1) : (r1, r0);
    }

    function test_tn_deploymentIsWiredCorrectly() public view {
        assertEq(address(F.SHD()), address(SHD));
        assertEq(F.BUY_AND_BURN(), BAB_SINK);
        assertEq(F.CREATION_FEE(), FEE);
        assertEq(F.GRADUATION_TARGET(), TARGET);
        assertEq(F.CREATOR_REWARD(), REWARD);
        assertEq(F.TOKEN_SUPPLY(), SUPPLY);
        assertEq(F.CREATOR_ALLOCATION(), CREATOR_ALLOC);
        assertEq(F.CURVE_SUPPLY(), CURVE_SUPPLY);
        assertTrue(SHD.launched());
        assertEq(SHD.owner(), address(0));
    }

    function test_tn_createToken_chargesFeeAndRegisters() public {
        uint256 sinkBefore = SHD.balanceOf(BAB_SINK);
        uint256 n = F.allTokensLength();
        address t = _createBonding(creator);
        assertEq(SHD.balanceOf(BAB_SINK) - sinkBefore, FEE);
        assertEq(F.allTokensLength(), n + 1);
        assertEq(F.creatorOf(t), creator);
        assertEq(LaunchToken(t).balanceOf(address(F)), SUPPLY);
        assertFalse(LaunchToken(t).isLaunched());
    }

    function test_tn_createToken_txDeadline() public {
        _fund(creator, 10 * FEE);
        vm.expectRevert(SHDLaunchFactoryTestnet.DeadlineExpired.selector);
        vm.prank(creator);
        F.createToken("A", "A", 0, TokenMetadata("", "", ""), SHDLaunchFactoryTestnet.Mode.BondingCurve, 0, block.timestamp - 1);
        vm.prank(creator);
        F.createToken("A", "A", 0, TokenMetadata("", "", ""), SHDLaunchFactoryTestnet.Mode.BondingCurve, 0, 0);
    }

    function test_tn_createToken_needsFeeAndAllowance() public {
        vm.expectRevert();
        vm.prank(attacker);
        F.createToken("A", "A", 0, TokenMetadata("", "", ""), SHDLaunchFactoryTestnet.Mode.BondingCurve, 0, 0);
    }

    function test_tn_createToken_rejectsInvalidMetadata() public {
        _fund(creator, 10 * FEE);
        vm.expectRevert(LaunchToken.InvalidWebsite.selector);
        vm.prank(creator);
        F.createToken("A", "A", 0, TokenMetadata("", "javascript:alert(1)", ""), SHDLaunchFactoryTestnet.Mode.BondingCurve, 0, 0);
    }

    function test_tn_instant_fullFlow() public {
        address t = _createInstant(creator, 100_000 ether);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        (uint256 tr, uint256 sr, address pair) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, 100_000 ether);
        assertEq(IPair(pair).balanceOf(address(F)), 0);
        assertGt(IPair(pair).balanceOf(F.DEAD()), 0);
        assertTrue(LaunchToken(t).isLaunched());
    }

    function test_tn_instant_inputGuards() public {
        _fund(creator, FEE);
        vm.expectRevert(SHDLaunchFactoryTestnet.InsufficientSHD.selector);
        vm.prank(creator);
        F.createToken("A", "A", 0, TokenMetadata("", "", ""), SHDLaunchFactoryTestnet.Mode.Instant, 0, 0);

        _fund(creator, FEE + 1);
        vm.expectRevert(SHDLaunchFactoryTestnet.UnexpectedSHD.selector);
        vm.prank(creator);
        F.createToken("A", "A", 0, TokenMetadata("", "", ""), SHDLaunchFactoryTestnet.Mode.BondingCurve, 1, 0);
    }

    function test_tn_instant_survivesDonateAndSync() public {
        address t = _createBonding(creator);
        address pair = F.FACTORY().createPair(t, address(SHD));
        _fund(attacker, 1);
        vm.startPrank(attacker);
        SHD.transfer(pair, 1);
        IPair(pair).sync();
        vm.stopPrank();

        _fund(whale, TARGET);
        vm.prank(whale);
        F.buy(t, TARGET, 0, 0);

        (,, bool g,) = F.getCurve(t);
        assertTrue(g);
        (uint256 tr, uint256 sr,) = _reserves(t);
        assertEq(sr, TARGET - REWARD + 1);
        assertGt(tr, 0);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        assertTrue(LaunchToken(t).isLaunched());
    }

    function test_tn_curve_buyQuoteSellRoundTrip() public {
        address t = _createBonding(creator);
        _fund(alice, 100_000 ether);
        uint256 q = F.quoteBuy(t, 10_000 ether);
        vm.prank(alice);
        F.buy(t, 10_000 ether, q, 0);
        assertEq(LaunchToken(t).balanceOf(alice), q);

        uint256 quoted = F.quoteSell(t, q);
        uint256 shdBefore = SHD.balanceOf(alice);
        vm.startPrank(alice);
        LaunchToken(t).approve(address(F), q);
        F.sell(t, q, quoted, 0);
        vm.stopPrank();
        assertEq(SHD.balanceOf(alice) - shdBefore, quoted);
        assertLe(quoted, 10_000 ether);
    }

    function test_tn_curve_tokensLockedForBuyers() public {
        address t = _createBonding(creator);
        _fund(alice, 10_000 ether);
        vm.prank(alice);
        F.buy(t, 10_000 ether, 0, 0);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        vm.prank(alice);
        LaunchToken(t).transfer(bob, 1 ether);
    }

    function test_tn_curve_guards() public {
        address t = _createBonding(creator);
        address inst = _createInstant(creator, 1_000 ether);
        _fund(alice, 100_000 ether);
        uint256 q = F.quoteBuy(t, 1_000 ether);

        vm.expectRevert(SHDLaunchFactoryTestnet.Slippage.selector);
        vm.prank(alice);
        F.buy(t, 1_000 ether, q + 1, 0);

        vm.expectRevert(SHDLaunchFactoryTestnet.NotBondingCurve.selector);
        vm.prank(alice);
        F.buy(inst, 1_000 ether, 0, 0);

        vm.expectRevert(SHDLaunchFactoryTestnet.NotGraduatedYet.selector);
        F.graduate(t);
    }

    function test_tn_curve_sellWithoutHoldingReverts() public {
        address t = _createBonding(creator);
        _fund(alice, 10_000 ether);
        vm.prank(alice);
        F.buy(t, 10_000 ether, 0, 0);
        vm.expectRevert();
        vm.prank(attacker);
        F.sell(t, 1 ether, 0, 0);
    }

    function test_tn_curve_graduation_fullFlow() public {
        address t = _createBonding(creator);
        _fund(whale, TARGET);
        uint256 creatorBefore = SHD.balanceOf(creator);
        uint256 q = F.quoteBuy(t, TARGET);

        vm.prank(whale);
        F.buy(t, TARGET, q, 0);

        (uint256 collected, uint256 sold, bool g,) = F.getCurve(t);
        assertTrue(g);
        assertEq(collected, TARGET);
        assertEq(SHD.balanceOf(creator) - creatorBefore, REWARD);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);

        (uint256 tr, uint256 sr, address pair) = _reserves(t);
        assertEq(sr, TARGET - REWARD);
        assertEq(tr, CURVE_SUPPLY - sold);
        assertEq(LaunchToken(t).balanceOf(creator) + sold + tr, SUPPLY);
        assertEq(IPair(pair).balanceOf(address(F)), 0);
        assertGt(IPair(pair).balanceOf(F.DEAD()), 0);
        assertTrue(LaunchToken(t).isLaunched());
    }

    function test_tn_curve_graduation_cappedOvershoot() public {
        address t = _createBonding(creator);
        _fund(whale, TARGET + 1_000_000 ether);
        vm.prank(whale);
        F.buy(t, TARGET + 1_000_000 ether, 0, 0);
        (uint256 collected,, bool g,) = F.getCurve(t);
        assertTrue(g);
        assertEq(collected, TARGET);
        assertEq(SHD.balanceOf(whale), 1_000_000 ether);
    }

    function test_tn_curve_independentTokens() public {
        address a = _createBonding(creator);
        address b = _createBonding(alice);
        _fund(bob, 20_000 ether);
        vm.prank(bob);
        F.buy(a, 10_000 ether, 0, 0);
        (uint256 ca,,,) = F.getCurve(a);
        (uint256 cb,,,) = F.getCurve(b);
        assertEq(ca, 10_000 ether);
        assertEq(cb, 0);
    }
}
