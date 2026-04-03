# SnipeHead Faucet V2

A secure and gas-efficient ERC20 faucet for the **SnipeHead (SHD)** token, built with Solidity ^0.8.20 and thoroughly tested using **Foundry**.

---

## ✨ Features

- **One claim per address ever** — Prevents abuse with permanent claim tracking
- **Daily global limit** — 1,000 SHD per 24 hours (resets automatically)
- **Reentrancy protection** — Uses OpenZeppelin's `ReentrancyGuard`
- **Hardcoded token address** — Maximum security (immutable)
- **Checks-Effects-Interactions** pattern followed
- **Comprehensive test coverage** — 12+ tests including edge cases
- **Event emission** for transparency

---

## 📁 Contracts

### 1. `Token.sol` (SnipeHead Token)
- Standard ERC20 with `Ownable` and `ERC20Burnable`
- Launch mechanism: Transfers are restricted until `launch()` is called by owner
- Prevents early sniping/trading

### 2. `SnipeHeadFaucetV2.sol`
- Main faucet contract
- Dispenses exactly **1 SHD** per unique address
- Enforces daily limit of **1000 SHD**
- Fully immutable token reference for security

---

## 🧪 Testing

The project includes a complete Foundry test suite (`SnipeHeadFaucetV2.t.sol`) covering:

- Successful claims
- One-claim-per-address enforcement
- Daily limit + automatic 24h reset
- Faucet empty protection
- Reentrancy attack resistance
- View functions correctness
- Event emission
- Partial daily usage and edge cases

**Run tests:**

```bash
forge test --match-contract SnipeHeadFaucetV2Test -vvv