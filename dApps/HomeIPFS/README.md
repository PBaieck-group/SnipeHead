# SnipeHead Home (IPFS)

> **Decentralized entry point to the entire SnipeHead ecosystem.**  
> One IPFS-hosted portal → every major SHD dApp on IPFS, plus live dashboard data on PulseChain.

This page is the **IPFS home base** for SnipeHead (SHD). From here, users can reach the full stack without depending on a single centralized host:

- **Faucet, Mining, SNFT, Deposit, Buy & Burn** — each linked to its own IPFS deployment  
- **Live dashboard** — price, market cap, supply/burns, recent swaps & burns, PulseChain core stats  
- **Trade / bridge** — PulseX and the PulseChain bridge (IPFS-friendly frontends where available)

**Exception:** [Pump.Tires](https://pump.tires/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc/) (original launch page) has no IPFS mirror; that link remains on their domain only.

| | |
|---|---|
| **Network** | PulseChain (chain ID `369`) |
| **Canonical site** | [snipehead.xyz](https://snipehead.xyz/) |
| **Live (IPFS)** | [Open HomeIPFS](https://bafybeifub2qckcf6derqeaczdcpxxmpwsjrkjaqsbaa3kld5blktygyra4.ipfs.inbrowser.link/) |
| **Repo path** | [`dApps/HomeIPFS`](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/HomeIPFS) |

---

## What’s included in this folder

| File / folder | Purpose |
|---------------|---------|
| `index.html` | Single-page app (dashboard + scripts) |
| `styles.css` | Compiled Tailwind CSS |
| `input.css` | Tailwind entry (`@tailwind` directives) |
| `favicon.png` | Site icon |
| `Logo_200.png` / `Logo_500.png` | Brand assets |
| `3d_logo/` | Optional 3D logo assets |

No build step is required to run the site. Open `index.html` via any static server (or IPFS). Rebuild `styles.css` from `input.css` only if you change Tailwind classes.

---

## Features

### Dashboard
- Hero intro and primary CTAs (claim, mine, trade, etc.)
- Live **SHD price**, market cap, supply after burns, faucet & mining stats
- Responsive topbar ticker (PLS, SHD, age, and optionally BTC/ETH when space allows)
- Collapsible sidebar navigation (works on mobile and desktop)

### Markets & chart
- Price / market data cards
- Embedded chart & swap area (PulseX / DexScreener-style embeds where applicable)

### Recent transactions
- Live **buys, sells, and burns** from SHD/WPLS pools (V1 & V2) plus token burns
- USD value, SHD amount, WPLS, price, pool, trader, block
- Links out to [PulseChain Scan](https://ipfs.scan.pulsechain.com)
- Manual reload + automatic polling (pauses when the tab is hidden)

### PulseChain core
- On-chain and network-oriented stats for the broader PulseChain context

### Network tools
- **RPC node picker** — built-in PulseChain RPCs + custom HTTPS endpoints, optional failover
- Add PulseChain network to wallet
- Add SHD token to wallet
- Copy contract address

### Ecosystem shortcuts (sidebar) — decentralization hub

This portal is designed so the **core SHD tools stay reachable via IPFS**, even if snipehead.xyz or GitHub are down. Sidebar links:

| Destination | Hosting | Notes |
|-------------|---------|--------|
| **Faucet V2** | IPFS | Claim starter SHD |
| **Mining V2** | IPFS | Stake / mine SHD |
| **SNFT** | IPFS | NFT collection dApp |
| **Deposit** | IPFS | Fund mining reward reserve (non-refundable) |
| **Buy & Burn** | IPFS | Direct burn + PLS → SHD burn |
| **PulseX** | IPFS-oriented frontend | Trade SHD (`ipfs.app.pulsex.com`) |
| **PulseChain Bridge** | IPFS-oriented frontend | `ipfs.bridge.pulsechain.com` |
| **Pump.Tires** | Centralized only | Launch page — **no IPFS version**; kept for historical/reference access |

Pinning **HomeIPFS** plus the linked dApp CIDs keeps the ecosystem usable in a decentralized way. Update sidebar URLs in `index.html` when you publish new IPFS builds.

---

## Contract & pool addresses (used by the page)

| Item | Address |
|------|---------|
| **SHD Token** | `0xb95bc84f9b6d0373642d586b81979b067572f7bc` |
| **Mining V2** | `0xa16C1FA26F13803083f0fd222D1EA083c1d6D650` |
| **Faucet V2** | `0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98` |
| **SNFT** | `0x4A345c962DFA2492023a1D19bc88062B532a43c3` |
| **WPLS** | `0xA1077a294dDE1B09bB078844df40758a5D0f9a27` |
| **SHD/WPLS pair V1** | `0xB5b4Be04D13e101524F7c57F2eBe2154a58C5DB8` |
| **SHD/WPLS pair V2** | `0x6d8a9F5726A5e67aC1Cd7F558Fe5B289e95ba232` |
| **Multicall3** | `0xcA11bde05977b3631167028862bE2a173976CA11` |

Burn sinks counted toward “burned” supply: `0x000…000` and `0x000…dead`.  
Initial supply used for burn math: **1,000,000,000 SHD**.

Always verify addresses on-chain before interacting with linked dApps.

---

## Built-in RPCs

| Name | URL |
|------|-----|
| PulseChain (official) | `https://rpc.pulsechain.com` |
| G4mm4 | `https://rpc-pulsechain.g4mm4.io` |
| PublicNode | `https://pulsechain-rpc.publicnode.com` |
| PulseChainStats | `https://rpc.pulsechainstats.com` |

Users can add their own **HTTPS** RPC (CORS-enabled) in the RPC modal. Preferences are stored in `localStorage`. Failover can be toggled in the UI.

---

## Data sources

- **On-chain** — balances, total supply, burns, mining/faucet reads, swap & burn logs via the selected RPC + Multicall3
- **Prices** — DexScreener, CoinGecko, CryptoCompare, Coinbase (as configured in the page)
- **Explorer** — [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com) / related PulseChain APIs for supplemental data

Polling is staggered and paused when the document is hidden to reduce load and rate limits.

---

## Local usage

```bash
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/dApps/HomeIPFS

# Any static server
npx serve .
# or
python3 -m http.server 8080
```

Open `http://localhost:8080` (or the port your server prints).

### Optional: rebuild CSS

If you edit Tailwind classes in `index.html` or `input.css`:

```bash
# From this folder, with Tailwind CLI available
npx tailwindcss -i ./input.css -o ./styles.css --minify
```

The shipped `styles.css` is already built for the current markup.

---

## IPFS / decentralized access

**This site’s role:** act as the IPFS front door to the SnipeHead ecosystem. The live build:

**https://bafybeifub2qckcf6derqeaczdcpxxmpwsjrkjaqsbaa3kld5blktygyra4.ipfs.inbrowser.link/**

Other gateways (example):

```
https://ipfs.io/ipfs/bafybeifub2qckcf6derqeaczdcpxxmpwsjrkjaqsbaa3kld5blktygyra4
```

When pinning, include the full folder contents (`index.html`, CSS, logos, favicon, and any assets under `3d_logo/`) so relative paths resolve.

Recommended companion pins (linked from the sidebar):

| dApp | Example CID / gateway |
|------|------------------------|
| Faucet | `bafybeifst4rflwie3ya4jdh2sa7epopsktrl74ehjziyjmd5k56d3pq64i` |
| Mining | `bafybeicf2oyipvxodm672pa3fvijijknxskd7yitqbe2fjr2n3aasq7fwu` |
| SNFT | `bafybeic3pyupjv7kipmbuwqjodeqffe27noq2kyv7zh32qwmphrue6tup4` |
| Deposit | `bafybeiatqofllwicbokkdhldzdztmf2figiyqntz62xuw5phpa2cf2pcqy` |
| Buy & Burn | `bafybeicsxvytyje2tzqu5ubbparwsqeo3mgsy5u2brx3dlbyidhlvy3634` |

Pump.Tires is **not** on IPFS; only the centralized URL is used in the sidebar.

---

## Tech stack

- Vanilla HTML / CSS / JavaScript (no framework runtime)
- [ethers.js v5](https://docs.ethers.org/v5/) (CDN) for RPC, Multicall, logs
- Tailwind CSS (precompiled `styles.css`)
- Google Fonts: Inter + Space Grotesk
- CSP allowing `connect-src https:` so users can point the UI at their own PulseChain RPC
- Responsive shell: fixed sidebar + sticky topbar

---

## Security notes

- The page is **read-oriented** for dashboard data; wallet actions are limited to adding the PulseChain network and the SHD token (via standard `wallet_*` methods). Linked dApps handle deposits, burns, mining, etc.
- Never enter seed phrases or private keys on this site.
- Prefer verifying the IPFS CID when using public gateways.
- Custom RPCs must be HTTPS and allow browser CORS; only use nodes you trust.

---

## Related links

- **Main project:** [github.com/PBaieck-group/SnipeHead](https://github.com/PBaieck-group/SnipeHead)
- **Portal:** [snipehead.xyz](https://www.snipehead.xyz)
- **Token on Scan:** [0xb95bc…f7bc](https://ipfs.scan.pulsechain.com/token/0xb95bc84f9b6d0373642d586b81979b067572f7bc)
- **Trade on PulseX:** [ipfs.app.pulsex.com](https://ipfs.app.pulsex.com/?outputCurrency=0xb95bc84f9b6d0373642d586b81979b067572f7bc)
- **dApps:** [Deposit](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/Deposit) · [BuyAndBurn](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/BuyAndBurn) · [Faucet](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeHeadFaucetV2) · [Mining](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SnipeheadMiningDecentralizedV2) · [SNFT](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/SNFT)

---

## Disclaimer

This dashboard is provided for informational and community use. Market data and on-chain reads can lag or fail depending on RPC and third-party APIs. Always do your own research (DYOR) before interacting with any smart contract or trading SHD. The authors and contributors are not responsible for losses from use of this site or linked tools.

---

**SnipeHead · PulseChain · Home / IPFS portal**
