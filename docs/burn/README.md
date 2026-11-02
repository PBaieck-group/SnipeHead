# SHD Burn

**Permanent, irreversible SHD token burns on PulseChain.**

This is a single-page, client-side web app for burning SnipeHead (SHD) tokens and for **Buy & Burn** (spend PLS → swap for SHD on PulseX → burn the SHD in one transaction).

- **Live path (this folder):** [docs/burn](https://github.com/PBaieck-group/SnipeHead/tree/main/docs/burn)
- **Version:** v1.14
- **Network:** PulseChain (`chainId` 369)
- **No backend.** Everything runs in your browser. Your private keys never leave your wallet.

---

## What it does

### 1. Direct burn
Connect a wallet, enter an amount of SHD, confirm, and call the token’s `burn(uint256)` function. Burned tokens are destroyed forever and removed from circulating supply.

### 2. Buy & Burn
Send PLS to the Buy & Burn contract. The contract:

1. Swaps PLS for SHD (subject to pool limits and a TWAP-based price floor)
2. Burns the received SHD in the same flow

PLS you send is **spent, not refunded**. Excess PLS that does not fit in one call can stay **queued** in the contract and be processed by a later call (yours or someone else’s).

### 3. Public stats (no wallet required)
Anyone can open the page and see total burned / total supply without connecting a wallet. Connect only when you want to burn or buy-and-burn.

---

## Features

| Feature | Notes |
|--------|--------|
| **Wallet connect** | EIP-6963 multi-wallet discovery + legacy `window.ethereum`. MetaMask and other injected wallets supported. |
| **Network guard** | Detects wrong chain and offers one-click switch / add PulseChain. |
| **Direct SHD burn** | Confirmation checkbox + review modal before the wallet prompt. |
| **Buy & Burn** | Live quote, slippage control, min-out protection, oracle readiness checks. |
| **Price oracle** | TWAP-style observations (~30 min window). Button to refresh when stale. |
| **Queued PLS** | “Burn queued PLS now” when the contract holds pending PLS. |
| **Stuck SHD** | “Burn SHD in contract” if the Buy & Burn contract holds residual SHD. |
| **RPC selector** | Built-in public RPCs + custom HTTPS RPC URLs, optional failover, preferences stored locally. |
| **Self-hosted ethers** | Official ethers v6 UMD bundle inlined — **no CDN**. |
| **Strict CSP** | Content-Security-Policy with script/style hashes; `connect-src` limited to the three built-in RPCs + localhost; anti-clickjacking; no external fonts/scripts. |
| **Mobile-friendly** | On mobile without a wallet, shows a copy-this-address box so you can open the page in a wallet browser (no third-party redirect). |

---

## Contracts & addresses

| Item | Value |
|------|--------|
| **Network** | PulseChain (chain ID `369` / `0x171`) |
| **SHD token** | [`0xb95bc84f9b6d0373642d586b81979b067572f7bc`](https://ipfs.scan.pulsechain.com/address/0xb95bc84f9b6d0373642d586b81979b067572f7bc) |
| **Buy & Burn** | [`0x3677e61a7a9e79fe45a882c201365c5165a5540e`](https://ipfs.scan.pulsechain.com/address/0x3677e61a7a9e79fe45a882c201365c5165a5540e) |
| **Explorer** | [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com) |

Burn accounting also treats balances held at the zero address and `0x…dead` as burned (in addition to supply reduced by `burn()`).

---

## Security model (read this)

- **Burns are permanent.** There is no undo, no recovery, no admin “unburn.”
- **Buy & Burn is not refundable.** PLS you send is used to buy SHD that is then burned. You receive nothing back.
- The page is **static HTML + JS**. It does not host your keys. Transactions are signed only by your wallet.
- Prefer running a **local copy** (see below) so you are not dependent on any single host.
- Always verify you are on **PulseChain** and that the token / Buy & Burn addresses match the table above before signing.

---

## How to use (hosted)

1. Open the burn page from this repo’s `docs/burn` folder (or any host that serves `index.html`).
2. Optionally pick an RPC node (built-in or your own HTTPS endpoint).
3. Connect your wallet and switch to PulseChain if prompted.
4. **Direct burn:** enter SHD amount → check the irreversible confirmation → confirm in the modal → approve in the wallet.
5. **Buy & Burn:** enter PLS amount → set slippage → review the quote → check the non-refundable confirmation → confirm → approve in the wallet.

---

## Run it yourself (decentralized / local)

You do **not** need Node, npm, or a build step. The site is one self-contained `index.html`.

### Option A — Clone this repo and open the file

```bash
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/docs/burn
```

Then either:

**Simple static server (recommended):**

```bash
# Python 3
python3 -m http.server 8080

# or Node (if you have it)
npx --yes serve -l 8080
```

Open: [http://127.0.0.1:8080](http://127.0.0.1:8080)

**Or open the file directly** in a browser (`file://…/index.html`).  
Some wallets block or limit `file://` pages; a local HTTP server is more reliable.

### Option B — Download only the burn page

1. Open this folder on GitHub:  
   [https://github.com/PBaieck-group/SnipeHead/tree/main/docs/burn](https://github.com/PBaieck-group/SnipeHead/tree/main/docs/burn)
2. Download `index.html` (Raw → Save).
3. Serve it with any static server as above, or host it on IPFS / your own domain.

### Option C — Host on IPFS or your own server

Upload `index.html` as a static asset. No API keys, no server-side code. Point any static host (GitHub Pages, Cloudflare Pages, nginx, IPFS gateway, etc.) at the file.

Example with IPFS CLI:

```bash
ipfs add index.html
# use the resulting CID with your preferred gateway or IPNS
```

---

## RPC nodes

Built-in defaults (used for **2-of-3 quorum** cross-checks):

| Name | URL |
|------|-----|
| PulseChain (official) | `https://rpc.pulsechain.com` |
| PublicNode | `https://pulsechain-rpc.publicnode.com` |
| G4mm4 | `https://rpc-pulsechain.g4mm4.io` |

**Read modes (aligned with the audited deposit page):**

- **Automatic (default)** — Before connect: public figures are read **once** from all 3 built-in nodes and shown only if at least 2 agree (`FallbackProvider` quorum); public nodes are **not** polled in the background. After connect: reads go through your **wallet’s own node** only (no address sent to public RPCs). Point your wallet at your own node for fully local reads.
- **Quorum** — Always 2-of-3 cross-check on built-in nodes; never falls back to a single RPC.
- **Single RPC / custom** — Optional; can enable failover to other listed RPCs.
- **Your wallet’s node** — Trust your wallet’s configured PulseChain RPC (not cross-checked).

Mode and failover are stored in `localStorage` under `shd_burn_rpc_prefs_v1`. **Custom RPC URLs are session-only** (not written to `localStorage`, which can retain API keys); legacy custom URLs are scrubbed on load.

**Transactions always go through your wallet’s provider.** This selector only affects read-only data (totals, balances, Buy & Burn stats, quotes).

---

## Browser & wallet requirements

- Modern browser with JavaScript enabled
- A PulseChain-compatible wallet (e.g. MetaMask configured for chain ID 369)
- For mobile: open the page inside a wallet’s in-app browser. If no wallet is detected, the page shows a copy-this-address box so you can paste the URL there yourself (no third-party redirect).

---

## Tech notes

- **Stack:** Vanilla HTML / CSS / JS + inlined [ethers.js](https://docs.ethers.org/) v6.13.5 (UMD, unmodified)
- **No dependencies to install** and no bundler
- **CSP:** `script-src` / `style-src` use SHA-256 hashes of the inlined scripts and styles. If you edit the HTML/JS/CSS, you must recompute those hashes or the browser will block the page.
- **Trusted Types / anti-framing:** The page refuses to render inside a foreign frame and tries to break out when framed.

---

## Disclaimer

This software is provided as-is. Burning tokens and sending PLS to Buy & Burn are **irreversible**. Use at your own risk. Always double-check network, contract addresses, and amounts in your wallet before confirming a transaction.

---

## License & project

Part of the [SnipeHead](https://github.com/PBaieck-group/SnipeHead) project.

Burn page version: **v1.14**
