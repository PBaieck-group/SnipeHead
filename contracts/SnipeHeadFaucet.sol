// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SnipeHeadFaucet is ReentrancyGuard {
    address public owner;
    IERC20 public shdToken;
    uint256 public constant TOKENS_PER_CLAIM = 5000 * 10**18; // 5000 SHD tokens
    uint256 public constant COOLDOWN_PERIOD = 24 hours; // 24-hour cooldown
    uint256 public constant DAILY_TOKEN_LIMIT = 250000 * 10**18; // 250,000 SHD per day
    uint256 public dailyTokensDispensed;
    uint256 public lastResetTime;
    mapping(address => uint256) public lastClaimTime;

    event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event TokensDeposited(address indexed sender, uint256 amount, uint256 timestamp);
    event TokensWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _shdTokenAddress) {
        owner = msg.sender;
        shdToken = IERC20(_shdTokenAddress);
        lastResetTime = block.timestamp;
    }

    function claimTokens() external nonReentrant {
        if (block.timestamp >= lastResetTime + 24 hours) {
            dailyTokensDispensed = 0;
            lastResetTime = block.timestamp;
        }
        require(dailyTokensDispensed + TOKENS_PER_CLAIM <= DAILY_TOKEN_LIMIT, "Daily token limit reached");
        require(
            lastClaimTime[msg.sender] == 0 || block.timestamp >= lastClaimTime[msg.sender] + COOLDOWN_PERIOD,
            "Cooldown period not elapsed"
        );
        require(shdToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM, "Faucet has insufficient tokens");

        lastClaimTime[msg.sender] = block.timestamp;
        dailyTokensDispensed += TOKENS_PER_CLAIM;
        require(shdToken.transfer(msg.sender, TOKENS_PER_CLAIM), "Token transfer failed");

        emit TokensClaimed(msg.sender, TOKENS_PER_CLAIM, block.timestamp);
    }

    function depositTokens(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(shdToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit TokensDeposited(msg.sender, amount, block.timestamp);
    }

    function withdrawTokens(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(shdToken.balanceOf(address(this)) >= amount, "Insufficient tokens in faucet");
        require(shdToken.transfer(msg.sender, amount), "Token transfer failed");

        emit TokensWithdrawn(msg.sender, amount, block.timestamp);
    }

    function getFaucetBalance() external view returns (uint256) {
        return shdToken.balanceOf(address(this));
    }

    function getLastClaimTime(address user) external view returns (uint256) {
        return lastClaimTime[user];
    }

    function getDailyTokensRemaining() external view returns (uint256) {
        if (block.timestamp >= lastResetTime + 24 hours) {
            return DAILY_TOKEN_LIMIT;
        }
        return DAILY_TOKEN_LIMIT > dailyTokensDispensed ? DAILY_TOKEN_LIMIT - dailyTokensDispensed : 0;
    }
}