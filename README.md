# SnipeHead (SHD) - V2

**SnipeHead V2** is the next evolution of the original SnipeHead token on PulseChain — rebuilt with improved tokenomics, stronger foundations, and a focus on sustainable, community-driven growth.

---

## 🚀 Overview

- 🧠 **Portal**: [snipehead.xyz](https://www.snipehead.xyz)
- **Token Name:** SnipeHead
- **Symbol:** SHD
- **Network:** PulseChain
- **Total Supply:** 1,000,000,000 SHD
- **Token Address:** [0xB95bC84f9B6D0373642D586b81979B067572f7bc](https://ipfs.scan.pulsechain.com/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)
- **Faucet V2 Address:** [0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98](https://ipfs.scan.pulsechain.com/address/0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98)
- **Mining V2 Address:** [0xDC292E06219F683f065c8911fAf1ad2109CBEDE0](https://ipfs.scan.pulsechain.com/address/0xDC292E06219F683f065c8911fAf1ad2109CBEDE0)
- **SnipeHead Launch Transaction:** [View on Explorer](https://ipfs.scan.pulsechain.com/tx/0xc8ae761ec0320037364625f5bc136b479aac5ebf5b067bedb86e3ccfe4a40d8b)
- **IPFS Faucet dApp Fallback:** [bafybeigvp3b5e37lcadocihbishejrf74c5gu63aiwln5jpcha4d2xydvm](https://bafybeigvp3b5e37lcadocihbishejrf74c5gu63aiwln5jpcha4d2xydvm.ipfs.dweb.link)
- **IPFS Mining dApp Fallback:** [bafybeiegjnpttuxiyhbgxwnez2yugytqu2zvif4uj44qdgj3ostpg6ftri](https://bafybeiegjnpttuxiyhbgxwnez2yugytqu2zvif4uj44qdgj3ostpg6ftri.ipfs.dweb.link)

---

## 🧱 Ecosystem

SnipeHead is evolving into a **multi-component decentralized ecosystem** built around the SHD token.

### 🔹 Core Components

#### 1. Token (SHD)
Standard ERC20 token with built-in **launch protection**:
- Transfers are restricted until the token is officially launched.
- The token is automatically launched by **Pump.Tires** (a Pump.fun clone on PulseChain) after the bonding curve is fully filled.

#### 2. Decentralized Mining
Fully trustless mining protocol:
- Mine SHD to earn SHD rewards
- No lockups — withdraw anytime
- Fixed reward rate
- No admin control or upgradeability

**Mining Contract:** `0xDC292E06219F683f065c8911fAf1ad2109CBEDE0`  
**Repository:** [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeheadMiningDecentralizedV2)

#### 3. Faucet V2
A secure and fair community faucet to help new users get started with SHD.

**Contract Address:** [0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98](https://ipfs.scan.pulsechain.com/address/0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98)

**Features:**
- Exactly **1 SHD** per address (one claim per wallet ever)
- Global daily limit of **1,000 SHD** (automatically resets every 24 hours)
- Protected against reentrancy attacks (OpenZeppelin `ReentrancyGuard`)
- Hardcoded immutable token address for maximum security
- Thoroughly tested with Foundry (12+ comprehensive tests)

**Repository Folder:** [`SnipeHead-faucetV2`](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeHead-faucetV2)

---

## 📁 Repositories & Contracts

| Component              | Status     | Contract Address                                   | Link |
|------------------------|------------|----------------------------------------------------|------|
| Token (SHD)            | Live       | `0xB95bC84f9B6D0373642D586b81979B067572f7bc`     | [Token.sol](https://github.com/PBaieck-group/SnipeHead/blob/main/Token.sol) |
| Faucet V2              | Live       | `0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98`     | [SnipeHead-faucetV2/](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeHead-faucetV2) |
| Decentralized Mining   | Live       | `0xDC292E06219F683f065c8911fAf1ad2109CBEDE0`     | [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeheadMiningDecentralizedV2) |

---

## 🛠️ How to Get SHD

1. **Claim from Faucet V2** ← Claim after bonding recommended for new users (1 SHD per wallet)
2. Buy on PumpTires (bonding curve)
3. Participate in decentralized mining

---

## 🔄 About V2

SnipeHead V2 is a complete upgrade from the original token. The old ecosystem components are now **deprecated** but still accessible for reference.

V2 focuses on cleaner architecture, better security, and modular expansion.

---

## 📈 Launch & Trading

- Launched via **Pump.Tires** — a Pump.fun-style bonding curve launcher on PulseChain.
- The token becomes fully transferable only after the bonding curve is completed and Pump.Tires calls `launch()`.
- Trade SHD: [pump.tires/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc](https://pump.tires/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)

---

## 💡 Vision

SnipeHead V2 aims to grow from a token into a **sustainable DeFi ecosystem** on PulseChain by providing transparent, trustless, and community-friendly tools.

---

## ⚠️ Disclaimer

This project is experimental and part of the evolving PulseChain ecosystem.  
Always do your own research (DYOR) before interacting with any smart contracts or trading tokens.

---

## 🔗 Links

- **Website**: [snipehead.xyz](https://www.snipehead.xyz)
- **Token**: [View on PulseChain Scan](https://ipfs.scan.pulsechain.com/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)
- **Faucet V2**: [0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98](https://ipfs.scan.pulsechain.com/address/0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98)
- **Mining Contract V2**: [0xDC292E06219F683f065c8911fAf1ad2109CBEDE0](https://ipfs.scan.pulsechain.com/address/0xDC292E06219F683f065c8911fAf1ad2109CBEDE0)
- **Trade on PumpTires**: [pump.tires](https://pump.tires/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)

---

**Built for the SnipeHead community — better, smarter, and more decentralized.**
