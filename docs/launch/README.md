# SnipeHead Launch

**Launch Instant or Bonding Curve tokens on PulseChain. Fixed 21M supply. Powered by SHD.**

This is a single-page, client-side web app for creating and trading tokens through the SnipeHead Launch factory on PulseChain.

- **Repo path:** [docs/launch](https://github.com/PBaieck-group/SnipeHead/tree/main/docs/launch)
- **Version:** v1.1.3  
- **Network:** PulseChain (`chainId` 369)  
- **No backend.** The page runs in your browser. Private keys never leave your wallet.

---

## What it does

### 1. Instant launch
Create a token and seed a PulseX pair in one flow (create + seed + unlock). Suited to teams that want a pool live immediately.

### 2. Bonding curve
Open a curve until a graduation target is reached. Anyone can buy and sell along the curve. When the target is hit, the token can **graduate** to PulseX liquidity.

### 3. Trade, portfolio, watchlist
- Browse launches, search, sort, and open a token page (stats, trades, holders, chart where available).  
- **Portfolio** — tokens you hold and recent trades (wallet connected).  
- **Watchlist** — local bookmarks in the browser.

### 4. On-chain constant checks
Numbers shown on the page (supply, graduation target, creator reward / allocation, virtual reserves) are checked against the live contracts at startup. If something disagrees, **Buy / Sell / Graduate are paused** until the page matches the chain (fail closed).

---

## Features

| Feature | Notes |
|--------|--------|
| **Wallet connect** | Injected wallets; network switch / add PulseChain when needed. |
| **Instant & curve modes** | Two creation paths from the same factory. |
| **Graduate** | Move a completed curve to PulseX liquidity. |
| **RPC selector** | Built-in public RPCs + optional custom RPC; used for reads (lists, balances, quotes). Transactions still use the wallet’s network settings. |
| **Token pages** | Trades, holders, stats; soft refresh while the tab is open. |
| **Logo upload** | Image for the token at create time (validated client-side). |
| **Terms gate** | First-visit terms acknowledgment stored locally. |
| **Strict CSP** | Script hashes (no `unsafe-inline` for scripts); event **delegation** via `data-click` / `data-change` (no inline handlers). |
| **Anti-clickjacking** | Page stays hidden unless top-level (`frameGuard`). Prefer host `frame-ancestors` / `X-Frame-Options` as well. |
| **Referrer policy** | `no-referrer`. |

---

## Contracts (PulseChain)

| Role | Address |
|------|---------|
| **Factory** | `0x60eB086a1b15eDADd73351d6Da128F3fB64F6Cb0` |
| **SHD token** | `0xB95bC84f9B6D0373642D586b81979B067572f7bc` |
| **PulseX V2 factory** | `0x29eA7545DEf87022BAdc76323F373EA1e707C523` |
| **Buy & Burn** | `0x3677e61A7a9E79Fe45a882C201365C5165A5540e` |

Explorer base: [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com)

Always compare addresses on the page with the explorer before signing.

---

## Curve parameters (reference)

Displayed and calculated values come from config and are verified on-chain. Nominal mainnet curve config in this build:

| Parameter | Value (human) |
|-----------|----------------|
| Fixed supply | 21,000,000 |
| Graduation target | 5,000,000 SHD (nominal) |
| Creator allocation | 5% (`creatorAllocBps` = 500) |
| Creator reward | 50,000 SHD (nominal) |

If the page and contract disagree, trading actions are blocked.

**You need SHD** to create tokens and to trade on this UI.

---

## Security notes

- **Anyone can launch.** Names, symbols, and logos are **not** verified. Tokens can be malicious or worthless.  
- **Smart contracts are immutable.** Wrong or hostile transactions cannot be reversed.  
- **Memecoins are extremely volatile** and can go to zero.  
- This is **not financial advice.** Only use funds you can afford to lose.  
- Prefer opening the page from a host you trust, or **self-host** the HTML (below).  
- After any edit to an inline `<script>` block, regenerate CSP hashes (see project `csp-hash.py` / comment at top of `index.html`).

---

## Run it yourself (decentralized / local)

The app is static files. You do not need a custom server backend.

### Option A — Clone and open locally

```bash
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/docs/launch
```

Serve the folder over HTTP (wallets and some browser APIs expect a real origin, not only `file://`):

```bash
# Python 3
python3 -m http.server 8080

# or Node
npx --yes serve -l 8080
```

Open `http://127.0.0.1:8080` (or the path where `index.html` lives).

### Option B — GitHub Pages / your domain

Point the site root (or a subpath) at this directory so `index.html` is served with your CSP and, ideally, `frame-ancestors` / `X-Frame-Options` via host headers (e.g. `_headers` on the host).

### Option C — IPFS

Add the built folder to IPFS and open the gateway or IPFS-native URL. Behavior depends on gateway CSP; for maximum control, use your own gateway or local node.

---

## RPC nodes

Built-in defaults (reads):

| Name | URL |
|------|-----|
| PulseChain (official) | `https://rpc.pulsechain.com` |
| PublicNode | `https://pulsechain.publicnode.com` |
| G4mm4 | `https://rpc-pulsechain.g4mm4.io` |

Signing and broadcasting still use **your wallet’s** configured PulseChain RPC.

> Note: this launch build’s CSP `connect-src` may be broader than the burn/deposit pages. If you fork for maximum lockdown, narrow `connect-src` to the RPC list you actually use and refresh script hashes.

---

## Development / CSP

- Inline scripts are pinned with **SHA-256** in the CSP `script-src` list.  
- UI actions use **event delegation** (`data-click`, `data-change`, `data-input`, `data-enter`) so markup does not need inline `onclick` handlers.  
- After changing any inline script contents, run the project hash helper (see the HTML comment):

  ```bash
  python3 csp-hash.py index.html
  ```

---

## Disclaimer

SnipeHead Launch is provided as-is. Creating or trading tokens can result in total loss. The authors and host operators are not responsible for third-party tokens, smart-contract risk, or wallet misuse. DYOR.

---

## Links

- **GitHub (this UI):** https://github.com/PBaieck-group/SnipeHead/tree/main/docs/launch  
- **SnipeHead:** https://snipehead.xyz/  
- **PulseChain:** https://pulsechain.com/  
