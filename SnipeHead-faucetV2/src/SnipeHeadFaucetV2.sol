// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SnipeHeadFaucetV2 is ReentrancyGuard {
    // Hardcoded immutable token address for maximum security
    IERC20 public immutable shdToken;
    address public constant SHD_TOKEN_ADDRESS = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;

    uint256 public constant TOKENS_PER_CLAIM = 1 * 10**18;     // Exactly 1 SHD per address — ever
    uint256 public constant DAILY_TOKEN_LIMIT = 1000 * 10**18; // Max 1000 SHD dispensed per 24h

    uint256 public dailyTokensDispensed;
    uint256 public lastResetTime;

    mapping(address => bool) public hasClaimed;

    event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);

    constructor() {
        shdToken = IERC20(SHD_TOKEN_ADDRESS);
        lastResetTime = block.timestamp;
    }

    function claimTokens() external nonReentrant {
        // Reset daily counter if 24 hours have passed
        if (block.timestamp >= lastResetTime + 24 hours) {
            dailyTokensDispensed = 0;
            lastResetTime = block.timestamp;
        }

        require(dailyTokensDispensed + TOKENS_PER_CLAIM <= DAILY_TOKEN_LIMIT, "Daily token limit reached");
        require(!hasClaimed[msg.sender], "You have already claimed your 1 SHD (one per address ever)");
        require(shdToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM, "Faucet is empty");

        // Checks → Effects → Interactions
        hasClaimed[msg.sender] = true;
        dailyTokensDispensed += TOKENS_PER_CLAIM;

        // Transfer last
        require(shdToken.transfer(msg.sender, TOKENS_PER_CLAIM), "Token transfer failed");

        emit TokensClaimed(msg.sender, TOKENS_PER_CLAIM, block.timestamp);
    }

    // === View functions ===
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