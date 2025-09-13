# 🎯 SnipeHead (SHD) – Token Overview

> PulseChain ERC-20 Token with Permit Support  
> 🧠 Portal: [https://www.snipehead.xyz](https://www.snipehead.xyz)  
> 📦 Contract Address: `0x7E5A488756c3FEe54248f97a36dF5B0e9cf27d8d`

1. **SnipeHead Fallback**  
   [SnipeHead Link ](https://ipfs.io/ipfs/bafybeidncnqobpjszescv2uewuljfgfmywnbrezi2lrkpsjiwezzsixytq/)
   
2. **SnipeHead Faucet Fallback**  
   [Faucet Link ](https://ipfs.io/ipfs/bafybeigo643sh275jirwmy2lgou7qanfsgjpxk4bcygaqyqodgoswhe4fe/)
   
3. **Mining Fallback**  
   [Mining Link ](https://ipfs.io/ipfs/bafybeibzsdchcbl376jbvajpwj2fvazjfuicfr2h4awwk24xnqrih7f5ny/)
   
4. **Airdrop Fallback**  
   [Airdrop Checker Link](https://ipfs.io/ipfs/bafybeihegcjlaw6fkqbzc3kjwp64fn7bks7i4yhbdys5ckj2xpxtuorjwy/)

---

## 🔹 What is SnipeHead (SHD)?

**SnipeHead (SHD)** is a fungible ERC-20 token deployed on the PulseChain blockchain. It implements OpenZeppelin's secure and battle-tested ERC-20 and ERC-20 Permit extensions, making it compatible with both standard token interactions and off-chain signature-based approvals.

### ✅ Key Features

- **ERC-20 Compliant**: Standard token interface for seamless wallet and dApp integration.
- **EIP-2612 Permit Support**: Enables gasless approvals via signed messages.
- **Pre-Mint on Deployment**: The entire supply is minted to a single recipient upon deployment.
- **Fixed Supply**: 21 billion SHD, with no inflation or minting beyond deployment.
- **OpenZeppelin Contracts v5**: Built with the latest audited library.

---

## 📄 Contract Breakdown

### Contract: `SnipeHead.sol`

**Imports:**

- [`ERC20`](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20) — Base ERC-20 implementation.
- [`ERC20Permit`](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC20Permit) — Adds support for permit (EIP-2612).

```solidity
contract SnipeHead is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("SnipeHead", "SHD")
        ERC20Permit("SnipeHead")
    {
        _mint(recipient, 21_000_000_000 * 10 ** decimals());
    }
}
```

### Constructor

- **Parameter**: `recipient (address)` — The address receiving the full initial supply.
- **Minting Logic**: Mints `21,000,000,000 * 10^18` SHD tokens to the `recipient`.

### Token Metadata

| Property      | Value                   |
|---------------|--------------------------|
| Name          | `SnipeHead`              |
| Symbol        | `SHD`                    |
| Decimals      | `18`                     |
| Total Supply  | `21,000,000,000 SHD`     |

---

## 🧪 Test Suite Overview

Tests are written using `node:test` and `viem`, targeting both functional correctness and event emissions. Here's what each test does:

---

### 1. ✅ Token Metadata Verification

**Test Purpose:**  
Ensures that the deployed contract has the correct name, symbol, and decimals.

**Assertions:**
- `name() === "SnipeHead"`
- `symbol() === "SHD"`
- `decimals() === 18`

---

### 2. 💰 Initial Minting on Deployment

**Test Purpose:**  
Verifies that the full supply is minted correctly to the specified recipient.

**Assertions:**
- `balanceOf(recipient) === 21_000_000_000 * 10^18`
- `balanceOf(deployer) === 0`
- `totalSupply() === 21_000_000_000 * 10^18`

---

### 3. 🔁 Transfer Functionality and Events

**Test Purpose:**  
Checks that token transfers:
- Correctly update balances
- Emit a `Transfer` event with correct arguments

**Scenario:**
- Transfer 1 million SHD from recipient to deployer
- Assert:
  - `Transfer` event emitted
  - Recipient’s balance decreased
  - Deployer’s balance increased

---

### 4. 📝 Permit-Based Approvals (EIP-2612)

**Test Purpose:**  
Validates the off-chain approval and `transferFrom()` process using EIP-2612 permits.

**Steps:**
1. Generate a valid signature using `signTypedData`.
2. Submit the permit via `permit()` to set the allowance.
3. Call `transferFrom()` using the permitted allowance.

**Assertions:**
- Nonce is correct
- Allowance is correctly recorded
- Transfer via `transferFrom()` is successful
- Balances reflect the token movement

**Note on Signature Parsing:**
- Viem’s `parseSignature()` is used
- `v = yParity + 27` to match Ethereum's signature format

---

## 🧠 Tech Stack

| Feature                | Tool / Library                  |
|------------------------|----------------------------------|
| Contract Framework     | OpenZeppelin (ERC20 + Permit)    |
| Blockchain             | PulseChain                       |
| Language               | Solidity `^0.8.20`               |
| Testing                | Node.js `node:test`              |
| Blockchain Client      | [`viem`](https://viem.sh)        |
| Development Framework  | Hardhat + Viem Plugin            |

---

## 🌐 Network Info

PulseChain and testnet networks are configured in `hardhat.config.ts`:

| Network            | Chain ID | Type     |
|--------------------|----------|----------|
| PulseChain         | `369`    | Mainnet  |
| PulseChain Testnet | `943`    | Testnet  |

Accounts and RPC URLs are managed through environment variables.

---

## 📌 Summary

The **SnipeHead (SHD)** token contract is a modern, high-supply ERC-20 implementation for PulseChain. It features:

- Strict compliance with ERC-20 and EIP-2612 standards  
- Complete off-chain signature support for gasless approvals  
- High-efficiency initial mint with a fixed 21 billion SHD supply  
- Well-structured tests verifying every major contract feature  

Built using the latest OpenZeppelin libraries and tested with `viem`, `node:test`, and Hardhat, this contract is production-ready and PulseChain-optimized.

---

🔗 **Project Website**: [https://www.snipehead.xyz](https://www.snipehead.xyz)  
📄 **License**: This project is licensed under the MIT License. See the LICENSE file for details.

✅ **Disclaimer**: This contract is provided as-is. Interacting with smart contracts involves risk; always verify code and test thoroughly. The SnipeHead project is not responsible for any losses.

🛡 Built with ❤️ by the SnipeHead Team
