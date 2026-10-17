# SHD Buy & Burn

> **Permanently burn SHD tokens on PulseChain — directly or by buying with PLS.**  
> Burns are permanent and **irreversible**.

This dApp lets anyone:

1. **Burn SHD** you already hold (via the token’s `burn` function).
2. **Buy & Burn** — send PLS to the Buy & Burn contract, which swaps for SHD on PulseX and burns it in the same flow.
3. Help the system by **processing queued PLS**, **refreshing the price oracle**, or **burning stuck SHD** held by the contract.

| | |
|---|---|
| **Network** | PulseChain (chain ID `369`) |
| **Version** | 1.5 |
| **Live (IPFS)** | [Open Buy & Burn dApp](https://bafybeicsxvytyje2tzqu5ubbparwsqeo3mgsy5u2brx3dlbyidhlvy3634.ipfs.inbrowser.link) |
| **Repo path** | [`dApps/BuyAndBurn`](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/BuyAndBurn) |

---

## Contract addresses

| Contract | Address | Explorer |
|----------|---------|----------|
| **SHD Token** | [`0xb95bc84f9b6d0373642d586b81979b067572f7bc`](https://ipfs.scan.pulsechain.com/address/0xb95bc84f9b6d0373642d586b81979b067572f7bc) | PulseChain Scan |
| **Buy & Burn** | [`0x3677e61a7a9e79fe45a882c201365c5165a5540e`](https://ipfs.scan.pulsechain.com/address/0x3677e61a7a9e79fe45a882c201365c5165a5540e) | PulseChain Scan |

- Token decimals: **18**
- Native currency: **PLS** (Pulse)
- Initial supply (for burned % display): **1,000,000,000 SHD**
- Addresses that count as burned sinks: `0x000…000` and `0x000…dead`

Always verify the addresses on-chain before approving, burning, or sending PLS.

---

## How it works

### Direct burn (your SHD)

1. Connect a wallet on **PulseChain**.
2. Enter the amount of SHD to burn.
3. Confirm that you understand the burn is permanent.
4. Confirm the transaction — tokens are destroyed via the token’s burn function and total supply decreases.

### Buy & Burn (PLS → SHD → burn)

1. Enter the amount of **PLS** to spend (and optional slippage).
2. Review the live quote (estimated SHD burned, min out, any queued remainder).
3. Confirm that you understand PLS sent is spent and not refunded.
4. The contract swaps PLS for SHD on PulseX (using a TWAP price oracle) and burns the SHD.
5. Amounts above the per-call cap stay **queued** in the contract and are burned by later calls.

### Helper actions (anyone can call)

| Action | What it does |
|--------|----------------|
| **Process queued** | Swaps/burns PLS (or WPLS) already sitting in the contract |
| **Refresh price oracle** | Advances the TWAP window (only once ≥ ~30 minutes have passed) |
| **Burn SHD in contract** | Burns any SHD held by the Buy & Burn contract (`burnStuckSHD`) |

---

## Features

- **Two burn paths** — direct SHD burn + Buy & Burn with PLS
- **Live quotes** — estimated SHD out, min out after slippage, queued remainder
- **TWAP oracle** — price floor protection; oracle must be ready (~30 min window)
- **Queued funds** — excess PLS stays in the contract for later burns
- **Public stats** — total burned, % of supply, contract balances (visible without connecting)
- **Wallet support** — EIP-6963 multi-wallet discovery + legacy `window.ethereum`
- **Network enforcement** — prompts to switch / add PulseChain
- **RPC manager** — built-in nodes + custom RPCs, optional failover, status indicator
- **Confirm modal** — shows amount, contract, network, and mode-specific notes before signing
- **Replacement-tx handling** — follows speed-ups / replacements for both burn and buy flows
- **Session restore** — reconnects only wallets the user previously connected on this page
- **Strict CSP** — no external scripts/fonts; styles and scripts are integrity-hashed
- **Mobile-friendly** — MetaMask deep-link hint on mobile browsers

---

## Built-in RPCs

| Name | URL |
|------|-----|
| PulseChain (official) | `https://rpc.pulsechain.com` |
| PublicNode | `https://pulsechain-rpc.publicnode.com` |
| G4mm4 | `https://rpc-pulsechain.g4mm4.io` |

You can add custom HTTPS RPC endpoints in the UI (stored in `localStorage`). Failover is enabled by default.

---

## Oracle & slippage notes

- The Buy & Burn contract uses a **TWAP** (time-weighted average price) over a **30-minute** window (`twapWindowSec: 1800`).
- If the oracle is not ready or has gone stale, use **Refresh price oracle** first.
- Slippage protects you if the pool price moves; if swaps keep failing with “SlippageExceeded”, try a slightly higher slippage or refresh the oracle.
- A re-quote is taken right before sending; if the quote has moved more than ~2% since you reviewed it, the dApp aborts so you can review again.

---

## Local usage

This is a single-file static dApp (`index.html`). No build step is required.

```bash
# Clone the repo
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/dApps/BuyAndBurn

# Serve locally (any static server)
npx serve .
# or
python3 -m http.server 8080
```

Open the page in a browser with a PulseChain-capable wallet.

> **Note:** Some wallets and browsers require HTTPS (or `localhost`) for `eth_requestAccounts`. Prefer serving over `https://` or a local tunnel when testing.

---

## IPFS / decentralized access

The current deployment is available via IPFS:

**https://bafybeicsxvytyje2tzqu5ubbparwsqeo3mgsy5u2brx3dlbyidhlvy3634.ipfs.inbrowser.link**

You can also resolve the CID with any IPFS gateway:

```
https://ipfs.io/ipfs/bafybeicsxvytyje2tzqu5ubbparwsqeo3mgsy5u2brx3dlbyidhlvy3634
```

---

## Security & safety notes

- **Burns are permanent and irreversible.** Only burn or spend amounts you are willing to destroy forever.
- **PLS sent to Buy & Burn is spent**, not refunded. You receive nothing in return.
- The page never asks for your seed phrase or private keys. It only interacts via your wallet’s standard provider APIs.
- Content-Security-Policy is strict: no external scripts, no external fonts, `connect-src https:` only.
- Always double-check the token and Buy & Burn contract addresses before signing.
- Prefer verifying the page hash / IPFS CID when using gateways.

---

## Tech stack

- Vanilla HTML / CSS / JavaScript (single file)
- [ethers.js](https://docs.ethers.org/) (bundled) for contract interaction
- EIP-6963 wallet discovery + EIP-1193 provider
- PulseX swap path (SHD/WPLS) + TWAP oracle on the Buy & Burn contract
- Native `<dialog>` confirm modal
- PulseChain (chain ID 369)

---

## Related links

- **Main project:** [github.com/PBaieck-group/SnipeHead](https://github.com/PBaieck-group/SnipeHead)
- **Portal:** [snipehead.xyz](https://snipehead.xyz)
- **Explorer:** [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com)
- **Deposit dApp (reward reserve funding):** [`dApps/Deposit`](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/Deposit)

---

## Disclaimer

This is burn / buy-and-burn software. Interacting with smart contracts involves risk of permanent loss of funds. There is no refund or recovery mechanism for burned tokens or PLS spent. Use at your own risk. The authors and contributors are not responsible for any losses incurred through use of this dApp or the associated contracts.

---

**SnipeHead · PulseChain · Permanent irreversible burn · v1.5**
