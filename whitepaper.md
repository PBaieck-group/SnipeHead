# Snipehead (SHD) Whitepaper

## Overview

Snipehead (SHD) is a fungible ERC-20 token deployed on the PulseChain blockchain, designed to leverage its decentralized infrastructure and prioritize user privacy. With a fixed supply of 21 billion SHD, the token integrates advanced features like EIP-2612 permit support for gasless approvals, fostering a seamless and efficient ecosystem. This whitepaper outlines SHD's technical foundation, its alignment with PulseChain's decentralized ethos, and the supporting dApps—faucet, mining contract, and airdrop checker—that drive its community-driven distribution.

## 1. PulseChain: A Decentralized Foundation

PulseChain is a layer-1 blockchain forked from Ethereum, optimized for scalability, privacy, and decentralization through a proof-of-stake (PoS) consensus mechanism. Unlike energy-intensive proof-of-work systems, PulseChain's PoS model allows validators to stake PLS (its native token) to secure the network, reducing centralization risks and promoting broad participation. Key decentralized features include:

- **Validator Distribution**: The network encourages a diverse set of validators, with staking accessible to individuals rather than large mining pools, though ongoing efforts monitor stake concentration to maintain fairness.
- **No Central Authority**: PulseChain operates without a central mint or corporate oversight, enabling borderless, censorship-resistant transactions. Smart contracts execute autonomously, free from external interference.
- **Fair Launch Model**: The "sacrifice phase" distributed PLS to users who donated assets, avoiding pre-mines or venture capital dominance, a principle extended to projects like SHD.
- **EVM Compatibility**: As an Ethereum Virtual Machine (EVM)-compatible chain, PulseChain supports decentralized tools (e.g., MetaMask) while offering lower fees and higher throughput, empowering developers and users alike.

This decentralized backbone ensures SHD transactions are secure, private, and resilient, aligning with PulseChain's mission to "empower individuals to transact and communicate without central control."

## 2. Snipehead (SHD) Token

SHD is an ERC-20 token built with OpenZeppelin Contracts v5, ensuring security and compliance. Its key specifications are:

- **Name**: SnipeHead
- **Symbol**: SHD
- **Decimals**: 18
- **Total Supply**: 21,000,000,000 SHD (pre-minted to a recipient upon deployment)

The contract (`SnipeHead.sol`) includes:

```solidity
contract SnipeHead is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("SnipeHead", "SHD")
        ERC20Permit("SnipeHead")
    {
        _mint(recipient, 21000000000 * 10 ** decimals());
    }
}
```

- **EIP-2612 Permit Support**: Enables off-chain signature-based approvals, reducing gas costs and enhancing privacy by allowing gasless transactions.
- **Fixed Supply**: No additional minting occurs post-deployment, ensuring a predictable economic model.

SHD leverages PulseChain's low-cost, high-speed transactions to facilitate micro-payments and dApp integrations, fostering a vibrant ecosystem.

## 3. Snipehead Ecosystem dApps

The Snipehead ecosystem includes three decentralized applications (dApps) hosted on IPFS for permanence and accessibility. These tools mirror early cryptocurrency distribution models, promoting adoption and engagement.

### 3.1 Snipehead Faucet

The `SnipeHeadFaucet.sol` contract allows users to claim free SHD tokens, reminiscent of Bitcoin's early faucet experiments. Key features:

- **Claim Limit**: 5,000 SHD per claim (5000 * 10^18 wei).
- **Cooldown Period**: 24 hours between claims.
- **Daily Cap**: 250,000 SHD total per day.

```solidity
function claimTokens() external nonReentrant {
    require(dailyTokensDispensed + TOKENS_PER_CLAIM <= DAILY_TOKEN_LIMIT, "Daily token limit reached");
    require(lastClaimTime[msg.sender] + COOLDOWN_PERIOD <= block.timestamp, "Cooldown period not elapsed");
    require(shdToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM, "Faucet has insufficient tokens");

    lastClaimTime[msg.sender] = block.timestamp;
    dailyTokensDispensed += TOKENS_PER_CLAIM;
    require(shdToken.transfer(msg.sender, TOKENS_PER_CLAIM), "Token transfer failed");

    emit TokensClaimed(msg.sender, TOKENS_PER_CLAIM, block.timestamp);
}
```

The faucet is accessible via an IPFS-hosted interface, enabling users to request tokens and support initial experimentation with SHD.

### 3.2 Snipehead Mining Contract

The `SnipeheadMiningDecentralized.sol` contract enables users to mine SHD tokens, introducing a reward-based participation model. Features include:

- **Reward Rate**: 0.000000031771820820 SHD per block per staked SHD (rewardRate = 31771820820).
- **Permit Integration**: Users can mine with EIP-2612 permits, transferring SHD to the contract without prior approval.
- **Reward Calculation**: Accumulated rewards per share (accRewardPerShare) scale with staked amounts.

```solidity
function mine(uint256 _amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
    IERC20Permit(address(shdToken)).permit(msg.sender, address(this), _amount, deadline, v, r, s);
    updatePool();
    UserInfo storage user = userInfo[msg.sender];
    if (user.minedAmount > 0) {
        uint256 pending = (user.minedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) safeSHDTransfer(msg.sender, pending);
    }
    shdToken.safeTransferFrom(msg.sender, address(this), _amount);
    user.minedAmount += _amount;
    totalMined += _amount;
    user.rewardDebt = (user.minedAmount * accRewardPerShare) / 1e18;
    emit Mined(msg.sender, _amount);
}
```

This dApp, also hosted on IPFS, encourages long-term engagement by rewarding stakers, reinforcing PulseChain's decentralized staking culture.

### 3.3 Airdrop Checker

The airdrop checker dApp verifies if users received free SHD tokens distributed to random HEX users. It queries a mapping of eligible addresses.

- **Purpose**: Confirms airdrop eligibility, enhancing transparency.
- **Integration**: Links to PulseChain's decentralized storage via IPFS.
- **User Experience**: Provides a simple interface for users to check their status.

This initiative rewards early HEX community members, aligning with PulseChain's fair distribution ethos.

## 4. Technical Stack

- **Contract Framework**: OpenZeppelin Contracts v5 (ERC20, ERC20Permit, SafeERC20, ReentrancyGuard).
- **Blockchain**: PulseChain (Mainnet Chain ID: 369, Testnet Chain ID: 943).
- **Language**: Solidity ^0.8.20.
- **Testing**: Node.js `node:test`, `viem`, Hardhat.
- **Storage**: IPFS for dApp hosting.

## 5. Ecosystem Vision

The Snipehead ecosystem aims to empower users through decentralization and privacy, leveraging PulseChain's strengths. Future plans include:
- Expanding dApps with DeFi integrations (e.g., staking pools, DEX listings).
- Enhancing privacy features with zero-knowledge proofs.
- Growing the community via governance proposals on PulseChain.

## 6. Disclaimer

This whitepaper is for informational purposes. Interacting with SHD or its dApps involves risks; users should verify code and conduct thorough testing. The Snipehead team is not liable for losses.

## 7. Repository

- **GitHub**: [https://github.com/PBaieck-group/SnipeHead](https://github.com/PBaieck-group/SnipeHead)
- **Contracts**: `SnipeHead.sol`, `SnipeHeadFaucet.sol`, `SnipeheadMiningDecentralized.sol`
- **IPFS Links**: Included in repository README.

