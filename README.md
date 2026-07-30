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
- **Mining V2 Address:** [0xa16C1FA26F13803083f0fd222D1EA083c1d6D650](https://ipfs.scan.pulsechain.com/address/0xa16C1FA26F13803083f0fd222D1EA083c1d6D650)
- **SnipeHead NFT (SNFT) Address:** [0x4A345c962DFA2492023a1D19bc88062B532a43c3](https://scan.pulsechain.com/address/0x4A345c962DFA2492023a1D19bc88062B532a43c3)
- **SnipeHead Launch Transaction:** [View on Explorer](https://ipfs.scan.pulsechain.com/tx/0xc8ae761ec0320037364625f5bc136b479aac5ebf5b067bedb86e3ccfe4a40d8b)

### 🖼️ SNFT Assets

- **SNFT Metadata (IPFS):**  
  https://bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju.ipfs.inbrowser.link/

- **SNFT Images (IPFS):**  
  https://bafybeibjoncyfsdv32fwfk2damq32jgtktpspkayurt52rvd4lqz6shsuy.ipfs.inbrowser.link/

### 🌐 IPFS Fallbacks

- **IPFS Faucet dApp Fallback:** [bafybeify4vlff6g4dl5oibtzy5ie4de6ipl2sg7zibie2vlw74ql7y4nva](https://bafybeify4vlff6g4dl5oibtzy5ie4de6ipl2sg7zibie2vlw74ql7y4nva.ipfs.dweb.link)
- **IPFS Mining dApp Fallback:** [bafybeienqnmtb4xgeovqqn3qjtld4v3hzpjesy7q5klyq2t42ejliwzlja](https://bafybeienqnmtb4xgeovqqn3qjtld4v3hzpjesy7q5klyq2t42ejliwzlja.ipfs.dweb.link)
- **IPFS SnipeHead SNFT dApp Fallback:** [bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla](https://bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla.ipfs.inbrowser.link/)
---


## 🧱 Ecosystem

SnipeHead is evolving into a **multi-component decentralized ecosystem** built around the SHD token.

### 🔹 Core Components

#### 1. Token (SHD)
Standard ERC20 token that launched with built-in **launch protection**:
- Transfers were restricted until the token officially launched.
- The token was automatically launched by **Pump.Tires** (a Pump.fun clone on PulseChain) once the bonding curve filled.
- SHD has since **graduated** off the bonding curve and now trades freely on **PulseX**.

#### 2. Decentralized Mining
Fully trustless mining protocol:
- Mine SHD to earn SHD rewards
- No lockups — withdraw anytime
- Fixed reward rate
- No admin control or upgradeability
- Reward reserve is strictly separated from staked principal, with rewards hard-capped by what's actually funded — see the [Mining contract README](https://github.com/PBaieck-group/SnipeHead/blob/main/SnipeheadMiningDecentralizedV2/README.md) for the full design and 45-test Foundry suite.
- Single-file, zero-dependency dApp — see the [Mining dApp README](https://github.com/PBaieck-group/SnipeHead/blob/main/dApps/SnipeheadMiningDecentralizedV2/README.md) for how it's built and how to run your own copy.

**Mining Contract:** `0xa16C1FA26F13803083f0fd222D1EA083c1d6D650`
**Contract Repository:** [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeheadMiningDecentralizedV2)
**dApp Repository:** [dApps/SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeheadMiningDecentralizedV2)

#### 3. Faucet V2
A secure and fair community faucet to help new users get started with SHD.

**Contract Address:** [0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98](https://ipfs.scan.pulsechain.com/address/0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98)

**Features:**
- Exactly **1 SHD** per address (one claim per wallet ever)
- Global daily limit of **1,000 SHD** (automatically resets every 24 hours)
- Protected against reentrancy attacks (OpenZeppelin `ReentrancyGuard`)
- Hardcoded immutable token address for maximum security
- Thoroughly tested with Foundry (12+ comprehensive tests) — see the [Faucet contract README](https://github.com/PBaieck-group/SnipeHead/blob/main/SnipeHead-faucetV2/README.md) for the full contract breakdown.
- Single-file, zero-dependency dApp — see the [Faucet dApp README](https://github.com/PBaieck-group/SnipeHead/blob/main/dApps/SnipeHeadFaucetV2/README.md) for how it's built and how to run your own copy.

**Contract Repository:** [SnipeHead-faucetV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeHead-faucetV2)
**dApp Repository:** [dApps/SnipeHeadFaucetV2](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeHeadFaucetV2)

#### 4. SnipeHead NFT (SNFT)
A limited-edition **ERC-721** collection of **35 unique NFTs** on PulseChain.

**Contract Address:** [0x4A345c962DFA2492023a1D19bc88062B532a43c3](https://ipfs.scan.pulsechain.com/address/0x4A345c962DFA2492023a1D19bc88062B532a43c3)

**Key details:**
- **Max Supply:** 35
- **Max per wallet (public mint):** 2
- **Mint Price (mainnet):** 3,000,000 PLS
- **Royalty:** 1% (EIP-2981)
- **Metadata:** Fully on IPFS (`bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju`)
- Sequential minting (token IDs 1 → 35)
- Owner-only reserve mint (`ownerMint`) that does **not** count against the public per-wallet limit
- Reentrancy protection, Ownable + pull-pattern withdraw, Enumerable support
- Thoroughly tested with Foundry (43 tests including fuzz tests)

**IPFS SNFT dApp Fallback:** [bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla](https://bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla.ipfs.inbrowser.link/)

---

## 📁 Repositories & Contracts

| Component              | Status     | Contract Address                                   | Contract Folder | dApp Folder |
|------------------------|------------|----------------------------------------------------|------------------|-------------|
| SnipeHead (SHD)            | Live       | `0xB95bC84f9B6D0373642D586b81979B067572f7bc`     | [SnipeHead.sol](https://scan.mypinata.cloud/ipfs/bafybeienxyoyrhn5tswclvd3gdjy5mtkkwmu37aqtml6onbf7xnb3o22pe/#/address/0xB95bC84f9B6D0373642D586b81979B067572f7bc?tab=contract) | — |
| Faucet V2              | Live       | `0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98`     | [SnipeHead-faucetV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeHead-faucetV2) | [dApps/SnipeHeadFaucetV2](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeHeadFaucetV2) |
| Decentralized Mining   | Live       | `0xa16C1FA26F13803083f0fd222D1EA083c1d6D650`     | [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeheadMiningDecentralizedV2) | [dApps/SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeheadMiningDecentralizedV2) |
| SnipeHead NFT (SNFT)   | Live       | `0x4A345c962DFA2492023a1D19bc88062B532a43c3`     | [SNFT](https://github.com/PBaieck-group/SnipeHead/tree/main/SNFT) | [dApps/SNFT](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SNFT) |

---

## 🛠️ How to Get SHD

1. **Claim from Faucet V2** ← recommended starting point for new users (1 SHD per wallet)
2. **Buy on PulseX** — SHD has graduated and trades freely, no bonding curve
3. Participate in decentralized mining

**How to get SNFT:** Mint on the NFT dApp (public mint, max 2 per wallet) or via the contract. See the IPFS NFT dApp Fallback above.

---

## 🔄 About V2

SnipeHead V2 is a complete upgrade from the original token. The old ecosystem components are now **deprecated** but still accessible for reference.

V2 focuses on cleaner architecture, better security, and modular expansion — now including a limited NFT collection as part of the broader ecosystem.

---

## 📈 Launch & Trading

- Originally launched via **Pump.Tires** — a Pump.fun-style bonding curve launcher on PulseChain.
- SHD has since **graduated** the bonding curve and is now fully transferable and trading on **PulseX**.
- Trade SHD: [ipfs.app.pulsex.com](https://ipfs.app.pulsex.com/?outputCurrency=0xb95bc84f9b6d0373642d586b81979b067572f7bc)

---

## 💡 Vision

SnipeHead V2 aims to grow from a token into a **sustainable DeFi ecosystem** on PulseChain by providing transparent, trustless, and community-friendly tools — including decentralized mining, a fair faucet, and a limited-edition NFT collection.

---

## ⚠️ Disclaimer

This project is experimental and part of the evolving PulseChain ecosystem.
Always do your own research (DYOR) before interacting with any smart contracts or trading tokens.

---

## 🔗 Links

- **Website**: [snipehead.xyz](https://www.snipehead.xyz)
- **Token**: [View on PulseChain Scan](https://ipfs.scan.pulsechain.com/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)
- **Faucet V2**: [0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98](https://ipfs.scan.pulsechain.com/address/0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98)
- **Faucet V2 contract README**: [SnipeHead-faucetV2](https://github.com/PBaieck-group/SnipeHead/blob/main/SnipeHead-faucetV2/README.md)
- **Faucet V2 dApp README**: [dApps/SnipeHeadFaucetV2](https://github.com/PBaieck-group/SnipeHead/blob/main/dApps/SnipeHeadFaucetV2/README.md)
- **Mining Contract V2**: [0xa16C1FA26F13803083f0fd222D1EA083c1d6D650](https://ipfs.scan.pulsechain.com/address/0xa16C1FA26F13803083f0fd222D1EA083c1d6D650)
- **Mining V2 contract README**: [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/blob/main/SnipeheadMiningDecentralizedV2/README.md)
- **Mining V2 dApp README**: [dApps/SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/blob/main/dApps/SnipeheadMiningDecentralizedV2/README.md)
- **SnipeHead NFT (SNFT)**: [0x4A345c962DFA2492023a1D19bc88062B532a43c3](https://bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla.ipfs.inbrowser.link)
- **IPFS SNFT dApp Fallback**: [bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla](https://bafybeigelpwmsvfricfa25x3upeyq5rwpprvg7enx6xtzxscexqr4lwzla.ipfs.inbrowser.link/)
- **SnipeHead NFT dApp README**: [dApps/SNFT](https://github.com/PBaieck-group/SnipeHead/blob/main/dApps/SNFT/README.md)
- **Trade on PulseX**: [ipfs.app.pulsex.com](https://ipfs.app.pulsex.com/?outputCurrency=0xb95bc84f9b6d0373642d586b81979b067572f7bc)

---

**Built for the SnipeHead community — better, smarter, and more decentralized.**
