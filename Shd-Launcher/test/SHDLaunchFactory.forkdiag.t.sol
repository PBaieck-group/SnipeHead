// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";
import {TokenMetadata} from "../src/SnipeLaunchToken.sol";
import {MockSHD} from "./mocks/MockPulseX.sol";

/// @notice Step-by-step probe of the real chain. Does not assert; it PRINTS where things break.
///         RUN_FORK=1 forge test --match-path test/SHDLaunchFactory.forkdiag.t.sol -vv
contract SHDLaunchFactoryForkDiag is Test {
    address constant SHD = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    address constant V2F = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;
    address constant BAB = 0x3677e61A7a9E79Fe45a882C201365C5165A5540e;

    function setUp() public {
        if (!vm.envOr("RUN_FORK", false)) vm.skip(true);
        vm.createSelectFork("pulsechain");
    }

    function _report(string memory step, bool ok, bytes memory ret) internal {
        if (ok) {
            emit log_named_string(step, "OK");
        } else {
            emit log_named_string(step, ret.length == 0 ? "REVERTED (empty data)" : "REVERTED (with data)");
            if (ret.length >= 4) emit log_named_bytes(string.concat(step, " revert data"), ret);
        }
    }

    function test_diag_1_codeExists() public {
        emit log_named_uint("code size SHD         ", SHD.code.length);
        emit log_named_uint("code size V2 factory  ", V2F.code.length);
        emit log_named_uint("code size BUY_AND_BURN", BAB.code.length);
    }

    function test_diag_2_creationFeeTransfer() public {
        address user = makeAddr("user");
        address spender = makeAddr("spender");
        deal(SHD, user, 1_000 ether);
        vm.prank(user);
        (bool ok, bytes memory r) = SHD.call(abi.encodeWithSignature("approve(address,uint256)", spender, 1_000 ether));
        _report("SHD.approve", ok, r);
        vm.prank(spender);
        (ok, r) = SHD.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", user, BAB, 1_000 ether));
        _report("SHD.transferFrom(user -> BUY_AND_BURN)", ok, r);
        emit log_named_uint("BUY_AND_BURN SHD balance", _bal(SHD, BAB));
    }

    function test_diag_3_createToken() public {
        SHDLaunchFactory f = new SHDLaunchFactory();
        address creator = makeAddr("creator");
        deal(SHD, creator, 1_000 ether);
        vm.startPrank(creator);
        (bool ok, bytes memory r) =
            SHD.call(abi.encodeWithSignature("approve(address,uint256)", address(f), type(uint256).max));
        _report("approve factory", ok, r);
        (ok, r) = address(f).call(
            abi.encodeCall(
                f.createToken,
                (
                    "Fork",
                    "FRK",
                    bytes32(0),
                    TokenMetadata("", "", ""),
                    SHDLaunchFactory.Mode.BondingCurve,
                    0,
                    0
                )
            )
        );
        _report("factory.createToken (BondingCurve)", ok, r);
        vm.stopPrank();
    }

    function test_diag_4_v2FactoryAndPair() public {
        address tok = address(new MockSHD()); // throwaway plain ERC-20
        (bool ok, bytes memory r) = V2F.call(abi.encodeWithSignature("getPair(address,address)", tok, SHD));
        _report("V2 factory.getPair", ok, r);
        (ok, r) = V2F.call(abi.encodeWithSignature("createPair(address,address)", tok, SHD));
        _report("V2 factory.createPair", ok, r);
        if (!ok) return;
        address pair = abi.decode(r, (address));

        MockSHD(tok).mint(address(this), 1_000 ether);
        deal(SHD, address(this), 1_000 ether);
        MockSHD(tok).transfer(pair, 1_000 ether);
        (ok, r) = SHD.call(abi.encodeWithSignature("transfer(address,uint256)", pair, 1_000 ether));
        _report("SHD.transfer(pair)", ok, r);
        (ok, r) = pair.call(abi.encodeWithSignature("mint(address,address)", address(this), address(this)));
        _report("pair.mint", ok, r);
    }

    function _bal(address t, address who) internal view returns (uint256) {
        (, bytes memory r) = t.staticcall(abi.encodeWithSignature("balanceOf(address)", who));
        return abi.decode(r, (uint256));
    }
}
