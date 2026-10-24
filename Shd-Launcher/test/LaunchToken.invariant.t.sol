// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";

/// @dev Random-action handler. `recipient` plays the role of the LaunchFactory.
contract Handler is Test {
    LaunchToken public immutable token;
    address public immutable recipient;
    address[] public actors;

    uint256 public ghostBurned;
    bool public ghostEverLaunched;
    bool public ghostLockBypassed; // set if a holder->holder transfer succeeded while locked

    constructor(LaunchToken t, address recipient_) {
        token = t;
        recipient = recipient_;
        actors.push(recipient_);
        for (uint256 i; i < 4; ++i) {
            actors.push(makeAddr(string.concat("actor", vm.toString(i))));
        }
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        bool lockedBefore = !token.isLaunched();

        vm.prank(from);
        try token.transfer(to, amount) {
            if (lockedBefore && from != recipient && to != recipient) ghostLockBypassed = true;
        } catch {}
    }

    function transferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner_ = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(owner_));
        bool lockedBefore = !token.isLaunched();

        vm.prank(owner_);
        token.approve(spender, amount);

        vm.prank(spender);
        try token.transferFrom(owner_, to, amount) {
            if (lockedBefore && owner_ != recipient && to != recipient) ghostLockBypassed = true;
        } catch {}
    }

    function burn(uint256 fromSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        token.burn(amount);
        ghostBurned += amount;
    }

    function launch(uint256 callerSeed) external {
        address caller = actors[callerSeed % actors.length];
        vm.prank(caller);
        try token.launch() {
            ghostEverLaunched = true;
        } catch {}
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 20 days));
        // Time alone never unlocks the token in the new design
    }
}

contract LaunchTokenInvariantTest is Test {
    LaunchToken internal token;
    Handler internal handler;

    function setUp() public {
        address recipient = makeAddr("factory");
        token = new LaunchToken(
            "Inv", "INV", makeAddr("creator"), bytes32(0), recipient, TokenMetadata("", "", "")
        );
        handler = new Handler(token, recipient);
        targetContract(address(handler));
    }

    /// Balances of all actors always add up to totalSupply (nothing minted/lost/leaked).
    function invariant_BalancesSumToTotalSupply() public view {
        uint256 sum;
        for (uint256 i; i < handler.actorCount(); ++i) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(sum, token.totalSupply());
    }

    /// Supply only ever goes down, and exactly by what was burned.
    function invariant_SupplyEqualsInitialMinusBurned() public view {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY() - handler.ghostBurned());
    }

    /// A holder-to-holder transfer must never succeed while the token is locked.
    function invariant_LockCannotBeBypassed() public view {
        assertFalse(handler.ghostLockBypassed());
    }

    /// Once launched it stays launched. Time alone never launches.
    function invariant_LaunchIsOneWay() public view {
        if (handler.ghostEverLaunched()) assertTrue(token.isLaunched());
    }
}
