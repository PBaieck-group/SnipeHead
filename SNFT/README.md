# SnipeHead NFT

A limited-edition ERC-721 collection of **35 unique NFTs** on **PulseChain**.

- **Max Supply:** 35  
- **Max per wallet (public mint):** 2  
- **Mint Price (mainnet):** 3,000,000 PLS  
- **Royalty:** 1% (EIP-2981)  
- **Metadata:** Fully on IPFS  

---

## Deployed Contracts

| Network                  | Address                                      | Status | Explorer |
|--------------------------|----------------------------------------------|--------|----------|
| **PulseChain Mainnet**   | [`0x4A345c962DFA2492023a1D19bc88062B532a43c3`](https://scan.pulsechain.com/address/0x4A345c962DFA2492023a1D19bc88062B532a43c3) | Live | [Sourcify](https://sourcify.dev/#/lookup/0x4A345c962DFA2492023a1D19bc88062B532a43c3) |
| PulseChain Testnet v4    | `0x4A345c962DFA2492023a1D19bc88062B532a43c3` | Tested | - |

> Note: The same address appears on both networks because the deployer used the same nonce.

---

## Features

- Sequential minting (token IDs 1 → 35)
- Public mint with per-wallet limit of 2
- Owner-only reserve mint (`ownerMint`) that does **not** count against the public per-wallet limit
- EIP-2981 royalties (1%)
- Fully on-chain metadata resolution via IPFS
- Reentrancy protection
- Ownable + pull-pattern withdraw
- Enumerable (supports marketplaces that need `tokenByIndex` / `tokenOfOwnerByIndex`)

---

## Project Structure

```text
.
├── src/
│   └── SnipeHeadNFT.sol                  # Main contract
├── script/
│   ├── DeploySnipeHeadNFT.s.sol          # Testnet deploy
│   ├── DeployMainnetSnipeHeadNFT.s.sol   # Mainnet deploy + activate + transfer ownership
│   ├── SmokeTestSnipeHeadNFT.s.sol       # Live smoke tests
│   └── Config.sol
├── test/
│   └── SnipeHeadNFT.t.sol                # Comprehensive Foundry unit + fuzz tests
├── metadata/                             # 001.json → 035.json + table.csv
├── assets/images/                        # Source images
└── foundry.toml
```

---

## Setup

```bash
# Clone & install
git clone <repo>
cd <repo>
forge install

# Copy environment file
cp .env.example .env
```

### `.env` variables

```env
PRIVATE_KEY=0x...
INITIAL_OWNER=0x...
ROYALTY_RECEIVER=0x...
ROYALTY_FEE_BPS=100
NFT_ADDRESS=0x4A345c962DFA2492023a1D19bc88062B532a43c3
SECOND_PRIVATE_KEY=0x...          # only needed for smoke tests
```

---

## Testing

### Unit + Fuzz tests (local)

```bash
forge test -vv
```

All 43 tests pass (including fuzz tests for payment validation, withdraw, enumeration, royalties, reentrancy, etc.).

### Live smoke tests on PulseChain Testnet v4

```bash
forge script script/SmokeTestSnipeHeadNFT.s.sol:SmokeTestSnipeHeadNFT \
  --rpc-url https://pulsechain-testnet.publicnode.com \
  --broadcast \
  -vvvv
```

---

## Deployment

### Testnet (PulseChain v4)

```bash
forge script script/DeploySnipeHeadNFT.s.sol:DeploySnipeHeadNFT \
  --rpc-url https://rpc.v4.testnet.pulsechain.com \
  --broadcast \
  -vvvv
```

### Mainnet (PulseChain)

The mainnet script performs three actions in one transaction sequence:

1. Deploys the contract
2. Calls `setMintingActive(true)`
3. Transfers ownership to `0x53c06B1748885c34AA224AB395d9846E675a3bE1`

```bash
forge script script/DeployMainnetSnipeHeadNFT.s.sol:DeployMainnetSnipeHeadNFT \
  --rpc-url https://rpc.pulsechain.com \
  --broadcast \
  -vvvv
```

---

## Verification (Sourcify)

```bash
forge verify-contract 0x4A345c962DFA2492023a1D19bc88062B532a43c3 \
  src/SnipeHeadNFT.sol:SnipeHeadNFT \
  --chain-id 369 \
  --verifier sourcify \
  --constructor-args $(cast abi-encode "constructor(address,address,uint96)" \
    0xD3BBcBdb5a1f3caE2dC757aC5E6F23CD941828Bf \
    0x53c06B1748885c34AA224AB395d9846E675a3bE1 \
    100)
```

---

## Contract Configuration

| Parameter            | Value                          |
|----------------------|--------------------------------|
| Name / Symbol        | SnipeHead NFT / SNFT           |
| Max Supply           | 35                             |
| Max per wallet       | 2 (public mint only)           |
| Starting Token ID    | 1                              |
| Mint Price (mainnet) | 3,000,000 PLS                  |
| Royalty              | 1% (100 bps)                   |
| Metadata CID         | `bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju` |
| Public mint          | Enabled on mainnet             |
| Current Owner        | `0x53c06B1748885c34AA224AB395d9846E675a3bE1` |

---

## Important Notes

- Token IDs are assigned **sequentially** (1, 2, 3 … 35). You cannot choose a specific ID.
- `ownerMint` does **not** increase `mintedPerWallet` — it is intended for team / giveaway allocations.
- Once ownership is transferred, only the new owner can call admin functions (`setMintPrice`, `setMintingActive`, `withdraw`, `ownerMint`, etc.).
- Do **not** call `renounceOwnership()` while the contract may hold funds — `withdraw()` becomes permanently locked.

---

## License

MIT
```