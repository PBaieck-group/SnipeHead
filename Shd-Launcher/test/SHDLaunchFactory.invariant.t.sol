// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";
import {MockSHD, MockV2Factory} from "./mocks/MockPulseX.sol";

contract CurveHandler is Test {
    SHDLaunchFactory public immutable f;
    MockSHD public immutable shd;
    LaunchToken public immutable token;
    address[] internal _actors;

    constructor(SHDLaunchFactory f_, MockSHD shd_, LaunchToken token_) {
        f = f_;
        shd = shd_;
        token = token_;
        for (uint256 i; i < 5; ++i) {
            _actors.push(makeAddr(string.concat("actor", vm.toString(i))));
        }
    }

    function actors() external view returns (address[] memory) {
        return _actors;
    }

    function buy(uint256 seed, uint256 amount) external {
        address a = _actors[seed % _actors.length];
        amount = bound(amount, 1 ether, 2_500_000 ether);
        shd.mint(a, amount);
        vm.startPrank(a);
        shd.approve(address(f), amount);
        try f.buy(address(token), amount, 0, 0) {} catch {}
        vm.stopPrank();
    }

    function sell(uint256 seed, uint256 amount) external {
        address a = _actors[seed % _actors.length];
        uint256 bal = token.balanceOf(a);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.startPrank(a);
        token.approve(address(f), amount);
        try f.sell(address(token), amount, 0, 0) {} catch {}
        vm.stopPrank();
    }
}

contract SHDLaunchFactoryInvariantTest is Test {
    address internal constant SHD_ADDR = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    address internal constant V2F_ADDR = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;
    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CREATOR_ALLOC = 1_050_000 ether;
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether;
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant VT = 22_249_000 ether;
    uint256 internal constant VS = 2_332_000 ether;

    SHDLaunchFactory internal f;
    MockSHD internal shd = MockSHD(SHD_ADDR);
    LaunchToken internal token;
    CurveHandler internal handler;
    address internal creator;

    function setUp() public {
        vm.warp(1_800_000_000);
        vm.etch(SHD_ADDR, address(new MockSHD()).code);
        vm.etch(V2F_ADDR, address(new MockV2Factory()).code);
        f = new SHDLaunchFactory();

        creator = makeAddr("creator");
        shd.mint(creator, 10 ether);
        vm.startPrank(creator);
        shd.approve(address(f), type(uint256).max);
        token = LaunchToken(
            f.createToken(
                "Inv",
                "INV",
                bytes32(0),
                TokenMetadata("", "", ""),
                SHDLaunchFactory.Mode.BondingCurve,
                0,
                0
            )
        );
        vm.stopPrank();

        handler = new CurveHandler(f, shd, token);
        targetContract(address(handler));
        bytes4[] memory sels = new bytes4[](2);
        sels[0] = CurveHandler.buy.selector;
        sels[1] = CurveHandler.sell.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_custodyMatchesAccounting() public view {
        (uint256 collected, uint256 sold, bool grad,) = f.getCurve(address(token));
        if (!grad) {
            assertEq(shd.balanceOf(address(f)), collected, "SHD custody");
            // factory holds full supply minus sold (creator alloc still inside)
            assertEq(token.balanceOf(address(f)), SUPPLY - sold, "token custody");
            // must not sit at/above target without graduating (dust window included)
            assertLt(collected + 1e6, TARGET, "target+dust reached without graduating");
        } else {
            // dust graduation may leave collected slightly under TARGET
            assertGe(collected + 1e6, TARGET, "graduated too early");
            assertLe(collected, TARGET, "graduation overshoot");
            assertEq(shd.balanceOf(address(f)), 0, "SHD left after graduation");
            assertEq(token.balanceOf(address(f)), 0, "tokens left after graduation");
            assertTrue(token.launched());
            assertEq(token.balanceOf(creator), CREATOR_ALLOC, "creator alloc at graduation");
        }
    }

    function invariant_soldEqualsHolderBalances() public view {
        (, uint256 sold, bool grad,) = f.getCurve(address(token));
        address[] memory a = handler.actors();
        uint256 sum;
        for (uint256 i; i < a.length; ++i) {
            sum += token.balanceOf(a[i]);
        }
        // after graduation, creator also holds allocation — exclude that from "sold"
        if (grad) {
            assertEq(sum, sold); // actors only; creator not in actors list
        } else {
            assertEq(sum, sold);
        }
    }

    function invariant_constantProductNeverDecreases() public view {
        (uint256 collected, uint256 sold,,) = f.getCurve(address(token));
        assertGe((VT - sold) * (VS + collected), VT * VS);
    }

    function invariant_curveIsSolvent() public view {
        (uint256 collected, uint256 sold, bool grad,) = f.getCurve(address(token));
        if (grad) return;
        uint256 payout = sold == 0 ? 0 : (sold * (VS + collected)) / (VT - sold + sold);
        assertLe(payout, collected);
    }
}
