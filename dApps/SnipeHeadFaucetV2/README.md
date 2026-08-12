<div align="center">

# 🪙 SnipeHead Faucet

**A single-file, zero-dependency, self-hostable faucet for claiming SHD on PulseChain.**

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

Websites disappear. Domains lapse, hosts go down, front-ends get taken offline overnight. This project is built so that can never happen to *you*: nearly everything the app needs to run lives inside one file, `index.html` — the only companions it needs are two small local image files, `Logo_200.png` and `favicon.png`, sitting in the same folder.

> **As long as you have those three files and a browser, the app works** — with or without this repo, with or without a live website, with or without the internet (aside from talking to an RPC node).

Fork it. Download it. Put the whole folder on a USB stick. It doesn't matter what happens to this GitHub repo or any site hosting it — your copy keeps working.

## What's actually in the file

| Concern | Status |
|---|---|
| Web fonts | ❌ None — falls back to your OS's default fonts |
| Images | ✅ Two local files only — `Logo_200.png` (header) and `favicon.png` (browser tab). CSP sets `img-src 'self'`, so no remote images can load |
| CDN-loaded scripts | ❌ None — ethers.js v5.7.2 is pasted directly into a `<script>` tag |
| Analytics / tracking | ❌ None |
| Third-party API calls | ❌ None, except the one thing the app *needs*: your chosen PulseChain RPC |
| RPC provider | ✅ **User-selectable** — pick from a dropdown or paste your own custom RPC URL |

Don't take our word for it — open `index.html` and check the `Content-Security-Policy` meta tag, it's the first thing in `<head>`:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src https:; img-src 'self'; font-src 'none';">
```

`connect-src https:` is the only network permission the page has — and that's used exclusively for talking to whichever RPC endpoint *you* choose.

## Quick start

You don't need Node, npm, a build tool, or a server. Pick whichever you're comfortable with.

📁 All commands below assume your terminal is inside `dApps/SnipeHeadFaucetV2/` — the folder that actually contains `index.html`, `Logo_200.png`, and `favicon.png`. Keep all three together; the logo and tab icon are loaded as relative paths.

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
2. Clone your fork and go straight to the faucet's folder — note this app lives in a subdirectory, not the repo root:
   ```bash
   git clone https://github.com/<your-username>/SnipeHead.git
   cd SnipeHead/dApps/SnipeHeadFaucetV2
   ```
3. That's it. There's no `npm install`, no `package.json`, nothing to build. Open `index.html` and it runs.

> 📁 **Path note:** every command below (`python3 -m http.server`, `npx serve .`, etc.) assumes you're standing inside `dApps/SnipeHeadFaucetV2/` — that's where `index.html` actually is.

## Editing the code

Everything — HTML, CSS, and JS — lives in the single `index.html` file. Useful landmarks to search for:

| Section | What's there |
|---|---|
| `<style>` block near the top | All page styling |
| `RPC SELECTOR` | RPC dropdown + custom RPC input logic |
| The giant minified block starting with `/* ethers.js v5.7.2 (self-hosted) */` | The vendored ethers.js library — you shouldn't need to touch this |
| Below the ethers.js bundle | App-specific logic: wallet connect, claim flow, contract calls |

## If this repo or website ever goes offline

That's the entire point of this architecture — **it doesn't matter.**

Anyone who saved a copy of `index.html`, or forked this repo before it disappeared, can keep running the exact same app indefinitely, on their own machine, with their own choice of RPC node. There is no server this project controls that the app phones home to.

## A note on the RPC endpoint

The app has zero dependency on any single RPC provider — but *you* do need a working PulseChain RPC somewhere to read balances or submit transactions. If every public RPC in the dropdown is down, rate-limited, or blocked in your region:

- Run your own PulseChain node, **or**
- Use any third-party RPC provider (free or paid) and paste its URL into the **custom RPC** field.

The app keeps working as long as any valid RPC URL is reachable from your browser.

## License

MIT — do whatever you want with this, including running it forever on your own machine. See [`LICENSE`](LICENSE) for details.

---

<div align="center">
<sub>Built to outlive its own website.</sub>
</div>
