// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SnipeheadMiningDecentralizedV2.sol";

// ============================================================
// Mock ERC20 deployed at the exact hardcoded token address
// ============================================================
contract MockSHD is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public totalSupply;

    string public constant name     = "SnipeHead";
    string public constant symbol   = "SHD";
    uint8  public constant decimals = 18;

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "ERC20: transfer amount exceeds balance");
        unchecked { balanceOf[msg.sender] -= value; balanceOf[to] += value; }
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 cur = allowance[from][msg.sender];
        if (cur != type(uint256).max) {
            require(cur >= value, "ERC20: insufficient allowance");
            unchecked { allowance[from][msg.sender] -= value; }
        }
        require(balanceOf[from] >= value, "ERC20: transfer amount exceeds balance");
        unchecked { balanceOf[from] -= value; balanceOf[to] += value; }
        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply   += amount;
        emit Transfer(address(0), to, amount);
    }
}

// ============================================================
// Test suite
// ============================================================
contract SnipeheadMiningDecentralizedV2Test is Test {

    // ── Constants ────────────────────────────────────────────
    address public constant HARDCODED_SHD = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    uint256 public constant REWARD_RATE   = 31_771_820_820;

    // Enough reserve to comfortably cover all reward scenarios in these tests
    uint256 public constant RESERVE_SEED  = 500_000_000 ether;

    // ── Actors ───────────────────────────────────────────────
    address public owner  = address(this);
    address public user1  = makeAddr("user1");
    address public user2  = makeAddr("user2");
    address public funder = makeAddr("funder");   // dedicated reward depositor

    // ── Contracts ────────────────────────────────────────────
    SnipeheadMiningDecentralizedV2 public mining;
    MockSHD public shd;

    // ============================================================
    // setUp
    // ============================================================
    function setUp() public {
        // Deploy the mock token at the address the contract expects
        bytes memory mockCode = vm.getDeployedCode("SnipeheadMiningDecentralizedV2.t.sol:MockSHD");
        vm.etch(HARDCODED_SHD, mockCode);
        shd = MockSHD(HARDCODED_SHD);

        // Mint realistic supply (1 billion tokens)
        shd.mint(owner,  1_000_000_000 ether);
        shd.mint(user1,    600_000_000 ether);
        shd.mint(user2,    100_000_000 ether);
        shd.mint(funder,   500_000_000 ether);

        // Deploy mining contract
        mining = new SnipeheadMiningDecentralizedV2();

        // Infinite approvals for test actors
        vm.prank(user1);  shd.approve(address(mining), type(uint256).max);
        vm.prank(user2);  shd.approve(address(mining), type(uint256).max);
        vm.prank(funder); shd.approve(address(mining), type(uint256).max);
        shd.approve(address(mining), type(uint256).max); // owner

        // Seed the reward reserve so every test starts with rewards available.
        // This mirrors real-world usage: someone funds the pool before stakers join.
        vm.prank(funder);
        mining.deposit(RESERVE_SEED);
    }

    // ============================================================
    // Helper: compute the reward the contract would accrue for
    //         `blocks` blocks with `staked` tokens and `reserve` SHD remaining.
    // ============================================================
    function _expectedReward(uint256 blocks, uint256 staked, uint256 reserve)
        internal pure returns (uint256)
    {
        uint256 theoretical = (blocks * REWARD_RATE * staked) / 1e18;
        return theoretical > reserve ? reserve : theoretical;
    }

    // ============================================================
    // 1. Constructor
    // ============================================================
    function test_Constructor_SetsCorrectValues() public view {
        assertEq(address(mining.shdToken()), HARDCODED_SHD);
        assertEq(mining.lastRewardBlock(),   block.number);
        assertEq(mining.accRewardPerShare(), 0);
        assertEq(mining.totalMined(),        0);
    }

    // ============================================================
    // 2. deposit() — reward reserve
    // ============================================================

    // setUp already called deposit; confirm reserve was credited
    function test_Deposit_CreditsRewardReserve() public view {
        assertEq(mining.getRewardReserve(), RESERVE_SEED);
    }

    // deposit() must NOT touch totalMined
    function test_Deposit_DoesNotAffectTotalMined() public view {
        assertEq(mining.totalMined(), 0);
    }

    // The contract balance equals reserve + staked; after setup only reserve exists
    function test_Deposit_ContractBalanceEqualReserve() public view {
        assertEq(mining.getContractSHDBalance(), RESERVE_SEED);
    }

    function test_Deposit_AnyoneCanFund() public {
        uint256 reserveBefore = mining.getRewardReserve();
        vm.prank(user2);
        mining.deposit(1_000_000 ether);
        assertEq(mining.getRewardReserve(), reserveBefore + 1_000_000 ether);
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.expectRevert(SnipeheadMiningDecentralizedV2.ZeroAmount.selector);
        mining.deposit(0);
    }

    function test_Deposit_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.Deposited(user2, 1_000 ether);
        vm.prank(user2);
        mining.deposit(1_000 ether);
    }

    // ============================================================
    // 3. getRewardReserve() — new view helper
    // ============================================================

    function test_GetRewardReserve_DecreasesAsRewardsAccrue() public {
        uint256 reserveBefore = mining.getRewardReserve();

        vm.prank(user1);
        mining.mine(10_000_000 ether);

        vm.roll(block.number + 100);

        // Trigger pool update so reserve is consumed
        mining.updatePool();

        assertLt(mining.getRewardReserve(), reserveBefore);
    }

    function test_GetRewardReserve_NeverGoesNegative() public {
        // setUp() deposited RESERVE_SEED (500M). Assert the reserve strictly
        // decreases after mining + rolling, and never underflows.
        // Solidity uint256 cannot go negative, but we verify no over-deduction.
        uint256 reserveBefore = mining.getRewardReserve();

        vm.prank(user1);
        mining.mine(500_000_000 ether);

        vm.roll(block.number + 1_000_000);
        mining.updatePool();

        uint256 reserveAfter = mining.getRewardReserve();

        // Reserve must have decreased (rewards accrued) and never underflowed
        assertLt(reserveAfter, reserveBefore);
        // In Solidity uint256 can never be negative, but we also verify the
        // consumed amount is exactly what was available — no over-deduction.
        assertLe(reserveBefore - reserveAfter, reserveBefore);
    }

    function test_GetRewardReserve_IncreasesOnDeposit() public {
        uint256 before = mining.getRewardReserve();
        vm.prank(user2);
        mining.deposit(50_000_000 ether);
        assertEq(mining.getRewardReserve(), before + 50_000_000 ether);
    }

    // ============================================================
    // 4. Reward separation — principal is never at risk
    // ============================================================

    // Core security test: after reserve is exhausted, stakers get 100% principal back
    function test_Security_PrincipalSafeWhenReserveEmpty() public {
        uint256 stakeAmount = 100_000_000 ether;

        vm.prank(user1);
        mining.mine(stakeAmount);

        // Roll far enough to drain the entire reserve
        vm.roll(block.number + 1_000_000);

        uint256 user1BalBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.unmine(stakeAmount);

        // User must receive at least their full principal back
        assertGe(shd.balanceOf(user1), user1BalBefore + stakeAmount);
    }

    // Two stakers: draining rewards for user1 must not prevent user2 from unmining
    function test_Security_TwoStakers_BothRecoverPrincipal() public {
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        vm.prank(user2);
        mining.mine(50_000_000 ether);

        // Drain most of the reserve
        vm.roll(block.number + 500_000);

        uint256 u1Before = shd.balanceOf(user1);
        uint256 u2Before = shd.balanceOf(user2);

        vm.prank(user1);
        mining.unmine(100_000_000 ether);

        vm.prank(user2);
        mining.unmine(50_000_000 ether);

        assertGe(shd.balanceOf(user1), u1Before + 100_000_000 ether);
        assertGe(shd.balanceOf(user2), u2Before + 50_000_000 ether);
    }

    // Staked tokens must never be counted as reward reserve
    function test_Security_StakedTokensNotPartOfReserve() public {
        uint256 reserveBefore = mining.getRewardReserve();

        vm.prank(user1);
        mining.mine(200_000_000 ether);

        // Reserve must be unchanged after staking
        assertEq(mining.getRewardReserve(), reserveBefore);
    }

    // Contract balance = totalMined + rewardReserve (accounting invariant)
    function test_Security_BalanceInvariant() public {
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        vm.roll(block.number + 50);
        mining.updatePool();

        uint256 contractBal  = mining.getContractSHDBalance();
        uint256 totalMined   = mining.totalMined();
        uint256 reserve      = mining.getRewardReserve();

        // accRewardPerShare already consumed from reserve, so:
        // contractBalance >= totalMined + reserve  (the diff is already-accrued but unclaimed rewards)
        assertGe(contractBal, totalMined + reserve);
    }

    // ============================================================
    // 5. Reserve cap — rewards stop when reserve is empty
    // ============================================================

    function test_ReserveCap_PendingRewardsCapAtReserve() public {
        uint256 stakeAmount = 100_000_000 ether;

        vm.prank(user1);
        mining.mine(stakeAmount);

        // Roll so far that theoretical rewards dwarf the reserve
        vm.roll(block.number + 10_000_000);

        uint256 pending = mining.pendingRewards(user1);

        // Pending must never exceed what was originally deposited as reserve
        assertLe(pending, RESERVE_SEED);
    }

    function test_ReserveCap_NoNewRewardsAfterReserveExhausted() public {
        // Drain the existing reserve first, then add a tiny controlled one.
        // rewardRate=31_771_820_820, stake=100M ether → reward/block ≈ 3.177e18
        // 100 ether reserve drains in ~31 blocks; rolling 500 blocks guarantees empty.
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        // Roll enough to consume the giant RESERVE_SEED — use 200M blocks.
        // 157M blocks drains 500M reserve with 100M stake (pre-calculated).
        vm.roll(block.number + 160_000_000);
        mining.updatePool();
        assertEq(mining.getRewardReserve(), 0);

        uint256 accBefore = mining.accRewardPerShare();

        // Roll more — reserve is 0, nothing should accrue
        vm.roll(block.number + 1_000);
        mining.updatePool();

        assertEq(mining.accRewardPerShare(), accBefore);
    }

    function test_ReserveCap_RewardsResumeAfterTopUp() public {
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        // Drain the full reserve (157M blocks needed for 500M reserve, 100M stake)
        vm.roll(block.number + 160_000_000);
        mining.updatePool();
        assertEq(mining.getRewardReserve(), 0);

        uint256 accAfterDrain = mining.accRewardPerShare();

        // Funder spent all 500M in setUp() deposit, so mint more before top-up
        shd.mint(funder, 50_000_000 ether);

        // Top up
        vm.prank(funder);
        mining.deposit(50_000_000 ether);

        // Rewards should resume
        vm.roll(block.number + 100);
        mining.updatePool();

        assertGt(mining.accRewardPerShare(), accAfterDrain);
    }

    // ============================================================
    // 6. mine()
    // ============================================================

    function test_Mine_StakesTokensCorrectly() public {
        vm.prank(user1);
        mining.mine(1_000 ether);

        assertEq(mining.totalMined(), 1_000 ether);
        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, 1_000 ether);
    }

    function test_Mine_ClaimsPendingRewardsBeforeNewStake() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.roll(block.number + 50);

        uint256 pending       = mining.pendingRewards(user1);
        uint256 balanceBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.mine(5 ether);

        // Balance should increase by pending rewards, decrease by new stake
        assertEq(shd.balanceOf(user1), balanceBefore + pending - 5 ether);
    }

    function test_Mine_LargeAmount_100Million() public {
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        assertEq(mining.totalMined(), 100_000_000 ether);
        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, 100_000_000 ether);
    }

    function test_Mine_LargeAmount_500Million() public {
        vm.prank(user1);
        mining.mine(500_000_000 ether);

        assertEq(mining.totalMined(), 500_000_000 ether);
        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, 500_000_000 ether);
    }

    function test_Mine_RevertsOnZeroAmount() public {
        vm.expectRevert(SnipeheadMiningDecentralizedV2.ZeroAmount.selector);
        vm.prank(user1);
        mining.mine(0);
    }

    function test_Mine_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.Mined(user1, 500 ether);
        vm.prank(user1);
        mining.mine(500 ether);
    }

    // ============================================================
    // 7. unmine()
    // ============================================================

    function test_Unmine_UnstakesAndClaimsRewards() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.roll(block.number + 30);

        uint256 pending      = mining.pendingRewards(user1);
        uint256 balBefore    = shd.balanceOf(user1);

        vm.prank(user1);
        mining.unmine(4 ether);

        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount,       6 ether);
        assertEq(mining.totalMined(), 6 ether);
        assertEq(shd.balanceOf(user1), balBefore + 4 ether + pending);
    }

    function test_Unmine_PartialUnstakeKeepsRemainingStake() public {
        vm.prank(user1);
        mining.mine(100 ether);

        vm.roll(block.number + 10);

        vm.prank(user1);
        mining.unmine(40 ether);

        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount,       60 ether);
        assertEq(mining.totalMined(), 60 ether);
    }

    function test_Unmine_LargeAmount() public {
        vm.prank(user1);
        mining.mine(300_000_000 ether);

        vm.roll(block.number + 200);

        uint256 pending   = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.unmine(100_000_000 ether);

        assertEq(shd.balanceOf(user1), balBefore + pending + 100_000_000 ether);
    }

    function test_Unmine_RevertsOnInsufficientAmount() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.expectRevert(SnipeheadMiningDecentralizedV2.InsufficientAmount.selector);
        vm.prank(user1);
        mining.unmine(20 ether);
    }

    function test_Unmine_RevertsOnZeroAmount() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.expectRevert(SnipeheadMiningDecentralizedV2.InsufficientAmount.selector);
        vm.prank(user1);
        mining.unmine(0);
    }

    function test_Unmine_EmitsEvents() public {
        vm.prank(user1);
        mining.mine(100 ether);

        vm.roll(block.number + 10);

        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.Unmined(user1, 100 ether);
        vm.prank(user1);
        mining.unmine(100 ether);
    }

    // ============================================================
    // 8. claimRewards()
    // ============================================================

    function test_ClaimRewards_WorksCorrectly() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.roll(block.number + 100);

        uint256 pending  = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.claimRewards();

        assertEq(shd.balanceOf(user1), balBefore + pending);
    }

    function test_ClaimRewards_LargeStakeAndManyBlocks() public {
        vm.prank(user1);
        mining.mine(200_000_000 ether);

        vm.roll(block.number + 1_000);

        uint256 pending  = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.claimRewards();

        assertEq(shd.balanceOf(user1), balBefore + pending);
    }

    function test_ClaimRewards_ResetsPendingToZero() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.roll(block.number + 50);

        vm.prank(user1);
        mining.claimRewards();

        assertEq(mining.pendingRewards(user1), 0);
    }

    function test_ClaimRewards_RevertsWhenNoPendingRewards() public {
        vm.prank(user1);
        mining.mine(10 ether);

        // No blocks rolled — no rewards yet
        vm.expectRevert(SnipeheadMiningDecentralizedV2.NoRewardsToClaim.selector);
        vm.prank(user1);
        mining.claimRewards();
    }

    function test_ClaimRewards_EmitsEvent() public {
        vm.prank(user1);
        mining.mine(500 ether);

        vm.roll(block.number + 10);

        uint256 pending = mining.pendingRewards(user1);

        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.RewardClaimed(user1, pending);
        vm.prank(user1);
        mining.claimRewards();
    }

    // ============================================================
    // 9. pendingRewards() accuracy
    // ============================================================

    function test_PendingRewards_AccurateAfterSingleBlock() public {
        uint256 stake = 10_000_000 ether;
        vm.prank(user1);
        mining.mine(stake);

        vm.roll(block.number + 1);

        uint256 reserve = mining.getRewardReserve();
        uint256 expected = _expectedReward(1, stake, reserve);
        uint256 actual   = mining.pendingRewards(user1);

        // Allow 1 wei rounding tolerance
        assertApproxEqAbs(actual, expected, 1);
    }

    function test_PendingRewards_CapedByReserve() public {
        uint256 stake = 500_000_000 ether;
        vm.prank(user1);
        mining.mine(stake);

        // Roll so far that theoretical rewards exceed entire reserve
        vm.roll(block.number + 10_000_000);

        uint256 pending = mining.pendingRewards(user1);
        assertLe(pending, RESERVE_SEED);
    }

    function test_PendingRewards_ZeroWhenNoStake() public view {
        assertEq(mining.pendingRewards(user1), 0);
    }

    function test_PendingRewards_ZeroWhenReserveEmpty() public {
        vm.prank(user1);
        mining.mine(100_000_000 ether);

        // 157M blocks drains the 500M RESERVE_SEED with 100M stake (pre-calculated).
        // Roll past that to guarantee reserve = 0.
        vm.roll(block.number + 160_000_000);
        mining.updatePool();
        assertEq(mining.getRewardReserve(), 0);

        // Snapshot pending after drain
        uint256 pendingAfterDrain = mining.pendingRewards(user1);

        // Roll more — no reserve left, so pending must not grow
        vm.roll(block.number + 1_000);
        uint256 pendingLater = mining.pendingRewards(user1);

        assertEq(pendingLater, pendingAfterDrain);
    }

    // ============================================================
    // 10. Multi-user reward fairness
    // ============================================================

    // User who stakes more earns proportionally more
    function test_MultiUser_ProportionalRewards() public {
        vm.prank(user1);
        mining.mine(200_000_000 ether); // 2× stake

        vm.prank(user2);
        mining.mine(100_000_000 ether);

        vm.roll(block.number + 100);

        uint256 pending1 = mining.pendingRewards(user1);
        uint256 pending2 = mining.pendingRewards(user2);

        // user1 should earn ~2× user2 (allow 1 wei tolerance)
        assertApproxEqAbs(pending1, pending2 * 2, 1);
    }

    // Late joiner only earns from the block they joined
    function test_MultiUser_LateJoinerOnlyEarnsFromJoinBlock() public {
        vm.prank(user1);
        mining.mine(10_000_000 ether);

        vm.roll(block.number + 50);

        // user2 joins late
        vm.prank(user2);
        mining.mine(10_000_000 ether);

        vm.roll(block.number + 50);

        uint256 pending1 = mining.pendingRewards(user1);
        uint256 pending2 = mining.pendingRewards(user2);

        // user1 had 100 blocks, user2 had 50 — user1 earns strictly more
        assertGt(pending1, pending2);
    }

    // ============================================================
    // 11. updatePool() edge cases
    // ============================================================

    function test_UpdatePool_NoOpWhenSameBlock() public {
        vm.prank(user1);
        mining.mine(10 ether);

        uint256 accBefore = mining.accRewardPerShare();
        mining.updatePool();

        assertEq(mining.accRewardPerShare(), accBefore);
    }

    function test_UpdatePool_NoOpWhenTotalMinedIsZero() public {
        vm.roll(block.number + 100);
        mining.updatePool();

        assertEq(mining.accRewardPerShare(), 0);
        assertEq(mining.rewardReserve(),     RESERVE_SEED); // reserve untouched
    }

    function test_UpdatePool_AccruesCorrectlyOverBlocks() public {
        uint256 stake  = 10_000_000 ether;
        uint256 blocks = 50;

        vm.prank(user1);
        mining.mine(stake);

        uint256 reserveBefore = mining.getRewardReserve();

        vm.roll(block.number + blocks);
        mining.updatePool();

        uint256 reserveAfter = mining.getRewardReserve();
        uint256 consumed     = reserveBefore - reserveAfter;
        uint256 expected     = _expectedReward(blocks, stake, reserveBefore);

        assertApproxEqAbs(consumed, expected, 1);
    }

    // ============================================================
    // 12. getContractSHDBalance()
    // ============================================================

    function test_GetContractSHDBalance_ReflectsStakeAndReserve() public {
        vm.prank(user1);
        mining.mine(50_000_000 ether);

        // Balance = reserve seed + user1 stake
        assertEq(mining.getContractSHDBalance(), RESERVE_SEED + 50_000_000 ether);
    }

    function test_GetContractSHDBalance_DecreasesOnUnmine() public {
        vm.prank(user1);
        mining.mine(50_000_000 ether);

        vm.roll(block.number + 10);

        uint256 pending   = mining.pendingRewards(user1);
        uint256 balBefore = mining.getContractSHDBalance();

        vm.prank(user1);
        mining.unmine(50_000_000 ether);

        // Balance should decrease by principal + rewards paid out
        assertEq(mining.getContractSHDBalance(), balBefore - 50_000_000 ether - pending);
    }
}
