// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SnipeheadMiningDecentralizedV2.sol";

// Mock ERC20 placed at the exact hardcoded address
contract MockSHD is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    uint256 public totalSupply;

    string public constant name = "SnipeHead";
    string public constant symbol = "SHD";
    uint8 public constant decimals = 18;

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[msg.sender] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked { allowance[from][msg.sender] -= value; }
        }
        require(balanceOf[from] >= value, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
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
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract SnipeheadMiningDecentralizedV2Test is Test {
    address public constant HARDCODED_SHD = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;

    SnipeheadMiningDecentralizedV2 public mining;
    MockSHD public shd;

    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant REWARD_RATE = 31_771_820_820;

    function setUp() public {
        bytes memory mockCode = vm.getDeployedCode("SnipeheadMiningDecentralizedV2.t.sol:MockSHD");
        vm.etch(HARDCODED_SHD, mockCode);

        shd = MockSHD(HARDCODED_SHD);

        // Realistic supply matching the real SnipeHead token (1 billion)
        shd.mint(owner, 1_000_000_000 ether);
        shd.mint(user1, 600_000_000 ether);
        shd.mint(user2, 100_000_000 ether);

        mining = new SnipeheadMiningDecentralizedV2();

        vm.prank(user1);
        shd.approve(address(mining), type(uint256).max);
        vm.prank(user2);
        shd.approve(address(mining), type(uint256).max);
    }

    // ================================================================
    // Core / Small Amount Tests
    // ================================================================
    function test_Constructor_SetsCorrectValues() public view {
        assertEq(address(mining.shdToken()), HARDCODED_SHD);
        assertEq(mining.lastRewardBlock(), block.number);
        assertEq(mining.accRewardPerShare(), 0);
        assertEq(mining.totalMined(), 0);
        assertEq(mining.getContractSHDBalance(), 0);
    }

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

        uint256 pending = mining.pendingRewards(user1);
        uint256 balanceBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.mine(5 ether);

        assertEq(shd.balanceOf(user1), balanceBefore + pending - 5 ether);
    }

    function test_ClaimRewards_WorksCorrectly() public {
        vm.prank(user1);
        mining.mine(10 ether);
        vm.roll(block.number + 100);

        uint256 pending = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.claimRewards();

        assertEq(shd.balanceOf(user1), balBefore + pending);
    }

    function test_Unmine_UnstakesAndClaimsRewards() public {
        vm.prank(user1);
        mining.mine(10 ether);
        vm.roll(block.number + 30);

        uint256 pending = mining.pendingRewards(user1);
        uint256 userBalBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.unmine(4 ether);

        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, 6 ether);
        assertEq(mining.totalMined(), 6 ether);
        assertEq(shd.balanceOf(user1), userBalBefore + 4 ether + pending);
    }

    // ================================================================
    // Large Amount Tests (Realistic for 1B token)
    // ================================================================
    function test_Mine_LargeAmount_100Million() public {
        uint256 amount = 100_000_000 ether;
        vm.prank(user1);
        mining.mine(amount);

        assertEq(mining.totalMined(), amount);
        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, amount);
    }

    function test_Mine_LargeAmount_500Million() public {
        uint256 amount = 500_000_000 ether;
        vm.prank(user1);
        mining.mine(amount);

        assertEq(mining.totalMined(), amount);
        (uint256 minedAmount, ) = mining.userInfo(user1);
        assertEq(minedAmount, amount);
    }

    function test_Rewards_WithLargeStakeAndManyBlocks() public {
        vm.prank(user1);
        mining.mine(200_000_000 ether);

        vm.roll(block.number + 1_000);

        uint256 pending = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.claimRewards();

        assertEq(shd.balanceOf(user1), balBefore + pending);
    }

    function test_Unmine_LargeAmount() public {
        vm.prank(user1);
        mining.mine(300_000_000 ether);
        vm.roll(block.number + 200);

        uint256 pending = mining.pendingRewards(user1);
        uint256 balBefore = shd.balanceOf(user1);

        vm.prank(user1);
        mining.unmine(100_000_000 ether);

        assertEq(shd.balanceOf(user1), balBefore + pending + 100_000_000 ether);
    }

    // ================================================================
    // Revert & Helper Tests
    // ================================================================
    function test_Mine_RevertsOnZeroAmount() public {
        vm.expectRevert(SnipeheadMiningDecentralizedV2.ZeroAmount.selector);
        vm.prank(user1);
        mining.mine(0);
    }

    function test_Unmine_RevertsOnInsufficientAmount() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.expectRevert(SnipeheadMiningDecentralizedV2.InsufficientAmount.selector);
        vm.prank(user1);
        mining.unmine(20 ether);
    }

    function test_ClaimRewards_RevertsWhenNoRewards() public {
        vm.prank(user1);
        mining.mine(10 ether);

        vm.expectRevert(SnipeheadMiningDecentralizedV2.NoRewardsToClaim.selector);
        vm.prank(user1);
        mining.claimRewards();
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.expectRevert(SnipeheadMiningDecentralizedV2.ZeroAmount.selector);
        mining.deposit(0);
    }

    function test_Deposit_AllowsAnyoneToFund() public {
        vm.prank(user2);
        mining.deposit(10_000_000 ether);
        assertGt(mining.getContractSHDBalance(), 0);
    }

    function test_GetContractSHDBalance_ReturnsCorrectValue() public {
        shd.mint(address(mining), 42_000 ether);
        assertEq(mining.getContractSHDBalance(), 42_000 ether);
    }

    function test_Events_EmittedCorrectly() public {
        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.Deposited(user2, 1000 ether);
        vm.prank(user2);
        mining.deposit(1000 ether);

        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.Mined(user1, 500 ether);
        vm.prank(user1);
        mining.mine(500 ether);

        vm.roll(block.number + 10);

        vm.expectEmit(true, false, false, true);
        emit SnipeheadMiningDecentralizedV2.RewardClaimed(user1, mining.pendingRewards(user1));
        vm.prank(user1);
        mining.claimRewards();
    }
}