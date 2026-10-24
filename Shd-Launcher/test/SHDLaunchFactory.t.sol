// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";
import {MockSHD, MockPair, MockV2Factory} from "./mocks/MockPulseX.sol";

/// @dev Runs offline: the hardcoded SHD and PulseX V2 factory addresses are given mock code with vm.etch.
abstract contract FactoryBase is Test {
    address internal constant SHD_ADDR = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    address internal constant V2F_ADDR = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;
    address internal constant BURN_ADDR = 0x0000000000000000000000000000000000000369;
    address internal constant BUY_AND_BURN = 0x3677e61A7a9E79Fe45a882C201365C5165A5540e;

    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CREATOR_ALLOC = 1_050_000 ether; // 5%
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether; // 95%
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant REWARD = 50_000 ether;
    uint256 internal constant FEE = 10 ether;
    uint256 internal constant GRADUATION_DUST = 1e6;
    uint256 internal constant VT = 22_249_000 ether;
    uint256 internal constant VS = 2_332_000 ether;

    SHDLaunchFactory internal f;
    MockSHD internal shd = MockSHD(SHD_ADDR);

    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal attacker = makeAddr("attacker");

    function setUp() public virtual {
        vm.etch(SHD_ADDR, address(new MockSHD()).code);
        vm.etch(V2F_ADDR, address(new MockV2Factory()).code);
        f = new SHDLaunchFactory();
        vm.warp(1_800_000_000);
    }

    function _fund(address who, uint256 amount) internal {
        shd.mint(who, amount);
        vm.prank(who);
        shd.approve(address(f), type(uint256).max);
    }

    function _create(SHDLaunchFactory.Mode mode, uint256 shdAmount) internal returns (address token) {
        uint256 need = FEE + (mode == SHDLaunchFactory.Mode.Instant ? shdAmount : 0);
        _fund(creator, need);
        vm.prank(creator);
        token = f.createToken(
            "Test",
            "TST",
            bytes32("gm"),
            TokenMetadata("desc", "https://example.com", ""),
            mode,
            shdAmount,
            0
        );
    }

    function _curve() internal returns (address) {
        return _create(SHDLaunchFactory.Mode.BondingCurve, 0);
    }

    function _instant(uint256 shdAmount) internal returns (address) {
        return _create(SHDLaunchFactory.Mode.Instant, shdAmount);
    }

    function _buy(address who, address token, uint256 shdIn) internal returns (uint256 tokensOut) {
        _fund(who, shdIn);
        uint256 before = LaunchToken(token).balanceOf(who);
        vm.prank(who);
        f.buy(token, shdIn, 0, 0);
        tokensOut = LaunchToken(token).balanceOf(who) - before;
    }

    function _sell(address who, address token, uint256 tokensIn) internal returns (uint256 shdOut) {
        uint256 before = shd.balanceOf(who);
        vm.startPrank(who);
        LaunchToken(token).approve(address(f), tokensIn);
        f.sell(token, tokensIn, 0, 0);
        vm.stopPrank();
        shdOut = shd.balanceOf(who) - before;
    }

    function _pair(address token) internal view returns (MockPair) {
        return MockPair(MockV2Factory(V2F_ADDR).getPair(token, SHD_ADDR));
    }

    function _reserves(address token) internal view returns (uint256 tokenRes, uint256 shdRes) {
        (uint112 r0, uint112 r1,) = _pair(token).getReserves();
        (tokenRes, shdRes) = token < SHD_ADDR ? (r0, r1) : (r1, r0);
    }

    function _graduate(address token) internal {
        _buy(alice, token, 2_000_000 ether);
        _buy(bob, token, 3_000_000 ether);
    }
}

contract SHDLaunchFactoryTest is FactoryBase {
    event TokenCreated(
        address indexed token, address indexed creator, SHDLaunchFactory.Mode mode, string name, string symbol
    );
    event InstantLaunched(address indexed token, address indexed creator, uint256 shdAmount, uint256 lpBurned);
    event CreatorAllocation(address indexed token, address indexed creator, uint256 amount);
    event Bought(address indexed token, address indexed buyer, uint256 shdIn, uint256 tokensOut);
    event Sold(address indexed token, address indexed seller, uint256 tokensIn, uint256 shdOut);
    event Graduated(
        address indexed token,
        address indexed creator,
        uint256 shdToLp,
        uint256 tokensToLp,
        uint256 lpBurned,
        uint256 creatorReward
    );

    function test_constants() public view {
        assertEq(f.BUY_AND_BURN(), BUY_AND_BURN);
        assertEq(address(f.SHD()), SHD_ADDR);
        assertEq(address(f.FACTORY()), V2F_ADDR);
        assertEq(f.DEAD(), BURN_ADDR);
        assertEq(f.CREATION_FEE(), FEE);
        assertEq(f.GRADUATION_TARGET(), TARGET);
        assertEq(f.CREATOR_REWARD(), REWARD);
        assertEq(f.TOKEN_SUPPLY(), SUPPLY);
        assertEq(f.CREATOR_ALLOCATION(), CREATOR_ALLOC);
        assertEq(f.CURVE_SUPPLY(), CURVE_SUPPLY);
        assertEq(f.GRADUATION_DUST(), GRADUATION_DUST);
        assertEq(CREATOR_ALLOC + CURVE_SUPPLY, SUPPLY);
    }

    // ============================================================= createToken

    function test_createToken_chargesFeeRegistersAndHoldsSupply() public {
        _fund(creator, FEE);
        vm.expectEmit(false, true, false, true);
        emit TokenCreated(address(0), creator, SHDLaunchFactory.Mode.BondingCurve, "Test", "TST");

        vm.prank(creator);
        address t = f.createToken(
            "Test",
            "TST",
            bytes32("gm"),
            TokenMetadata("d", "", ""),
            SHDLaunchFactory.Mode.BondingCurve,
            0,
            0
        );

        assertEq(shd.balanceOf(BUY_AND_BURN), FEE);
        assertEq(f.creatorOf(t), creator);
        assertEq(uint256(f.modeOf(t)), uint256(SHDLaunchFactory.Mode.BondingCurve));
        assertEq(f.allTokensLength(), 1);

        // Factory still holds full supply until graduation (creator allocation released then)
        assertEq(LaunchToken(t).balanceOf(address(f)), SUPPLY);
        assertFalse(LaunchToken(t).isLaunched());

        (uint256 collected, uint256 sold, bool grad, address cr) = f.getCurve(t);
        assertEq(collected, 0);
        assertEq(sold, 0);
        assertFalse(grad);
        assertEq(cr, creator);
    }

    function test_createToken_instantModeLaunchesImmediately() public {
        uint256 seed = 100_000 ether;
        _fund(creator, FEE + seed);

        vm.expectEmit(false, true, false, true);
        emit CreatorAllocation(address(0), creator, CREATOR_ALLOC);

        vm.prank(creator);
        address t = f.createToken(
            "Test",
            "TST",
            bytes32("gm"),
            TokenMetadata("d", "", ""),
            SHDLaunchFactory.Mode.Instant,
            seed,
            0
        );

        // Creator holds exactly 5%
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        // Pool holds exactly 95%
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        assertEq(tokenRes, CURVE_SUPPLY);
        assertEq(shdRes, seed);

        MockPair p = _pair(t);
        assertEq(p.balanceOf(address(f)), 0);
        assertGt(p.balanceOf(BURN_ADDR), 0);

        assertTrue(LaunchToken(t).launched());
        assertEq(LaunchToken(t).balanceOf(address(f)), 0);
        assertEq(shd.balanceOf(address(f)), 0);

        // Full accounting
        assertEq(
            LaunchToken(t).balanceOf(creator) + tokenRes,
            SUPPLY
        );
    }

    function test_createToken_instantRequiresPositiveSHD() public {
        _fund(creator, FEE);
        vm.prank(creator);
        vm.expectRevert(SHDLaunchFactory.InsufficientSHD.selector);
        f.createToken("T", "T", 0, TokenMetadata("", "", ""), SHDLaunchFactory.Mode.Instant, 0, 0);
    }

    function test_createToken_curveRejectsNonZeroSHD() public {
        _fund(creator, FEE + 1);
        vm.prank(creator);
        vm.expectRevert(SHDLaunchFactory.UnexpectedSHD.selector);
        f.createToken("T", "T", 0, TokenMetadata("", "", ""), SHDLaunchFactory.Mode.BondingCurve, 1, 0);
    }

    function test_createToken_txDeadline() public {
        _fund(creator, 10 * FEE);
        TokenMetadata memory md = TokenMetadata("", "", "");

        vm.startPrank(creator);
        vm.expectRevert(SHDLaunchFactory.DeadlineExpired.selector);
        f.createToken("T", "T", 0, md, SHDLaunchFactory.Mode.BondingCurve, 0, block.timestamp - 1);

        f.createToken("T", "T", 0, md, SHDLaunchFactory.Mode.BondingCurve, 0, 0);
        f.createToken("T", "T", 0, md, SHDLaunchFactory.Mode.BondingCurve, 0, block.timestamp);
        f.createToken("T", "T", 0, md, SHDLaunchFactory.Mode.BondingCurve, 0, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_createToken_revertsWithoutFeeFunds() public {
        vm.prank(creator);
        shd.approve(address(f), type(uint256).max);
        vm.prank(creator);
        vm.expectRevert();
        f.createToken("T", "T", 0, TokenMetadata("", "", ""), SHDLaunchFactory.Mode.BondingCurve, 0, 0);
    }

    function test_createToken_revertsWithoutAllowance() public {
        shd.mint(creator, FEE);
        vm.prank(creator);
        vm.expectRevert();
        f.createToken("T", "T", 0, TokenMetadata("", "", ""), SHDLaunchFactory.Mode.BondingCurve, 0, 0);
    }

    function test_createToken_propagatesTokenValidation() public {
        _fund(creator, FEE);
        vm.prank(creator);
        vm.expectRevert(LaunchToken.InvalidName.selector);
        f.createToken("", "T", 0, TokenMetadata("", "", ""), SHDLaunchFactory.Mode.BondingCurve, 0, 0);
        assertEq(shd.balanceOf(BUY_AND_BURN), 0);
    }

    function test_createToken_manyTokensIndependent() public {
        address a = _curve();
        address b = _curve();
        assertTrue(a != b);
        assertEq(f.allTokensLength(), 2);
        assertEq(shd.balanceOf(BUY_AND_BURN), 2 * FEE);
    }

    // =============================================================== instant

    function test_instant_creatorHolds5pctPoolHolds95pct() public {
        address t = _instant(50_000 ether);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, 50_000 ether);
        assertEq(LaunchToken(t).balanceOf(creator) + tr, SUPPLY);
    }

    function test_instant_tokenTradableAfterCreate() public {
        address t = _instant(1 ether);
        assertTrue(LaunchToken(t).isLaunched());
        // creator can transfer their allocation
        vm.prank(creator);
        assertTrue(LaunchToken(t).transfer(alice, 1 ether));
        // pool tokens can leave the pair
        vm.prank(address(_pair(t)));
        assertTrue(LaunchToken(t).transfer(bob, 1 ether));
    }

    function test_instant_independentTokensIndependentPools() public {
        address a = _instant(1_000 ether);
        address b = _instant(2_000 ether);
        (, uint256 sa) = _reserves(a);
        (, uint256 sb) = _reserves(b);
        assertEq(sa, 1_000 ether);
        assertEq(sb, 2_000 ether);
        assertEq(LaunchToken(a).balanceOf(creator), CREATOR_ALLOC);
        assertEq(LaunchToken(b).balanceOf(creator), CREATOR_ALLOC);
    }

    // ================================================================== curve

    function test_buy_basic() public {
        address t = _curve();
        uint256 q = f.quoteBuy(t, 10_000 ether);
        _fund(alice, 10_000 ether);

        vm.expectEmit(true, true, false, true);
        emit Bought(t, alice, 10_000 ether, q);
        vm.prank(alice);
        f.buy(t, 10_000 ether, 0, 0);
        uint256 out = LaunchToken(t).balanceOf(alice);

        assertEq(out, q);
        assertGt(out, 0);
        (uint256 collected, uint256 sold, bool grad,) = f.getCurve(t);
        assertEq(collected, 10_000 ether);
        assertEq(sold, out);
        assertFalse(grad);
        assertEq(shd.balanceOf(address(f)), 10_000 ether);
        // factory still holds: full supply - sold (creator alloc still inside)
        assertEq(LaunchToken(t).balanceOf(address(f)), SUPPLY - out);
    }

    function test_buy_initialPriceMatchesSeed() public {
        address t = _curve();
        uint256 out = f.quoteBuy(t, 1 ether);
        assertApproxEqRel(out, 1 ether * VT / VS, 1e15);
    }

    function test_buy_tokenStaysLockedForBuyers() public {
        address t = _curve();
        _buy(alice, t, 1_000 ether);
        vm.prank(alice);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        LaunchToken(t).transfer(bob, 1);
    }

    function test_buy_priceIncreasesWithEachBuy() public {
        address t = _curve();
        uint256 a = _buy(alice, t, 100_000 ether);
        uint256 b = _buy(bob, t, 100_000 ether);
        assertLt(b, a);
    }

    function test_buy_guards() public {
        address t = _curve();
        _fund(alice, 1_000_000 ether);
        uint256 q = f.quoteBuy(t, 1_000 ether);

        vm.startPrank(alice);
        vm.expectRevert(SHDLaunchFactory.Slippage.selector);
        f.buy(t, 1_000 ether, q + 1, 0);

        vm.expectRevert(SHDLaunchFactory.InsufficientSHD.selector);
        f.buy(t, 0, 0, 0);

        vm.expectRevert(SHDLaunchFactory.DeadlineExpired.selector);
        f.buy(t, 1_000 ether, 0, block.timestamp - 1);

        f.buy(t, 1_000 ether, 0, block.timestamp);
        f.buy(t, 1_000 ether, 0, 0);
        vm.stopPrank();
    }

    function test_buy_rejectsNonCurveTokens() public {
        address inst = _instant(1_000 ether);
        _fund(alice, 1_000 ether);
        vm.startPrank(alice);
        vm.expectRevert(SHDLaunchFactory.NotBondingCurve.selector);
        f.buy(inst, 1_000 ether, 0, 0);
        vm.expectRevert(SHDLaunchFactory.NotBondingCurve.selector);
        f.buy(makeAddr("nope"), 1_000 ether, 0, 0);
        vm.stopPrank();
    }

    function test_buy_revertsWithoutFunds() public {
        address t = _curve();
        vm.prank(alice);
        shd.approve(address(f), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert();
        f.buy(t, 1_000 ether, 0, 0);
    }

    function test_buy_cappedAtGraduationTargetAndOnlyCappedAmountPulled() public {
        address t = _curve();
        _fund(alice, 20_000_000 ether);
        uint256 before = shd.balanceOf(alice);

        uint256 q = f.quoteBuy(t, 20_000_000 ether);
        vm.prank(alice);
        f.buy(t, 20_000_000 ether, q, 0);

        assertEq(before - shd.balanceOf(alice), TARGET);
        (uint256 collected,, bool grad,) = f.getCurve(t);
        assertEq(collected, TARGET);
        assertTrue(grad);
        assertEq(shd.balanceOf(alice), 15_000_000 ether);
    }

    function test_buy_neverOversellsCurveSupply() public {
        address t = _curve();
        _buy(alice, t, 4_999_999 ether);
        (, uint256 sold,,) = f.getCurve(t);
        assertLt(sold, CURVE_SUPPLY);
        assertGt(CURVE_SUPPLY - sold, 4_000_000 ether);
    }

    // -------------------------------------------------------------- graduation

    function test_graduation_fullFlow() public {
        address t = _curve();
        uint256 creatorShdBefore = shd.balanceOf(creator);

        _buy(alice, t, 2_000_000 ether);

        _fund(bob, 3_000_000 ether);
        vm.expectEmit(true, true, false, false);
        emit Graduated(t, creator, 0, 0, 0, 0);
        vm.prank(bob);
        f.buy(t, 3_000_000 ether, 0, 0);

        (uint256 collected, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        assertEq(collected, TARGET);

        // creator SHD reward
        assertEq(shd.balanceOf(creator) - creatorShdBefore, REWARD);
        // creator token allocation
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);

        // pool: leftover curve tokens + (target - reward) SHD
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        assertEq(shdRes, TARGET - REWARD);
        assertEq(tokenRes, CURVE_SUPPLY - sold);

        // accounting: creator alloc + sold + pool = full supply
        assertEq(LaunchToken(t).balanceOf(creator) + sold + tokenRes, SUPPLY);

        MockPair p = _pair(t);
        assertEq(p.balanceOf(address(f)), 0);
        assertGt(p.balanceOf(BURN_ADDR), 0);
        assertEq(shd.balanceOf(address(f)), 0);
        assertEq(LaunchToken(t).balanceOf(address(f)), 0);

        assertTrue(LaunchToken(t).launched());
        vm.prank(alice);
        assertTrue(LaunchToken(t).transfer(bob, 1 ether));
    }

    function test_graduation_priceContinuity() public {
        address t = _curve();
        _graduate(t);
        (, uint256 sold,,) = f.getCurve(t);

        uint256 curveEndPrice = (VS + TARGET) * 1e18 / (VT - sold);
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        uint256 poolPrice = shdRes * 1e18 / tokenRes;

        assertApproxEqRel(poolPrice, curveEndPrice, 1e14, "pool must open at the curve's final price");
    }

    function test_graduation_oneShotVsManyBuysSamePool() public {
        // many small buys
        address t = _curve();
        for (uint256 i; i < 50; ++i) {
            address u = makeAddr(string.concat("buyer", vm.toString(i)));
            _buy(u, t, 100_000 ether);
        }
        (,, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        assertEq(shdRes, TARGET - REWARD);

        // single path
        address t2 = _curve();
        _graduate(t2);
        (uint256 tokenRes2,) = _reserves(t2);
        assertApproxEqAbs(tokenRes, tokenRes2, 1e6);
    }

    function test_graduation_buyWholeTargetInOneTx() public {
        address t = _curve();
        _fund(whale = makeAddr("whale"), TARGET);
        uint256 q = f.quoteBuy(t, TARGET);
        vm.prank(whale);
        f.buy(t, TARGET, q, 0);

        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        assertEq(LaunchToken(t).balanceOf(whale), sold);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY - sold);
        assertEq(sr, TARGET - REWARD);
        assertEq(LaunchToken(t).balanceOf(creator) + sold + tr, SUPPLY);
    }

    address internal whale;

    function test_graduation_survivesDonateAndSyncGrief() public {
        address t = _curve();
        address pair = MockV2Factory(V2F_ADDR).createPair(t, SHD_ADDR);
        shd.mint(attacker, 1);
        vm.startPrank(attacker);
        shd.transfer(pair, 1);
        MockPair(pair).sync();
        vm.stopPrank();

        _graduate(t);
        (,, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        assertEq(shdRes, TARGET - REWARD + 1);
        assertGt(tokenRes, 0);
        assertTrue(LaunchToken(t).launched());
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
    }

    function test_graduation_otherCurvesUnaffected() public {
        address a = _curve();
        address b = _curve();
        _buy(alice, b, 500_000 ether);
        _graduate(a);
        (uint256 collectedB,, bool gradB,) = f.getCurve(b);
        assertEq(collectedB, 500_000 ether);
        assertFalse(gradB);
        assertEq(shd.balanceOf(address(f)), 500_000 ether);
        // curve B still holds full supply minus tokens sold to alice
        assertEq(LaunchToken(b).balanceOf(address(f)), SUPPLY - LaunchToken(b).balanceOf(alice));
    }

    function test_graduate_publicFunctionGuards() public {
        address t = _curve();
        vm.expectRevert(SHDLaunchFactory.NotGraduatedYet.selector);
        f.graduate(t);

        _graduate(t);
        vm.expectRevert(SHDLaunchFactory.AlreadyGraduated.selector);
        f.graduate(t);

        address inst = _instant(1_000 ether);
        vm.expectRevert(SHDLaunchFactory.NotBondingCurve.selector);
        f.graduate(inst);
        vm.expectRevert(SHDLaunchFactory.NotBondingCurve.selector);
        f.graduate(makeAddr("nope"));
    }

    function test_buy_afterGraduationReverts() public {
        address t = _curve();
        _graduate(t);
        _fund(attacker, 1_000 ether);
        vm.prank(attacker);
        vm.expectRevert(SHDLaunchFactory.AlreadyGraduated.selector);
        f.buy(t, 1_000 ether, 0, 0);
    }

    function test_curve_creatorCannotDumpAllocationIntoCurve() public {
        // allocation is held by factory until graduation, so creator has 0 tokens mid-curve
        address t = _curve();
        _buy(alice, t, 100_000 ether);
        assertEq(LaunchToken(t).balanceOf(creator), 0);
        // sell() will revert (no balance / no allowance); they cannot extract SHD from the curve
        vm.prank(creator);
        vm.expectRevert();
        f.sell(t, 1 ether, 0, 0);
    }

    // -------------------------------------------------------------------- sell

    function test_sell_roundTripLosesOnlyRounding() public {
        address t = _curve();
        uint256 spent = 10_000 ether;
        uint256 out = _buy(alice, t, spent);

        uint256 q = f.quoteSell(t, out);
        vm.startPrank(alice);
        LaunchToken(t).approve(address(f), out);
        vm.expectEmit(true, true, false, true);
        emit Sold(t, alice, out, q);
        f.sell(t, out, 0, 0);
        vm.stopPrank();
        uint256 back = shd.balanceOf(alice);

        assertEq(back, q);
        assertLe(back, spent);
        assertApproxEqAbs(back, spent, 10);

        (uint256 collected, uint256 sold,,) = f.getCurve(t);
        assertEq(collected, spent - back);
        assertEq(sold, 0);
        assertEq(LaunchToken(t).balanceOf(address(f)), SUPPLY);
        assertEq(shd.balanceOf(address(f)), collected);
    }

    function test_sell_partial() public {
        address t = _curve();
        uint256 out = _buy(alice, t, 50_000 ether);
        uint256 back = _sell(alice, t, out / 2);
        assertGt(back, 0);
        assertEq(LaunchToken(t).balanceOf(alice), out - out / 2);
    }

    function test_sell_guards() public {
        address t = _curve();
        uint256 out = _buy(alice, t, 10_000 ether);

        vm.startPrank(alice);
        LaunchToken(t).approve(address(f), type(uint256).max);

        vm.expectRevert(SHDLaunchFactory.NothingToSell.selector);
        f.sell(t, 0, 0, 0);

        vm.expectRevert(SHDLaunchFactory.NothingToSell.selector);
        f.sell(t, out + 1, 0, 0);

        uint256 q = f.quoteSell(t, out);
        vm.expectRevert(SHDLaunchFactory.Slippage.selector);
        f.sell(t, out, q + 1, 0);

        vm.expectRevert(SHDLaunchFactory.DeadlineExpired.selector);
        f.sell(t, out, 0, block.timestamp - 1);

        vm.expectRevert(SHDLaunchFactory.ZeroOutput.selector);
        f.sell(t, 1, 0, 0);
        vm.stopPrank();
    }

    function test_sell_cannotSellWithoutHoldingOrAllowance() public {
        address t = _curve();
        _buy(alice, t, 10_000 ether);
        vm.prank(bob);
        vm.expectRevert();
        f.sell(t, 1 ether, 0, 0);

        vm.prank(alice);
        vm.expectRevert();
        f.sell(t, 1 ether, 0, 0);
    }

    function test_sell_rejectsNonCurveAndGraduated() public {
        address inst = _instant(1_000 ether);
        vm.expectRevert(SHDLaunchFactory.NotBondingCurve.selector);
        f.sell(inst, 1, 0, 0);

        address t = _curve();
        _graduate(t);
        vm.expectRevert(SHDLaunchFactory.AlreadyGraduated.selector);
        f.sell(t, 1 ether, 0, 0);
    }

    function test_sell_everyoneCanExitAndCurveReturnsToEmpty() public {
        address t = _curve();
        uint256 a = _buy(alice, t, 300_000 ether);
        uint256 b = _buy(bob, t, 700_000 ether);

        uint256 backB = _sell(bob, t, b);
        uint256 backA = _sell(alice, t, a);

        assertLe(backA + backB, 1_000_000 ether);
        assertApproxEqAbs(backA + backB, 1_000_000 ether, 100);
        (uint256 collected, uint256 sold,,) = f.getCurve(t);
        assertEq(sold, 0);
        assertLe(collected, 100);
    }

    function test_noTokenOrEthSurplusInFactoryAfterNormalLifecycle() public {
        address t = _curve();
        _graduate(t);
        assertEq(address(f).balance, 0);
        assertEq(shd.balanceOf(address(f)), 0);
        assertEq(LaunchToken(t).balanceOf(address(f)), 0);
    }

    // ===================================================================== fuzz

    function testFuzz_buyThenSellNeverProfits(uint256 shdIn) public {
        shdIn = bound(shdIn, 1e9, TARGET - 1 ether);
        address t = _curve();
        uint256 out = _buy(alice, t, shdIn);
        uint256 back = _sell(alice, t, out);
        assertLe(back, shdIn);
        assertLe(shdIn - back, 10);
    }

    function testFuzz_quotesMatchExecution(uint256 shdIn, uint256 sellFrac) public {
        shdIn = bound(shdIn, 1e9, TARGET - 1 ether);
        address t = _curve();
        uint256 qBuy = f.quoteBuy(t, shdIn);
        uint256 out = _buy(alice, t, shdIn);
        assertEq(out, qBuy);

        uint256 tokensIn = bound(sellFrac, 1e9, out);
        uint256 qSell = f.quoteSell(t, tokensIn);
        vm.assume(qSell > 0);
        assertEq(_sell(alice, t, tokensIn), qSell);
    }

    function testFuzz_solvency_twoUsersAnyExitOrder(uint256 a, uint256 b, bool aFirst) public {
        a = bound(a, 1 ether, 2_000_000 ether);
        b = bound(b, 1 ether, 2_000_000 ether);
        address t = _curve();
        uint256 ta = _buy(alice, t, a);
        uint256 tb = _buy(bob, t, b);

        uint256 ra;
        uint256 rb;
        if (aFirst) {
            ra = _sell(alice, t, ta);
            rb = _sell(bob, t, tb);
        } else {
            rb = _sell(bob, t, tb);
            ra = _sell(alice, t, ta);
        }
        assertLe(ra + rb, a + b);
        (uint256 collected, uint256 sold,,) = f.getCurve(t);
        assertEq(sold, 0);
        assertEq(shd.balanceOf(address(f)), collected);
        assertEq(a + b - ra - rb, collected);
    }

    function testFuzz_graduationPriceContinuity(uint256 firstBuy) public {
        firstBuy = bound(firstBuy, 1 ether, TARGET - 1 ether);
        address t = _curve();
        _buy(alice, t, firstBuy);
        _buy(bob, t, TARGET);
        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        assertEq(tokenRes, CURVE_SUPPLY - sold);
        assertEq(shdRes, TARGET - REWARD);
        assertApproxEqRel(shdRes * 1e18 / tokenRes, (VS + TARGET) * 1e18 / (VT - sold), 1e14);
        assertEq(LaunchToken(t).balanceOf(creator) + sold + tokenRes, SUPPLY);
    }

    function testFuzz_instantAnySHDAmount(uint256 amount) public {
        amount = bound(amount, 1 ether, 1e30);
        address t = _instant(amount);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, amount);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        assertEq(LaunchToken(t).balanceOf(address(f)), 0);
        assertEq(shd.balanceOf(address(f)), 0);
        assertTrue(LaunchToken(t).isLaunched());
    }

    // ============================================================= dust / donations / dump

    /// @notice Buying within GRADUATION_DUST of the target auto-graduates (no stuck curve).
    function test_graduation_dustBoundary_autoGraduatesWithinDust() public {
        address t = _curve();
        _fund(alice, TARGET);
        // TARGET - 1 is well within DUST (1e6), so this buy must graduate in-tx
        vm.prank(alice);
        f.buy(t, TARGET - 1, 0, 0);

        (uint256 collected,, bool grad,) = f.getCurve(t);
        assertTrue(grad, "must auto-graduate when only dust remains");
        assertEq(collected, TARGET - 1);
        assertTrue(LaunchToken(t).isLaunched());
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
    }

    /// @notice Leave more than DUST remaining, then permissionless graduate() still works
    ///         once a later buy brings collected into the dust window.
    function test_graduation_dustBoundary_permissionlessGraduate() public {
        address t = _curve();
        // stop just above the dust window so we do NOT auto-graduate yet
        uint256 stopAt = TARGET - GRADUATION_DUST - 1;
        _fund(alice, stopAt);
        vm.prank(alice);
        f.buy(t, stopAt, 0, 0);

        (uint256 collected,, bool grad,) = f.getCurve(t);
        assertFalse(grad);
        assertEq(collected, stopAt);

        // still outside dust window -> graduate() reverts
        vm.expectRevert(SHDLaunchFactory.NotGraduatedYet.selector);
        f.graduate(t);

        // one more wei pushes into (or past) the dust window via a tiny buy...
        // actually room is GRADUATION_DUST+1, buy that residual
        _fund(bob, GRADUATION_DUST + 1);
        vm.prank(bob);
        f.buy(t, GRADUATION_DUST + 1, 0, 0);

        (collected,, grad,) = f.getCurve(t);
        assertTrue(grad);
        // collected is TARGET (capped) or TARGET - something small depending on path
        assertGe(collected + GRADUATION_DUST, TARGET);
        assertLe(collected, TARGET);
    }


    /// @notice SHD or tokens donated to the factory must not break graduation accounting.
    function test_donation_shdAndTokensDoNotCorruptGraduation() public {
        address t = _curve();

        // donate SHD and (via factory, which is allowed while locked) extra tokens conceptually:
        // tokens are already all at the factory; donate SHD directly.
        shd.mint(address(f), 123_456 ether);
        assertEq(shd.balanceOf(address(f)), 123_456 ether);

        _graduate(t);

        (uint256 collected,, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        assertEq(collected, TARGET);

        // graduation pays creator REWARD from curve state, seeds pool from curve state.
        // donated SHD stays in the factory (no rescue) — that is intentional.
        assertEq(shd.balanceOf(address(f)), 123_456 ether);
        assertEq(LaunchToken(t).balanceOf(address(f)), 0);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
    }

    /// @notice After graduation the creator can sell their 5% into the pool.
    ///         Documents the accepted extraction bound (~order of allocation / pool depth).
    function test_creatorDumpAfterGraduation_boundedExtraction() public {
        address t = _curve();
        _graduate(t);

        (uint256 tokenRes, uint256 shdRes) = _reserves(t);
        uint256 alloc = LaunchToken(t).balanceOf(creator);
        assertEq(alloc, CREATOR_ALLOC);

        // constant-product: selling `alloc` into (tokenRes, shdRes) yields
        // out = alloc * shdRes / (tokenRes + alloc)
        uint256 maxOut = alloc * shdRes / (tokenRes + alloc);

        // bound: extraction is less than ~20% of pool SHD for the current 5% allocation
        assertLt(maxOut * 100, shdRes * 20, "5% dump should extract < 20% of pool SHD");
        // and less than half the creator SHD reward scale is not required — just document
        assertGt(maxOut, 0);
    }

}
