// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SnipeheadMiningDecentralized is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Snipehead token (SHD)
    IERC20 public immutable shdToken;

    // Mining information for each user
    struct UserInfo {
        uint256 minedAmount; // Amount of SHD tokens mined
        uint256 rewardDebt; // Reward debt to prevent double claiming
    }

    // Reward rate: 31771820820 (0.000000031771820820 SHD/block/SHD)
    uint256 public immutable rewardRate = 31771820820; // Fixed, no updates 
    uint256 public lastRewardBlock; // Last block number when rewards were updated
    uint256 public accRewardPerShare; // Accumulated rewards per share, scaled by 1e18

    // Mapping of user address to their mining info
    mapping(address => UserInfo) public userInfo;

    // Total SHD tokens mined in the contract
    uint256 public totalMined;

    // Events
    event Mined(address indexed user, uint256 amount);
    event Unmined(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(address _shdToken) {
        require(_shdToken != address(0), "Invalid token address");
        shdToken = IERC20(_shdToken);
        lastRewardBlock = block.number;
    }

    // Update reward variables for all users
    function updatePool() public {
        if (block.number <= lastRewardBlock || totalMined == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = (blocks * rewardRate * totalMined) / 1e18;
        accRewardPerShare = accRewardPerShare + (reward * 1e18) / totalMined;
        lastRewardBlock = block.number;
    }

    // Get pending rewards for a user
    function pendingRewards(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShareTemp = accRewardPerShare;

        if (block.number > lastRewardBlock && totalMined != 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = (blocks * rewardRate * totalMined) / 1e18;
            accRewardPerShareTemp = accRewardPerShareTemp + (reward * 1e18) / totalMined;
        }

        return (user.minedAmount * accRewardPerShareTemp) / 1e18 - user.rewardDebt;
    }

    // Mine SHD tokens with permit
    function mine(uint256 _amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
        require(_amount > 0, "Cannot mine 0");

        // Permit: Allow the contract to spend user's SHD tokens without a prior approval
        IERC20Permit(address(shdToken)).permit(msg.sender, address(this), _amount, deadline, v, r, s);

        updatePool();

        UserInfo storage user = userInfo[msg.sender];

        // If user has mined before, claim their pending rewards
        if (user.minedAmount > 0) {
            uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
            if (pending > 0) {
                safeSHDTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }

        // Transfer SHD tokens from user to contract
        shdToken.safeTransferFrom(msg.sender, address(this), _amount);

        user.minedAmount = user.minedAmount + _amount;
        totalMined = totalMined + _amount;
        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;

        emit Mined(msg.sender, _amount);
    }

    // Unmine SHD tokens
    function unmine(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.minedAmount >= _amount, "Insufficient mined amount");
        require(_amount > 0, "Cannot unmine 0");
        updatePool();

        // Calculate and distribute pending rewards
        uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) {
            safeSHDTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }

        user.minedAmount = user.minedAmount - _amount;
        totalMined = totalMined - _amount;
        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;

        // Transfer mined SHD tokens back to user
        shdToken.safeTransfer(msg.sender, _amount);

        emit Unmined(msg.sender, _amount);
    }

    // Claim pending rewards without unmining
    function claimRewards() external nonReentrant {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        require(pending > 0, "No rewards to claim");

        user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;
        safeSHDTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }

    // Get the contract's current balance of SHD tokens
    function getContractSHDBalance() public view returns (uint256) {
        return shdToken.balanceOf(address(this)); // This works since IERC20Permit extends IERC20
    }

    // Safe SHD transfer to handle cases where contract balance is insufficient
    function safeSHDTransfer(address _to, uint256 _amount) private {
        uint256 shdBal = shdToken.balanceOf(address(this));
        uint256 transferAmount = _amount > shdBal ? shdBal : _amount;
        require(transferAmount > 0, "Insufficient balance");
        shdToken.safeTransfer(_to, transferAmount);
    }
}