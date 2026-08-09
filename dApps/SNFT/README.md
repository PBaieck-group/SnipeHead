<div align="center">

# 🎯 SnipeHead NFT

**A self-hostable minting front-end for the 35-unit SnipeHead NFT collection on PulseChain.**

No build step. No backend. No CDN. No fonts pulled from the internet.  
Everything the page needs lives in this folder — open it and it works.

![No build step](https://img.shields.io/badge/build-none-brightgreen)
![No backend](https://img.shields.io/badge/backend-none-blue)
![PulseChain](https://img.shields.io/badge/chain-PulseChain%20(369)-orange)
![License](https://img.shields.io/badge/license-MIT-informational)
![PRs welcome](https://img.shields.io/badge/PRs-welcome-orange)

</div>

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [What's in this folder](#whats-in-this-folder)
- [How the collection works](#how-the-collection-works)
- [Quick start](#quick-start)
- [Forking this repo](#forking-this-repo)
- [Editing the code](#editing-the-code)
- [If this repo or website ever goes offline](#if-this-repo-or-website-ever-goes-offline)
- [A note on the RPC endpoint](#a-note-on-the-rpc-endpoint)
- [Contract](#contract)
- [License](#license)

---

## Why this exists

Websites disappear. Domains lapse, hosts go down, front-ends get taken offline overnight. This project is built so that can never happen to *you*: the minting UI, the artwork, the metadata, and the contract interface all live in this folder.

> **As long as you have a copy of this folder and a browser, the app works** — with or without this repo, with or without a live website, with or without the internet (aside from talking to an RPC node and your wallet).

Fork it. Download it. Put it on a USB stick. It doesn't matter what happens to this GitHub repo or any site hosting it — your copy keeps working.

## What's in this folder

| File / folder | Purpose |
|---|---|
| `index.html` | The entire front-end (HTML + CSS + JS + self-hosted ethers.js v6) |
| `metadata/` | 35 JSON files (`001.json` … `035.json`) — name, description, attributes |
| `images/` | 35 full-resolution PNG artworks (`001.png` … `035.png`) — used for the detail/modal view |
| `images-web/` | 35 resized WebP thumbnails (`001.webp` … `035.webp`) — used for the gallery grid, much faster to load |
| `Logo_200.png` | Small logo used in the nav and wallet modal |
| `Logo_500.png` | Larger logo asset (available for other uses) |

| Concern | Status |
|---|---|
| Web fonts | ❌ None — falls back to your OS's default fonts |
| CDN-loaded scripts | ❌ None — ethers.js v6.15.0 is pasted directly into a `<script>` tag |
| Analytics / tracking | ❌ None |
| Third-party API calls | ❌ None, except the one thing the app *needs*: your chosen PulseChain RPC |
| RPC provider | ✅ **User-selectable** — pick from a dropdown or paste your own custom RPC URL |
| Images & metadata | ✅ Served from the local `images/`, `images-web/`, and `metadata/` folders |

Don't take our word for it — open `index.html` and check the `Content-Security-Policy` meta tag near the top of `<head>`:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self' https:; img-src 'self'; font-src 'none';">
```

`connect-src 'self' https:` is the only network permission the page has — `'self'` allows the page to load its own local resources, and `https:` is used for talking to whichever RPC endpoint *you* choose. Images are restricted to `'self'` (the local `images/` and `images-web/` folders, plus logos).

## How the collection works

SnipeHead is a **35-piece NFT development** released **strictly in order** on PulseChain Mainnet.

- Units mint 001 → 002 → 003 … → 035.  
  You cannot buy Unit 014 before Unit 013 has sold — the contract enforces it.
- **Maximum 2 units per wallet** (on-chain limit).
- **One flat listing price** paid in PLS. No auctions, no bidding.
- Only the next unit in sequence is available at any time.

The front-end reads live state from the contract (total minted, price, per-wallet count, owners) and shows:

- Available / Coming Up / Sold status for every unit
- “My NFTs” filter once a wallet is connected
- One-click mint for the current available unit (or up to 2 if your wallet still has room)

## Quick start

You don't need Node, npm, a build tool, or a server. Pick whichever you're comfortable with.

📁 All commands below assume your terminal is inside the folder that contains `index.html`, `metadata/`, `images/`, and `images-web/`.

### Option 1 — just open the file

Double-click `index.html`, or drag it into your browser.  
(Some wallet extensions work better over `http://` — see Option 2 if MetaMask complains.)

### Option 2 — serve it locally

```bash
# Python (already on most systems)
python3 -m http.server 8080

# or Node, no install required
npx serve .
```

Then visit `http://localhost:8080`.

### Option 3 — host it anywhere static files are served

GitHub Pages, IPFS, Netlify, Cloudflare Pages, your own VPS — it's static files, it doesn't care where it lives.  
Just keep the folder structure intact (`index.html` next to `metadata/`, `images/`, and `images-web/`).

## Forking this repo

1. Click **Fork** ↗️ in the top right of the repository.
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/SnipeHead.git
   cd SnipeHead/dApps/SNFTS
   ```
3. That's it. There's no `npm install`, no `package.json`, nothing to build.  
   Open `index.html` (or serve the folder) and it runs.

## Editing the code

Everything for the UI lives in the single `index.html` file. Useful landmarks to search for:

| Section | What's there |
|---|---|
| `<style>` block near the top | All page styling (dark blueprint theme) |
| `RPC SELECTOR` | RPC dropdown + custom RPC input logic |
| The giant minified block starting with `/* ethers.js v6.15.0 (self-hosted, no CDN) */` | The vendored ethers.js library — you shouldn't need to touch this |
| `/* ================= CONFIG ================= */` | Contract address, chain ID, RPC list, folder paths |
| Below the ethers.js bundle | App logic: wallet connect, chain state, gallery, mint flow |

To point at a different contract or change the metadata/image paths, edit the `CONFIG` object near the top of the app script:

```js
const CONFIG = {
  metadataFolder: 'metadata/',
  imagesFolder: 'images/',
  thumbsFolder: 'images-web/',
  contractAddressRaw: '0x4A345c962DFA2492023a1D19bc88062B532a43c3',
  // ...
};
```

Artwork and traits live in the `images/`, `images-web/`, and `metadata/` folders — replace those files if you ever re-issue or update the collection.

> **Note on `images-web/`:** these are resized (600px) WebP copies of the artwork in `images/`, used only for the gallery grid so the page loads fast. The full-resolution PNGs in `images/` are still what's shown in the detail/modal view and are the canonical artwork files. If you replace an image in `images/`, regenerate the matching thumbnail:
> ```bash
> cwebp -q 85 -resize 600 0 images/001.png -o images-web/001.webp
> ```

## If this repo or website ever goes offline

That's the entire point of this architecture — **it doesn't matter.**

Anyone who saved a copy of this folder (or forked the repo before it disappeared) can keep running the exact same minting UI indefinitely, on their own machine, with their own choice of RPC node. There is no server this project controls that the app phones home to.

## A note on the RPC endpoint

The app has zero dependency on any single RPC provider — but *you* do need a working PulseChain RPC somewhere to read chain state or submit transactions. If every public RPC in the dropdown is down, rate-limited, or blocked in your region:

- Run your own PulseChain node, **or**
- Use any third-party RPC provider (free or paid) and paste its URL into the **custom RPC** field.

The app keeps working as long as any valid RPC URL is reachable from your browser.

## Contract

| | |
|---|---|
| **Network** | PulseChain Mainnet (Chain ID `369`) |
| **Contract** | [`0x4A345c962DFA2492023a1D19bc88062B532a43c3`](https://ipfs.scan.pulsechain.com/address/0x4A345c962DFA2492023a1D19bc88062B532a43c3?tab=contract) |
| **Explorer** | [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com) |
| **Max supply** | 35 |
| **Max per wallet** | 2 |
| **Payment** | PLS (native) |

## License

MIT — do whatever you want with this, including running it forever on your own machine. See [`LICENSE`](LICENSE) for details.

---

<div align="center">
<sub>Built to outlive its own website.</sub>
</div>
