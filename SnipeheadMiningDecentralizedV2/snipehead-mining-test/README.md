# SNIPEHEAD_MINING_TEST

Comprehensive Foundry test suite for the **SnipeheadMiningDecentralizedV2** smart contract.

This repository contains a full set of unit tests, large-scale tests to ensure the mining contract works correctly with both small and very large token amounts (matching the real 1 billion SHD token supply).

## 📋 Overview

- **Contract Tested**: `SnipeheadMiningDecentralizedV2.sol`
- **Framework**: Foundry (Forge)
- **Token**: Mock SHD token etched to the exact hardcoded address used in the contract (`0xB95bC84f9B6D0373642D586b81979B067572f7bc`)
- **Test Coverage**: Constructor, staking, unstaking, reward claiming, pool funding, events, reverts, and high-value scenarios

## 🧪 Test Categories

### Core / Small Amount Tests
- Constructor initialization
- Basic staking (`mine`)
- Reward claiming before additional staking
- Unstaking with pending rewards
- Revert cases (zero amount, insufficient balance, no rewards)

### Large Amount Tests (Realistic for 1B supply)
- Staking 100 million and 500 million SHD
- Reward accumulation with large stakes over many blocks
- Unstaking large amounts

### Helper Tests
- Anyone can fund the reward pool (`deposit`)
- Event emission verification
- Contract balance checks

### SnipeHead

