// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";

interface IERC20Full {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IPairFull {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function sync() external;
}

contract SHDLaunchFactoryForkTest is Test {
    IERC20Full internal constant SHD = IERC20Full(0xB95bC84f9B6D0373642D586b81979B067572f7bc);
    address internal constant BURN = 0x0000000000000000000000000000000000000369;
    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CREATOR_ALLOC = 1_050_000 ether;
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether;
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant REWARD = 50_000 ether;
    uint256 internal constant FEE = 10 ether;

    SHDLaunchFactory internal f;
    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        if (!vm.envOr("RUN_FORK", false)) vm.skip(true);
        vm.createSelectFork("pulsechain");
        f = new SHDLaunchFactory();
    }

    function _fund(address who, uint256 amount) internal {
        deal(address(SHD), who, amount);
        vm.prank(who);
        SHD.approve(address(f), type(uint256).max);
    }

    function _createBonding() internal returns (address t) {
        _fund(creator, FEE);
        vm.prank(creator);
        t = f.createToken(
            "Fork", "FRK", bytes32(0), TokenMetadata("", "", ""),
            SHDLaunchFactory.Mode.BondingCurve, 0, 0
        );
    }

    function _createInstant(uint256 shdAmount) internal returns (address t) {
        _fund(creator, FEE + shdAmount);
        vm.prank(creator);
        t = f.createToken(
            "Fork", "FRK", bytes32(0), TokenMetadata("", "", ""),
            SHDLaunchFactory.Mode.Instant, shdAmount, 0
        );
    }

    function _reserves(address t) internal view returns (uint256 tokenRes, uint256 shdRes) {
        address pair = f.FACTORY().getPair(t, address(SHD));
        (uint112 r0, uint112 r1,) = IPairFull(pair).getReserves();
        (tokenRes, shdRes) = IPairFull(pair).token0() == t ? (r0, r1) : (r1, r0);
    }

    function test_fork_instantLaunch() public {
        address t = _createInstant(100_000 ether);

        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, 100_000 ether);

        address pair = f.FACTORY().getPair(t, address(SHD));
        assertEq(IPairFull(pair).balanceOf(address(f)), 0);
        assertGt(IPairFull(pair).balanceOf(BURN), 0);
        assertTrue(LaunchToken(t).launched());
    }

    function test_fork_curveGraduationSurvivesDonateAndSync() public {
        address t = _createBonding();
        address pair = f.FACTORY().createPair(t, address(SHD));

        deal(address(SHD), attacker, 1);
        vm.startPrank(attacker);
        SHD.transfer(pair, 1);
        IPairFull(pair).sync();
        vm.stopPrank();

        _fund(alice, TARGET);
        vm.prank(alice);
        f.buy(t, TARGET, 0, 0);

        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(sr, TARGET - REWARD + 1);
        assertEq(tr, CURVE_SUPPLY - sold);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        assertTrue(LaunchToken(t).launched());
    }

    function test_fork_curveGraduation() public {
        address t = _createBonding();
        _fund(alice, TARGET);
        vm.prank(alice);
        f.buy(t, TARGET, 0, 0);

        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(sr, TARGET - REWARD);
        assertEq(tr, CURVE_SUPPLY - sold);
        assertEq(SHD.balanceOf(address(f)), 0);
        assertEq(LaunchToken(t).balanceOf(creator), CREATOR_ALLOC);
        assertEq(LaunchToken(t).balanceOf(creator) + sold + tr, SUPPLY);
        assertTrue(LaunchToken(t).launched());
    }

    function test_fork_shdHasNoTransferFee() public {
        deal(address(SHD), alice, 1_000 ether);
        uint256 before = SHD.balanceOf(attacker);
        vm.prank(alice);
        SHD.transfer(attacker, 1_000 ether);
        assertEq(SHD.balanceOf(attacker) - before, 1_000 ether);
    }
}
