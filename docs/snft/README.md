# SnipeHead NFT

A 35-unit NFT development on **PulseChain Mainnet** (Chain ID 369), released one unit at a time, in order. This folder is the minting site: a single static `index.html` with no build step, no backend and no CDN.

**Live site:** https://snipehead.xyz/snft/ 

**Version:** v2.0.0

## How the sale works

- Units mint strictly in sequence: Unit 001, then 002, then 003, and so on.
- Two units per wallet maximum.
- One flat price for every unit, paid in PLS.
- These rules are enforced by the contract. The page only displays and calls them.

## Contract

| | |
|---|---|
| Network | PulseChain Mainnet, Chain ID 369 |
| Address | `0x4A345c962DFA2492023a1D19bc88062B532a43c3` |
| Explorer | https://ipfs.scan.pulsechain.com/address/0x4A345c962DFA2492023a1D19bc88062B532a43c3?tab=contract |

Always check the contract address against this README and the explorer before sending funds.

## What the page does

**Reading**
- By default it asks all three built-in PulseChain RPC endpoints and only accepts an answer a majority (2 of 3) agree on.
- You can pick a single endpoint or paste your own `https://` RPC. A custom RPC is verified to be chain 369, needs a confirmation, and is kept for the current tab only.
- Contract state and token owners are batched into one call through Multicall3 (`0xcA11bde05977b3631167028862bE2a173976CA11`) when available.
- Reads are all-or-nothing. If anything fails to load, the page shows an error state instead of made-up values, and claiming is disabled.

**Minting** (`mint(quantity)`, with `value = price × quantity`)

Before a transaction is sent, the page:
1. confirms the wallet is on PulseChain (369),
2. re-reads the mint price through the wallet's own provider and refuses to send if it differs from what was displayed,
3. re-reads `totalMinted`, `mintingActive`, the wallet limit and supply through the wallet's provider, and refuses to send if the unit on screen is no longer the next one or the quantity is no longer allowed.

If a check fails, nothing is sent and the listing is refreshed. A very small window remains between the last check and confirmation; only the contract can fully close it.

**Security**
- A strict Content-Security-Policy is set via `<meta>`, with the inline scripts allowed by SHA-256 hash and no external scripts, fonts or images.
- The page hides itself if it is loaded inside a frame (anti-clickjacking).
- ethers.js v6.15.0 is inlined in `index.html`, so there is no third-party script loading.

## Repository layout

```
.
├── index.html        # the whole app (HTML, CSS, JS, inlined ethers.js)
├── images/           # full-size PNGs, 001.png to 035.png
├── images-web/       # web-optimised WebP thumbnails, 001.webp to 035.webp
├── metadata/         # token metadata, 001.json to 035.json
├── Logo_200.png
├── Logo_500.png
├── IM.png            # Internet Money Wallet logo (wallet prompt)
└── zkx.png           # ZKX Wallet logo (wallet prompt)
```

## Run locally

Serve the folder over HTTP. Opening `index.html` straight from disk will not load the metadata correctly.

```bash
cd docs/snft
python3 -m http.server 8080
# open http://localhost:8080
```

## Configuration

Settings live in the `CONFIG` object at the top of the main script in `index.html`:

| Key | Purpose |
|---|---|
| `contractAddressRaw` | NFT contract address |
| `rpcEndpoints` | built-in RPC endpoints used for quorum reads |
| `rpcUrl` | RPC suggested to wallets when adding PulseChain |
| `explorer` | block explorer base URL used for links |
| `metadataFolder`, `imagesFolder`, `thumbsFolder` | asset folders |
| `fallbackMaxSupply` | supply shown until the contract is read |

## Editing `index.html`: update the CSP hash

The Content-Security-Policy lists a SHA-256 hash for each inline `<script>`. **If you change any inline script, its hash changes and the browser will block it**, which leaves a blank or broken page. After any edit to a script, recompute the hashes and update the `script-src` list in the CSP `<meta>` tag.

```python
import re, hashlib, base64
src = open('index.html', encoding='utf-8').read()
for s in re.findall(r'<script>(.*?)</script>', src, flags=re.S):
    print('sha256-' + base64.b64encode(hashlib.sha256(s.encode('utf-8')).digest()).decode())
```

The script contents must be hashed exactly as written, including whitespace. Changing styles or markup does not affect the hashes.

## Deploying to IPFS

- Pin the whole folder so the relative paths to `images/`, `images-web/` and `metadata/` keep working.
- Test on every gateway you plan to link to. The CSP uses `'self'`, and gateways differ in how they serve paths.
- Check what the contract's `tokenURI` points to. Wallets and marketplaces read token metadata from that URL, not from this page, so it must keep resolving after the move.

## Wallets

The site works with any wallet that injects `window.ethereum`. The wallet prompt links to:
- MetaMask: https://metamask.io/download/
- ZKX Wallet: https://zkxwallet.com/
- Internet Money Wallet: https://internetmoney.io/

## Changelog

### v2.0.0
- Before sending a mint, re-checks the next unit, minting status and the wallet's allowed quantity against fresh chain state, so a stale "Unit NNN" label can no longer be minted after someone else claims it first.
- Fixed the undefined `--mono` CSS variable in the footer.
- Updated the CSP hash for the changed script.

## Disclaimer

This is experimental software for a digital collectible. NFTs and PLS can lose value, blockchain transactions are irreversible, and nothing here is financial advice. Verify the contract address yourself and only mint with funds you can afford to lose.
