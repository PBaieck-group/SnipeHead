// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SnipeheadMiningDecentralizedV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    
    IERC20 public immutable shdToken = IERC20(0xB95bC84f9B6D0373642D586b81979B067572f7bc);

    struct UserInfo {
        uint256 minedAmount;   // Amount of SHD currently staked by user
        uint256 rewardDebt;    // Used to calculate pending rewards correctly
    }

   
    uint256 public immutable rewardRate = 31771820820; // Fixed forever

    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare; // Accumulated rewards per share (scaled by 1e18)

    mapping(address => UserInfo) public userInfo;
    uint256 public totalMined;

    // Events
    event Deposited(address indexed from, uint256 amount);
    event Mined(address indexed user, uint256 amount);
    event Unmined(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor() {
        require(address(shdToken) != address(0), "Invalid token address");
        lastRewardBlock = block.number;
    }

    // Update global reward variables
    function updatePool() public {
        if (block.number <= lastRewardBlock || totalMined == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = (blocks * rewardRate * totalMined) / 1e18;
        accRewardPerShare += (reward * 1e18) / totalMined;
        lastRewardBlock = block.number;
    }

    // View pending rewards for a user
    function pendingRewards(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 acc = accRewardPerShare;

        if (block.number > lastRewardBlock && totalMined != 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = (blocks * rewardRate * totalMined) / 1e18;
            acc += (reward * 1e18) / totalMined;
        }

        return (user.minedAmount * acc) / 1e18 - user.rewardDebt;
    }

    // ==================== ANYONE CAN FUND THE POOL ====================
    // Public function so anyone can send SHD to support development and rewards
    function deposit(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();

        uint256 balanceBefore = shdToken.balanceOf(address(this));
        shdToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 actualReceived = shdToken.balanceOf(address(this)) - balanceBefore;

        if (actualReceived == 0) revert NoTokensReceived();

        emit Deposited(msg.sender, actualReceived);
    }

    // Mine SHD tokens (requires approve first)
    function mine(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();

        updatePool();

        UserInfo storage user = userInfo[msg.sender];

        // Claim any pending rewards before adding more stake
        if (user.minedAmount > 0) {
            uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
            if (pending > 0) {
                safeSHDTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }

        uint256 balanceBefore = shdToken.balanceOf(address(this));
        shdToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 actualReceived = shdToken.balanceOf(address(this)) - balanceBefore;

        if (actualReceived == 0) revert NoTokensReceived();

        user.minedAmount += actualReceived;
        totalMined += actualReceived;
        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;

        emit Mined(msg.sender, actualReceived);
    }

    // Unmine SHD tokens
    function unmine(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        if (_amount == 0 || user.minedAmount < _amount) revert InsufficientAmount();

        updatePool();

        // Claim pending rewards before unstaking
        uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) {
            safeSHDTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }

        user.minedAmount -= _amount;
        totalMined -= _amount;
        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;

        shdToken.safeTransfer(msg.sender, _amount);

        emit Unmined(msg.sender, _amount);
    }

    // Claim rewards without unstaking
    function claimRewards() external nonReentrant {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];

        uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending == 0) revert NoRewardsToClaim();

        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;
        safeSHDTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }

    // View contract SHD balance
    function getContractSHDBalance() public view returns (uint256) {
        return shdToken.balanceOf(address(this));
    }

    // Internal safe transfer (never sends more than available)
    function safeSHDTransfer(address _to, uint256 _amount) private {
        uint256 bal = shdToken.balanceOf(address(this));
        uint256 transferAmount = _amount > bal ? bal : _amount;
        if (transferAmount == 0) revert InsufficientBalance();

        shdToken.safeTransfer(_to, transferAmount);
    }

    // Custom errors (cheaper gas than require strings)
    error ZeroAmount();
    error InsufficientAmount();
    error NoTokensReceived();
    error NoRewardsToClaim();
    error InsufficientBalance();
}
