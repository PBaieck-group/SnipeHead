# SnipeheadMiningDecentralizedV2_FIXED

A decentralized mining contract for **SnipeHead** (`SHD`) tokens on PulseChain.

Users mine SHD to earn additional SHD rewards at a fixed, predictable rate. The contract is fully decentralized with no admin keys after deployment.

---

## Contract Addresses

### Mainnet (PulseChain)
- **SHD Token**: `0xb95bc84f9b6d0373642d586b81979b067572f7bc`
- **Mining Contract**: `0xa16C1FA26F13803083f0fd222D1EA083c1d6D650`

### Testnet V4 (PulseChain) 

> **These addresses are for testing purposes on the PulseChain V4 Testnet and are not intended for mainnet use.**

- **SHD Token**: `0x14c1e69430C0e8A9C68C9626AE12EB33111C117C`
- **Mining Contract**: `0x4cB044b1f0708dAD14aDbD7731f407D3aB0502E8`

---

### ⚠️ Testnet V4 (PulseChain) — Legacy Reference Only

> **These addresses point to the old V2 contract and are provided for historical reference only.**
> These testnet contract does NOT include the reward reserve separation or reserve cap fixes present in the current production contract.
> Do not use the testnet contract as a reference for how the current system works.

- **SHD Token**: `0x98e7F08d660502A9F849F0fB08f1d136DC06F4bB`
- **Mining Contract**: `0x1F93c4ba25B8d689272b429B0A09F436377E864F`

---

## What Changed in V2_FIX (Current Production Contract)

The original V2 contract had a critical vulnerability: **reward tokens and staked principal shared the same pool**. This meant rewards could be paid out of other users' Mined tokens, potentially leaving Miners unable to withdraw their principal.

V2_FIX introduces two fixes:

### Fix 1 — Separated Reward Reserve
Tokens deposited via `deposit()` are tracked in a dedicated `rewardReserve` counter, completely separate from `totalMined` (mined principal). Rewards are only ever paid from `rewardReserve`  miner principal is never touched.

### Fix 2 — Reserve Cap
`updatePool()` now caps reward accrual to what is actually available in `rewardReserve`. The contract will never promise or accrue more rewards than it can pay. When the reserve runs dry, rewards simply pause until someone calls `deposit()` again no penalties to miners.

---

## Features

- Mine SHD tokens to earn rewards
- Unmine at any time — full principal always guaranteed
- Claim rewards without unmining
- Anyone can fund the reward pool via the public `deposit()` function
- Fixed reward rate (hardcoded, never changes)
- Reward reserve is publicly visible via `getRewardReserve()`
- Gas-efficient with custom errors
- Protected against reentrancy
- Fully tested with Foundry (45 tests covering small + very large mines, security invariants, and reserve cap behaviour)

---

## How It Works

### Mining
Users call `mine(uint256 amount)` after approving the mining contract to spend their SHD. Rewards accumulate each block proportionally based on `totalMined` and the fixed `rewardRate`, drawn exclusively from `rewardReserve`.

### Funding the Reward Pool
Anyone can call `deposit(uint256 amount)` to add SHD to the reward reserve. This is the **only** supported way to fund the pool.

> ⚠️ **Do not send SHD directly to the contract address.** Tokens transferred without using `deposit()` will not be credited to `rewardReserve` and will be permanently stranded with no way to recover them.

### Contract Functions

| Function | Description |
|---|---|
| `mine(amount)` | Mine SHD. Auto-claims any pending rewards first. |
| `unmine(amount)` | Unmine SHD. Auto-claims pending rewards. Principal always returned in full. |
| `claimRewards()` | Claim pending rewards without touching your mine. |
| `deposit(amount)` | Fund the reward reserve. Open to anyone. |
| `pendingRewards(address)` | View pending rewards for any address. Capped honestly by reserve. |
| `getRewardReserve()` | View remaining SHD available for future rewards. |
| `getContractSHDBalance()` | View total SHD held by the contract (mines + reserve). |

---

## Project Structure

~~~
SnipeheadMiningDecentralizedV2/
├── contracts/
│   ├── contracts.txt
│   └── SnipeheadMiningDecentralizedV2.sol          # Production contract (V2)
│
└── snipehead-mining-test/                          # Full Foundry project
    ├── src/
    │   ├── SnipeheadMiningDecentralizedV2.sol       # Contract under test (V2)
    │   ├── SnipeheadMiningDecentralizedV2_V4_TEST.sol  # Old testnet contract (legacy)
    │   └── SnipeHead.sol
    ├── test/
    │   └── SnipeheadMiningDecentralizedV2.t.sol    # 45 comprehensive tests
    ├── script/
    │   ├── SnipeheadMiningDecentralizedV2.s.sol    # Mainnet deployment script
    │   └── SnipeheadTestnetV4.s.sol                # Legacy testnet script
    ├── dAPP/
    │   └── index.html                              # Web dApp (testnet_V4)
    ├── commands.txt
    └── foundry.toml
~~~

---

## dApp

A modern, responsive web interface is included in:

`snipehead-mining-test/dAPP/index.html`

Configured for **PulseChain TestnetV4** (Chain ID 943).

### Features
- Connect wallet (MetaMask / Rabby / etc.)
- Mine, Unmine, and Claim with automatic two-step approval handling
- Real-time display of wallet balance, mined amount, and pending rewards
- **Reward Reserve Health Bar** — live indicator showing how much of the reward pool remains, colour-coded green / amber / critical
- Pool statistics: APY, Total SHD Mined, Contract Balance, Reward Reserve
- Tooltips explaining each stat
- "How It Works" section explaining the reserve separation model

> The old testnet dApp targeted the legacy V4 testnet contract and does not reflect the current contract behaviour.

---

## Testing

The contract is thoroughly tested using **Foundry** with 45 tests across 12 sections:

| Section | What is tested |
|---|---|
| Constructor | Initial state |
| `deposit()` | Reserve crediting, separation from mines, events |
| `getRewardReserve()` | Decreases on accrual, increases on deposit, never underflows |
| Security / Separation | Principal safe when reserve empty, two-miner isolation, balance invariant |
| Reserve Cap | Rewards stop when reserve = 0, resume after top-up, `pendingRewards` honest |
| `mine()` | Mining, auto-claim, large amounts, reverts, events |
| `unmine()` | Unmining, partial unmine, large amounts, reverts, events |
| `claimRewards()` | Accuracy, resets to zero, reverts when nothing to claim, events |
| `pendingRewards()` | Single-block accuracy, capped by reserve, zero when no mine |
| Multi-user | Proportional rewards, late joiner fairness |
| `updatePool()` | No-op same block, no-op zero mine, correct accrual |
| `getContractSHDBalance()` | Reflects mines + reserve, decreases on unmine |

### Run Tests

~~~bash
cd snipehead-mining-test
forge test --match-path test/SnipeheadMiningDecentralizedV2.t.sol -vvv
~~~

---

## Deployment

~~~bash
forge script script/SnipeheadMiningDecentralizedV2.s.sol \
  --rpc-url https://rpc.pulsechain.com \
  --broadcast -vvv
~~~

> The legacy testnet deployment script (`SnipeheadTestnetV4.s.sol`) targets the old V4 testnet contract and is kept for reference only.

---

## Security

- Uses OpenZeppelin `SafeERC20` and `ReentrancyGuard`
- Reward reserve and mined principal are strictly separated in accounting
- Reward accrual is hard-capped by available reserve — no over-promising
- No upgradeability or privileged functions after deployment
- No admin keys, no owner, fully immutable once deployed
- 45 unit tests including security invariant checks
- `pendingRewards()` view mirrors the same reserve cap used in `updatePool()` — the UI is always honest

---

## Disclaimer

This software is provided **as-is**, without warranties of any kind.

Users interact with the contract at their own risk. Always verify contract addresses and review the source code before use. The testnet contract addresses listed above refer to a legacy version and do not reflect current contract behaviour.

---

## License

MIT License