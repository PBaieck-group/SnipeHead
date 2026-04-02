# SnipeheadMiningDecentralizedV2

A decentralized mining contract for **SnipeHead** (`SHD`) tokens on PulseChain.

Users stake SHD to earn additional SHD rewards at a fixed, predictable rate. The contract is fully decentralized with no admin keys after deployment.

---

## Contract Addresses

### Mainnet (PulseChain)
- **SHD Token**: `0xb95bc84f9b6d0373642d586b81979b067572f7bc`
- **Mining Contract**: `0xDC292E06219F683f065c8911fAf1ad2109CBEDE0`

### Testnet V4 (PulseChain)
- **SHD Token**: `0x98e7F08d660502A9F849F0fB08f1d136DC06F4bB`
- **Mining Contract**: `0x1F93c4ba25B8d689272b429B0A09F436377E864F`

---

## Features

- Mine SHD tokens to earn rewards  
- Unmine at any time  
- Claim rewards without unmining  
- Anyone can fund the reward pool via the public `deposit()` function  
- Fixed reward rate (never changes)  
- Gas-efficient with custom errors  
- Protected against reentrancy  
- Fully tested with Foundry (small + very large stakes)  

---

## How It Works

Users call `mine(uint256 amount)` after approving the mining contract to spend their SHD.  
Rewards accumulate proportionally based on the global `totalMined` and the fixed `rewardRate`.

- `mine()` → mines tokens and auto-claims any pending rewards  
- `unmine()` → unminess tokens and auto-claims pending rewards  
- `claimRewards()` → claims pending rewards only  
- `deposit()` → anyone can add SHD to the reward pool  

---

## Project Structure

~~~
SnipeheadMiningDecentralizedV2/
├── contracts/
│   ├── contracts.txt
│   └── SnipeheadMiningDecentralizedV2.sol          # Production contract
│
└── snipehead-mining-test/                          # Full Foundry project
    ├── src/
    │   ├── SnipeheadMiningDecentralizedV2_V4_TEST.sol
    │   └── SnipeHead.sol
    ├── test/
    │   └── SnipeheadMiningDecentralizedV2.t.sol    # Comprehensive tests
    ├── script/
    │   └── SnipeheadTestnetV4.s.sol                # Deployment script
    ├── dAPP/                                      # Web dApp (index.html)
    ├── commands.txt
    └── foundry.toml
~~~

---

## dApp (Testnet)

A modern, responsive web interface is included in:

`snipehead-mining-test/dAPP/`

### Features
- Connect wallet (MetaMask / Rabby, etc.)
- Mine, Unmine, and Claim with automatic approval handling
- Real-time display of your balance, mined amount, and pending rewards
- Network statistics: APY, Total SHD Mined, Contract Balance, Available Rewards
- Clean glassmorphism design with particle animation

The dApp is configured for **PulseChain Testnet V4** (Chain ID 943).

---

## Testing

The contract is thoroughly tested using **Foundry**:

- Small and large amount tests (up to 500 million SHD)
- Reward calculation accuracy over many blocks
- Edge cases and reverts
- Event emission checks

### Run Tests

~~~bash
cd snipehead-mining-test
forge test
~~~

---

## Deployment

Deployment commands are available in:

`snipehead-mining-test/commands.txt`

### Example

~~~bash
forge script script/SnipeheadTestnetV4.s.sol \
  --rpc-url https://rpc.v4.testnet.pulsechain.com \
  --broadcast -vvv
~~~

---

## Security

- Uses OpenZeppelin `SafeERC20` and `ReentrancyGuard`
- No upgradeability or privileged functions after deployment
- Extensive unit test coverage
- Safe transfer logic to prevent sending more than available balance

---

## Disclaimer

This software is provided **as-is**, without warranties of any kind.

Users interact with the contract at their own risk. Always verify contract addresses and review code before use.

---

## License

MIT License