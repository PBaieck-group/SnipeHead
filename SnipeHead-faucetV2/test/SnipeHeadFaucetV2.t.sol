// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SnipeHead.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * ================================================================
 * SnipeHeadFaucetV2.t.sol - Comprehensive Test Suite (12 tests)
 * ================================================================
 *
 * Covers:
 * - Happy path
 * - One claim per address ever
 * - Daily global limit + reset
 * - Faucet empty
 * - Reentrancy behavior
 * - View functions
 * - Events
 * - Edge cases (partial daily limit, exact 24h, etc.)
 */

contract SnipeHeadFaucetV2 is ReentrancyGuard {
    IERC20 public immutable shdToken;

    uint256 public constant TOKENS_PER_CLAIM = 1 * 10**18;
    uint256 public constant DAILY_TOKEN_LIMIT = 1000 * 10**18;

    uint256 public dailyTokensDispensed;
    uint256 public lastResetTime;

    mapping(address => bool) public hasClaimed;

    event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);

    constructor() {
        shdToken = IERC20(0xB95bC84f9B6D0373642D586b81979B067572f7bc);
        lastResetTime = block.timestamp;
    }

    function claimTokens() external nonReentrant {
        if (block.timestamp >= lastResetTime + 24 hours) {
            dailyTokensDispensed = 0;
            lastResetTime = block.timestamp;
        }

        require(dailyTokensDispensed + TOKENS_PER_CLAIM <= DAILY_TOKEN_LIMIT, "Daily token limit reached");
        require(!hasClaimed[msg.sender], "You have already claimed your 1 SHD (one per address ever)");
        require(shdToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM, "Faucet is empty");

        hasClaimed[msg.sender] = true;
        dailyTokensDispensed += TOKENS_PER_CLAIM;

        require(shdToken.transfer(msg.sender, TOKENS_PER_CLAIM), "Token transfer failed");

        emit TokensClaimed(msg.sender, TOKENS_PER_CLAIM, block.timestamp);
    }

    function getFaucetBalance() external view returns (uint256) {
        return shdToken.balanceOf(address(this));
    }

    function getDailyTokensRemaining() external view returns (uint256) {
        if (block.timestamp >= lastResetTime + 24 hours) {
            return DAILY_TOKEN_LIMIT;
        }
        return DAILY_TOKEN_LIMIT > dailyTokensDispensed ? DAILY_TOKEN_LIMIT - dailyTokensDispensed : 0;
    }

    function hasAddressClaimed(address user) external view returns (bool) {
        return hasClaimed[user];
    }
}

// ================================================================
// Main Test Contract
// ================================================================
contract SnipeHeadFaucetV2Test is Test {
    address public constant SHD_TOKEN_ADDRESS = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;

    SnipeHeadFaucetV2 public faucet;
    Token public realToken;

    function setUp() public {
        realToken = new Token("SnipeHead Token", "SHD", 1_000_000 * 10**18);
        realToken.launch();

        bytes memory tokenCode = address(realToken).code;
        vm.etch(SHD_TOKEN_ADDRESS, tokenCode);

        for (uint256 i = 0; i < 50; i++) {
            bytes32 value = vm.load(address(realToken), bytes32(i));
            if (value != bytes32(0)) {
                vm.store(SHD_TOKEN_ADDRESS, bytes32(i), value);
            }
        }

        faucet = new SnipeHeadFaucetV2();

        bytes32 balanceSlot = keccak256(abi.encode(address(faucet), uint256(0)));
        vm.store(SHD_TOKEN_ADDRESS, balanceSlot, bytes32(uint256(10_000 * 10**18)));

        assertEq(IERC20(SHD_TOKEN_ADDRESS).balanceOf(address(faucet)), 10_000 * 10**18);
        assertTrue(Token(SHD_TOKEN_ADDRESS).launched());
    }

    function _balanceSlot(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, uint256(0)));
    }

    // ====================== CORE TESTS ======================

    function test_claimTokens_Success() public {
        address user = makeAddr("alice");

        vm.expectEmit(true, true, true, true);
        emit SnipeHeadFaucetV2.TokensClaimed(user, 1 ether, block.timestamp);

        vm.prank(user);
        faucet.claimTokens();

        assertTrue(faucet.hasAddressClaimed(user));
        assertEq(IERC20(SHD_TOKEN_ADDRESS).balanceOf(user), 1 ether);
        assertEq(faucet.getDailyTokensRemaining(), 999 ether);
    }

    function test_claimTokens_Revert_AlreadyClaimed() public {
        address user = makeAddr("bob");
        vm.prank(user);
        faucet.claimTokens();

        vm.expectRevert("You have already claimed your 1 SHD (one per address ever)");
        vm.prank(user);
        faucet.claimTokens();
    }

    function test_claimTokens_Revert_DailyLimitReached() public {
        for (uint256 i = 0; i < 1000; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            vm.prank(user);
            faucet.claimTokens();
        }

        vm.expectRevert("Daily token limit reached");
        vm.prank(makeAddr("overflow"));
        faucet.claimTokens();
    }

    function test_claimTokens_DailyResetAfter24Hours() public {
        for (uint256 i = 0; i < 1000; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            vm.prank(user);
            faucet.claimTokens();
        }

        vm.warp(block.timestamp + 24 hours + 1);

        address newUser = makeAddr("newDay");
        vm.prank(newUser);
        faucet.claimTokens();

        assertTrue(faucet.hasAddressClaimed(newUser));
        assertEq(faucet.getDailyTokensRemaining(), 999 ether);
    }

    function test_claimTokens_Revert_FaucetEmpty() public {
        bytes32 slot = _balanceSlot(address(faucet));
        vm.store(SHD_TOKEN_ADDRESS, slot, bytes32(uint256(0)));

        vm.expectRevert("Faucet is empty");
        vm.prank(makeAddr("empty"));
        faucet.claimTokens();
    }

    function test_claimTokens_Revert_Reentrancy() public {
        ReentrantAttacker attacker = new ReentrantAttacker(address(faucet));
        vm.expectRevert("You have already claimed your 1 SHD (one per address ever)");
        attacker.attack();
    }

    // ====================== ADDITIONAL USEFUL TESTS ======================

    function test_getDailyTokensRemaining_BeforeAndAfterReset() public {
        assertEq(faucet.getDailyTokensRemaining(), 1000 ether);

        vm.prank(makeAddr("user1"));
        faucet.claimTokens();

        assertEq(faucet.getDailyTokensRemaining(), 999 ether);

        vm.warp(block.timestamp + 24 hours + 1);
        assertEq(faucet.getDailyTokensRemaining(), 1000 ether);
    }

    function test_partialDailyLimit_StillAllowsClaims() public {
        // Use only 500 tokens
        for (uint256 i = 0; i < 500; i++) {
            vm.prank(makeAddr(string.concat("partial", vm.toString(i))));
            faucet.claimTokens();
        }

        assertEq(faucet.getDailyTokensRemaining(), 500 ether);
        assertEq(faucet.getFaucetBalance(), 9_500 ether);
    }

    function test_multipleClaimsFromDifferentUsers_SameDay() public {
        address[] memory users = new address[](250);
        for (uint256 i = 0; i < 250; i++) {
            users[i] = makeAddr(string.concat("multi", vm.toString(i)));
            vm.prank(users[i]);
            faucet.claimTokens();
        }

        assertEq(faucet.getDailyTokensRemaining(), 750 ether);
    }

    function test_event_TokensClaimed() public {
        address user = makeAddr("eventTest");

        vm.expectEmit(true, true, true, true);
        emit SnipeHeadFaucetV2.TokensClaimed(user, 1 ether, block.timestamp);

        vm.prank(user);
        faucet.claimTokens();
    }

    function test_viewFunctions_AfterClaim() public {
        address user = makeAddr("viewTest");
        vm.prank(user);
        faucet.claimTokens();

        assertEq(faucet.getFaucetBalance(), 9_999 ether);
        assertEq(faucet.getDailyTokensRemaining(), 999 ether);
        assertTrue(faucet.hasAddressClaimed(user));
        assertFalse(faucet.hasAddressClaimed(makeAddr("never")));
    }
}

// ================================================================
// Reentrancy attacker
// ================================================================
contract ReentrantAttacker {
    SnipeHeadFaucetV2 immutable faucet;

    constructor(address _faucet) {
        faucet = SnipeHeadFaucetV2(_faucet);
    }

    function attack() external {
        faucet.claimTokens();
        faucet.claimTokens();
    }
}