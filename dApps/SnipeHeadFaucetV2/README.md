<div align="center">

# 🪙 SnipeHead Faucet

**A single-file, zero-dependency, self-hostable faucet for claiming SHD on PulseChain.**

No build step. No backend. No CDN. No remote fonts. No point of failure but your own hard drive.

![No dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)
![No backend](https://img.shields.io/badge/backend-none-blue)
![License](https://img.shields.io/badge/license-MIT-informational)
![Version](https://img.shields.io/badge/version-2.1.2-blue)

</div>

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [What's actually in the app](#whats-actually-in-the-app)
- [File layout](#file-layout)
- [Quick start](#quick-start)
- [Forking / keeping a local copy](#forking--keeping-a-local-copy)
- [Editing the code](#editing-the-code)
- [If this repo or website ever goes offline](#if-this-repo-or-website-ever-goes-offline)
- [RPC notes](#rpc-notes)
- [License](#license)

---

## Why this exists

Websites disappear. Domains lapse, hosts go down, front-ends get taken offline overnight. This project is built so that can never happen to *you*: nearly everything the app needs lives inside one file, `index.html`, plus a handful of local assets (logo, favicon, and self-hosted fonts) in the same folder.

> **As long as you have this folder and a browser, the app works** — with or without this repo, with or without a live website, with or without the internet (aside from talking to a PulseChain RPC node).

Fork it. Download the whole folder. Put it on a USB stick. It doesn't matter what happens to any hosting site — your copy keeps working.

## What's actually in the app

| Concern | Status |
|---|---|
| Web fonts | ✅ Self-hosted only — Space Grotesk + Space Mono (`.woff2` files in this folder). CSP sets `font-src 'self'` |
| Images | ✅ Local only — `Logo_200.png` (header) and `favicon.png` (tab icon). CSP sets `img-src 'self'` |
| External JS libraries | ❌ None — no ethers.js, no web3.js, no CDN scripts. Minimal hand-written JSON-RPC + 4-byte ABI selectors |
| Analytics / tracking | ❌ None |
| Third-party API calls | ❌ None, except the one thing the app *needs*: your chosen PulseChain RPC |
| RPC provider | ✅ User-selectable dropdown + custom URL + automatic failover when the preferred node fails |
| Script security | ✅ Strict CSP: scripts allowed only by exact SHA-256 hash (no `'unsafe-inline'` for scripts) |

Open `index.html` and check the `Content-Security-Policy` meta tag near the top of `<head>`:

```html
<meta http-equiv="Content-Security-Policy"
  content="default-src 'none';
           script-src 'sha256-7soFFNkhVwtI5TY10DYuRiSYh03MKYQH/Yr8rlvYI0I=';
           style-src 'unsafe-inline';
           connect-src https: http://127.0.0.1:* http://localhost:* http://[::1]:*;
           img-src 'self';
           font-src 'self';
           base-uri 'none';
           form-action 'none';">
```

- `connect-src` is limited to HTTPS RPCs plus loopback HTTP so you can point at a local node.
- Everything else is blocked by default.

### Contract addresses (PulseChain)

| Role | Address |
|---|---|
| Faucet | `0x12a283b6bD04D75c2d83ec110C6E5F91fC34fA98` |
| SHD token | `0xB95bC84f9B6D0373642D586b81979B067572f7bc` |

One claim of **1 SHD** per address. Daily faucet limit is enforced on-chain.

## File layout

Keep everything in the same folder. Relative paths are used for fonts, logo, and favicon.

```
.
├── index.html                          # the entire app (HTML + CSS + JS)
├── Logo_200.png                        # header logo
├── favicon.png                         # browser tab icon
├── space-grotesk-latin-400-normal.woff2
├── space-grotesk-latin-500-normal.woff2
├── space-grotesk-latin-600-normal.woff2
├── space-grotesk-latin-700-normal.woff2
├── space-mono-latin-400-normal.woff2
├── space-mono-latin-700-normal.woff2
├── LICENSE-SpaceGrotesk-OFL.txt        # SIL Open Font License
├── LICENSE-SpaceMono-OFL.txt           # SIL Open Font License
└── README.md
```

Fonts are licensed under the SIL Open Font License (see the two `LICENSE-*.txt` files).

## Quick start

You don't need Node, npm, a build tool, or a backend. Any static file server (or even opening the file directly) works.

### Option 1 — open the file

Double-click `index.html` or drag it into a browser. Done.

> Some wallet extensions behave more reliably over `http://` than `file://`. Prefer Option 2 if connect/claim feels flaky.

### Option 2 — serve it locally

```bash
# Python (already on most systems)
python3 -m http.server 8080

# or Node, no install required
npx serve .
```

Then open `http://localhost:8080`.

### Option 3 — host it anywhere static files are served

GitHub Pages, GitLab Pages, IPFS, Netlify, Cloudflare Pages, your own VPS — it's static files, it doesn't care where it lives.

## Forking / keeping a local copy

1. Clone or download the full folder (all files listed above).
2. There is no `package.json`, no `npm install`, nothing to build.
3. Open or serve `index.html` from that folder.

That’s it. Your local copy is complete and independent of any remote repo or website.

## Editing the code

Everything lives in the single `index.html` file. Useful landmarks:

| Search for | What you’ll find |
|---|---|
| `@font-face` | Self-hosted Space Grotesk / Space Mono definitions |
| `Content-Security-Policy` | The CSP meta tag |
| `DEFAULT_RPCS` | Built-in PulseChain RPC list + failover logic |
| `SEL = {` | The four 4-byte function selectors (claim, balance, daily remaining, hasClaimed) |
| `connectWallet` / `claimTokens` | Wallet connect + claim flow |
| `v2.1.2` | Version string shown in the footer |

**Important:** the page uses a CSP **script hash**. If you change any JavaScript, the hash in the CSP meta tag will no longer match and the browser will block the script. After editing JS you must recompute the SHA-256 of the script body and update the `script-src` value (or temporarily use a looser CSP while developing).

## If this repo or website ever goes offline

That’s the entire point of this architecture — **it doesn’t matter.**

Anyone who saved a copy of this folder can keep running the exact same app indefinitely, on their own machine, with their own choice of RPC node. There is no server this project controls that the app phones home to.

## RPC notes

The app has zero dependency on any single RPC provider, but *you* need a working PulseChain RPC to read state or submit transactions.

Built-in options (with automatic failover):

- PulseChain official (`https://rpc.pulsechain.com`)
- G4mm4
- PublicNode

You can also paste any HTTPS RPC URL (or `http://127.0.0.1` / `localhost` / `[::1]` for a local node). Preferences are stored in `localStorage` under `shd_rpc_prefs_v1`.

If every public RPC is down or rate-limited in your region, run your own node or use any third-party provider and add it via **+ Add custom RPC…**.

## License

MIT for the application code — do whatever you want with it, including running it forever on your own machine.

The Space Grotesk and Space Mono font files are licensed under the SIL Open Font License (see `LICENSE-SpaceGrotesk-OFL.txt` and `LICENSE-SpaceMono-OFL.txt`).

---

<div align="center">
<sub>Built to outlive its own website. · v2.1.2</sub>
</div>
