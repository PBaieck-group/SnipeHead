<div align="center">

# ⛏️ SnipeHead Mining

**A single-file, zero-dependency, self-hostable mining dApp for SHD on PulseChain.**

No build step. No backend. No CDN. No fonts pulled from the internet. No point of failure but your own hard drive.

![No dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)
![No backend](https://img.shields.io/badge/backend-none-blue)
![License](https://img.shields.io/badge/license-MIT-informational)
![PRs welcome](https://img.shields.io/badge/PRs-welcome-orange)

</div>

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [What's actually in the file](#whats-actually-in-the-file)
- [Quick start](#quick-start)
- [Forking this repo](#forking-this-repo)
- [Editing the code](#editing-the-code)
- [If this repo or website ever goes offline](#if-this-repo-or-website-ever-goes-offline)
- [A note on the RPC endpoint](#a-note-on-the-rpc-endpoint)
- [License](#license)

---

## Why this exists

Websites disappear. Domains lapse, hosts go down, front-ends get taken offline overnight. This project is built so that can never happen to *you*: everything the app needs to run lives inside one file, `index.html`.

> **As long as you have a copy of that file and a browser, the app works** — with or without this repo, with or without a live website, with or without the internet (aside from talking to an RPC node).

Fork it. Download it. Put it on a USB stick. It doesn't matter what happens to this GitHub repo or any site hosting it — your copy keeps working.

## What's actually in the file

| Concern | Status |
|---|---|
| Web fonts | ❌ None — `Inter` / `Exo 2` are named in the CSS but never fetched; falls back to your OS's default fonts |
| Images | ❌ None — CSP sets `img-src 'none'` |
| CDN-loaded scripts/styles | ❌ None — ethers.js v5.7.2 and the Tailwind utility CSS are both pasted directly inline, not loaded from a CDN |
| Analytics / tracking | ❌ None |
| Third-party API calls | ❌ None, except the one thing the app *needs*: your chosen PulseChain RPC |
| RPC provider | ✅ **User-selectable** — pick from a dropdown or paste your own custom RPC URL, remembered locally for next time |

Don't take our word for it — open `index.html` and check the `Content-Security-Policy` meta tag, it's the first thing in `<head>`:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src https:; img-src 'none'; font-src 'none';">
```

`connect-src https:` is the only network permission the page has — and that's used exclusively for talking to whichever RPC endpoint *you* choose.

### A note on your RPC preference

This app remembers your chosen RPC endpoint using `localStorage` so you don't have to re-select it on every visit. That preference **never leaves your browser** — it isn't sent anywhere, isn't synced to any server, and doesn't compromise the "fully self-contained" nature of this app. It's purely a local convenience.

## Quick start

You don't need Node, npm, a build tool, or a server. Pick whichever you're comfortable with.

📁 All commands below assume your terminal is inside `dApps/SnipeheadMiningDecentralizedV2/` — the folder that actually contains `index.html`.

### Option 1 — just open the file

Double-click `index.html`, or drag it into your browser. Done.

### Option 2 — serve it locally

Some browser wallet extensions (MetaMask, etc.) behave better over `http://` than `file://`. Any static file server works:

```bash
# Python (already on most systems)
python3 -m http.server 8080

# or Node, no install required
npx serve .
```

Then visit `http://localhost:8080`.

### Option 3 — host it anywhere static files are served

GitHub Pages, IPFS, Netlify, Cloudflare Pages, your own VPS — it's one HTML file, it doesn't care where it lives.

## Forking this repo

1. Click **Fork** ↗️ in the top right of [PBaieck-group/SnipeHead](https://github.com/PBaieck-group/SnipeHead).
2. Clone your fork and go straight to this dApp's folder — note it lives in a subdirectory, not the repo root:
   ```bash
   git clone https://github.com/<your-username>/SnipeHead.git
   cd SnipeHead/dApps/SnipeheadMiningDecentralizedV2
   ```
3. That's it. There's no `npm install`, no `package.json`, nothing to build. Open `index.html` and it runs.

## Editing the code

Everything — HTML, CSS, and JS — lives in the single `index.html` file. Useful landmarks to search for:

| Section | What's there |
|---|---|
| `<style>` block near the top | Tailwind utility CSS (inlined) plus custom page styling |
| `rpcSelect`, `customRpcInput`, `addRpcButton`, `cancelRpcButton` | RPC dropdown + custom RPC input UI and logic |
| `RPC_PREF_STORAGE_KEY` | Local `localStorage` persistence of the user's chosen RPC |
| The giant minified block starting with `/* ethers.js v5.7.2 (self-hosted) */` | The vendored ethers.js library — you shouldn't need to touch this |
| Below the ethers.js bundle | App-specific logic: wallet connect, mining/staking flow, contract calls |

## If this repo or website ever goes offline

That's the entire point of this architecture — **it doesn't matter.**

Anyone who saved a copy of `index.html`, or forked this repo before it disappeared, can keep running the exact same app indefinitely, on their own machine, with their own choice of RPC node. There is no server this project controls that the app phones home to.

## A note on the RPC endpoint

The app has zero dependency on any single RPC provider — but *you* do need a working PulseChain RPC somewhere to read balances, mining stats, or submit transactions. If every public RPC in the dropdown is down, rate-limited, or blocked in your region:

- Run your own PulseChain node, **or**
- Use any third-party RPC provider (free or paid) and paste its URL into the **custom RPC** field.

The app keeps working as long as any valid RPC URL is reachable from your browser.

## License

MIT — do whatever you want with this, including running it forever on your own machine. See [`LICENSE`](LICENSE) for details.

---

<div align="center">
<sub>Built to outlive its own website.</sub>
</div>
