# SnipeHead NFT: Ethereum mint site

The static mint page for **SnipeHeadNFT** on **Ethereum Mainnet** (Chain ID 1).

- **Live site:** https://snipehead.xyz/snft-eth/
- **PulseChain version:** https://snipehead.xyz/snft/
- **Contract:** [`0xE85eB0a14E185968B2a947d98feA023F8e80AB3a`](https://etherscan.io/address/0xE85eB0a14E185968B2a947d98feA023F8e80AB3a)
- **Contract source:** [SnipeHeadNFT.sol](https://github.com/PBaieck-group/SnipeHead-eth/blob/main/src/SnipeHeadNFT.sol)
- **Version:** v2.0.0

## What it is

A 35-unit NFT development, released one lot at a time, in order: Unit 001, then 002, then 003, and so on. Each wallet can claim up to two units, and every unit costs the same listing price, paid in ETH. All of these rules are enforced by the contract. The page only reads the contract and sends the mint transaction.

## How the page works

The whole site is a single self-contained HTML file. There is no backend, no build step and no framework. [ethers.js](https://docs.ethers.org/v6/) v6 is inlined in the file, so nothing is loaded from a CDN.

- **Reads:** supply, price, minting status, owners and your counts are fetched from the contract and batched through [Multicall3](https://www.multicall3.com/) to keep the number of RPC calls low.
- **Writes:** the only transaction the page sends is `mint(quantity)`, signed in your own wallet.
- **Metadata and images:** served as static files from the same folder (`metadata/`, `images/`, `images-web/`).

## Security and decentralization

- **No single point of trust for reads.** By default the page asks three public RPC endpoints (PublicNode, 1RPC, 0xRPC) and only accepts an answer that a majority agree on. You can also pick one endpoint or paste your own. A custom RPC is kept for the current tab only, is checked to be on chain 1 before use, and shows a warning, because that server decides what the page displays.
- **Wallet first.** With a wallet connected, reads go through your wallet before the RPC.
- **Re-checked before sending.** `mint()` re-reads the price and the live unit state through your wallet's own provider and refuses to send if anything differs from what the page showed. It also confirms the wallet is on Ethereum Mainnet and that your balance covers the cost. A failed check sends nothing.
- **No fake data.** If a read fails, the page says so instead of showing 0 or guessing.
- **Escaped metadata.** Names and traits from the metadata files are HTML-escaped before they are shown.
- **Strict Content-Security-Policy.** The three inline scripts are pinned by SHA-256 hash, so no other script can run. `base-uri`, `form-action`, `object-src` and `frame-src` are all `'none'`.
- **Anti-clickjacking.** The page hides itself and tries to break out if it is loaded inside a frame.
- **Referrer privacy.** The page sends no referrer, and external links use `rel="noopener noreferrer"`.
- **Separate storage.** RPC choices are saved under `snipehead:eth:*`, so this page and the PulseChain page never overwrite each other's settings.

## Folder contents

| Path | Purpose |
| --- | --- |
| `index.html` | The mint page (the file served at `/snft-eth/`) |
| `Logo_200.png` | Logo and favicon |
| `metamask.png`, `zkx.png`, `IM.png` | Wallet logos for the connect dialog |
| `images/` | Full-size unit images (001-035) |
| `images-web/` | Web-sized thumbnails shown in the grid |
| `metadata/` | ERC-721 metadata JSON (001-035) |

The page expects those folder names. They are set at the top of the script in `CONFIG` (`metadataFolder`, `imagesFolder`, `thumbsFolder`).

## Run it yourself

You don't need `snipehead.xyz` to use this page. It is plain static files with no install step, no Node and no build, and a copy you run yourself talks to the same contract.

**1. Get the files**

```bash
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/docs/snft-eth
```

Or download the folder from GitHub as a ZIP and unzip it.

**2. Serve the folder over HTTP**

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000 in a browser with a wallet extension such as MetaMask. Any static file server works the same way, for example `npx serve`.

Don't open `index.html` by double-clicking it. Most browsers block a `file://` page from loading the `metadata/` files, and some wallets don't inject themselves into `file://` pages.

**3. Host it elsewhere (optional)**

Upload the whole folder to any static host, such as GitHub Pages, Netlify, your own server or IPFS. Keep the folder layout the same, and serve it over HTTPS for anything public. No configuration is needed. The page uses relative paths, so it works from any domain or subfolder.

If you change the HTML at all, update the CSP script hash first (see below).

## Changing the page

Because the CSP pins the app script by hash, **any edit to the main `<script>` block changes its hash and the page will stop running until the hash is updated.** After editing, recompute the hash of the last script and replace the old one in the `Content-Security-Policy` meta tag:

```bash
python3 -c "import re,hashlib,base64;s=open('index.html',encoding='utf-8').read();m=re.findall(r'<script>(.*?)</script>',s,re.S)[-1];print('sha256-'+base64.b64encode(hashlib.sha256(m.encode()).digest()).decode())"
```

The first two scripts (the anti-clickjacking snippet and ethers.js) only need new hashes if you change them.

To point the page at a different contract, chain or RPC list, edit `CONFIG` at the top of the main script, then update the hash as above.

## Hosting

The site is plain static files served through GitHub Pages on the `snipehead.xyz` domain, in the `/snft-eth/` path. Any static host works, as long as the files keep the same relative layout.

## Using the site safely

- Check that the contract address in your wallet's confirmation matches the one above before you sign.
- Only connect a wallet you control, and treat any custom RPC like any other third-party server.
- This page is a front end. The rules above are enforced by the contract, so you can verify them on [Etherscan](https://etherscan.io/address/0xE85eB0a14E185968B2a947d98feA023F8e80AB3a) or in the source.
