# SHD Deposit (v2.0)

A single-file, dependency-free web page for depositing SHD into the PulseChain reward reserve.

- **Live site:** <https://snipehead.xyz/deposit/>
- **Source:** [`docs/deposit/index.html`](https://github.com/PBaieck-group/SnipeHead/tree/main/docs/deposit)
- **Network:** PulseChain (chainId `369`)

> **Deposits are non-refundable.** Read the on-page confirmation before sending anything. This software is provided as-is, with no warranty. Always verify the contract addresses below against an official source before use.

---

## Contents

1. [Design goals](#design-goals)
2. [Run it](#run-it)
3. [Files](#files)
4. [How the frontend works](#how-the-frontend-works)
5. [Configuration](#configuration)
6. [Security model](#security-model)
7. [Editing the page (CSP hashes)](#editing-the-page-csp-hashes)
8. [Verifying the bundled ethers library](#verifying-the-bundled-ethers-library)
9. [Troubleshooting](#troubleshooting)

---

## Design goals

- **No build step, no package manager, no framework.** One HTML file.
- **No CDN and no third-party requests.** The ethers library is inlined. There are no external fonts, scripts, analytics, or images.
- **Minimal network surface.** The page may only contact the built-in PulseChain RPC endpoints (and a node on your own machine). This is enforced by a Content-Security-Policy, not just by convention.
- **Hard to tamper with silently.** Inline code is pinned by SHA-256 hashes in the CSP, and HTML-string injection is blocked with Trusted Types.
- **Auditable.** Everything a user runs is readable in one file.

---

## Run it

### Use the hosted version

Open <https://snipehead.xyz/deposit/>, connect a wallet, and follow the prompts.

### Host it yourself (GitHub Pages)

1. Fork or clone this repository.
2. In **Settings → Pages**, set the source to the `main` branch and the `/docs` folder.
3. Enable **Enforce HTTPS**.
4. The page will be served at `https://<your-pages-domain>/deposit/`.

### Run it locally

You need any static file server. The page does not need a build.

```bash
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/docs/deposit

# pick one
python3 -m http.server 8000
# or
npx serve .
```

Then open <http://localhost:8000> in a browser that has a wallet extension (MetaMask, Rabby, etc.).

> Serve it over `http://localhost` or `https://`. Opening the file directly with `file://` often prevents wallet extensions from injecting their provider.

**Requirements:** a modern browser (a recent Chromium-based browser, Firefox, or Safari), a wallet that supports PulseChain, and some PLS for gas.

---

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole application: markup, CSS, inlined ethers, and app logic. |
| `README.md` | This document. |

---

## How the frontend works

`index.html` contains three inline scripts and two inline styles, in this order:

| Block | What it is |
| --- | --- |
| Script 1 (tiny) | Anti-clickjacking guard. The page starts hidden (`html{display:none}`) and is revealed only when it is the top-level window. |
| Script 2 (large) | `ethers` v6.13.5, the official `ethers.umd.min.js`, unmodified. |
| Script 3 | The app logic (wrapped in an IIFE, `"use strict"`). |
| Style 1 (tiny) | The anti-clickjack rule above. |
| Style 2 | All page styling. |

### Wallet connection

- Wallets are discovered through **EIP-6963** (`eip6963:announceProvider`), with a fallback to `window.ethereum` for older or in-app wallet browsers.
- If more than one wallet is found, a picker is shown. Wallet icons come from the extension and are treated as untrusted: only inline `data:image/png|jpeg|gif|webp|svg+xml` URIs of limited size are accepted, otherwise no icon is shown.
- After connecting, the page asks the wallet to switch to PulseChain (`wallet_switchEthereumChain`). If the chain is unknown, it offers `wallet_addEthereumChain` with only the official RPC.
- The page listens for `accountsChanged` and `chainChanged`. If either changes, any open confirmation dialog is closed and balances are refreshed.
- The connected wallet's identifier is remembered so a returning user is silently reconnected (read-only `eth_accounts`, no pop-up). Pressing **Disconnect** forgets it.

### Reading data (balance and reserve)

Reads are separate from transactions. Transactions are always signed and broadcast by your wallet.

The RPC selector offers these read modes:

| Mode | Behaviour |
| --- | --- |
| **Automatic** (default) | Before connecting: public quorum (only the public reserve figure is requested, with no address involved). After connecting: your wallet's own node. |
| **Quorum (2 of 3)** | Asks all three built-in RPCs and accepts a result only when a majority agree, so one broken or lying node cannot control the balance or reserve shown. |
| **Your wallet's node** | Reads go through the connected wallet, so the page itself makes no third-party calls. |
| **A specific built-in RPC** | PulseChain (official), PublicNode, or G4mm4, with optional failover to the others. |
| **Custom RPC** | A URL you add yourself. Because of the CSP, this effectively means a node on your own machine (`http(s)://localhost:PORT` or `127.0.0.1`). |

Reads are throttled and pause when the browser tab is hidden. Each RPC is verified to be on chain `369` before its answer is trusted.

### Depositing

1. Enter an amount (comma and decimal formatting is handled; more than 18 decimals is rejected). **Max** fills the whole-token portion of your balance.
2. Tick the non-refundable acknowledgement.
3. A confirmation dialog shows the amount, the token contract, the destination (mining) contract, and the network.
4. On confirm, the page runs this sequence:
   1. Re-check that the account and chain have not changed.
   2. Re-read your SHD balance on-chain (the number on screen may be stale).
   3. Read the current allowance.
   4. If the allowance is already enough, simulate `deposit` and skip approval. Otherwise:
      - send `approve(miningContract, amount)` for **exactly the deposit amount** (never unlimited),
      - wait for confirmation (following replaced or sped-up transactions),
      - simulate `deposit` again; if it would fail, show a **Revoke** button.
   5. Re-check account and chain, estimate gas, and send `deposit(amount)`.
   6. Wait for confirmation, then refresh balances.
5. **Revoke approval** sets the allowance for the mining contract back to `0`.

Transaction hashes are shown in the status log as links to the block explorer only when they match the expected 32-byte hex format.

### Local storage

| Where | What | Why |
| --- | --- | --- |
| `localStorage` | Your wallet's identifier | Silent reconnect after reload. |
| `localStorage` | RPC preferences (selected built-in mode, failover on/off) | Remember your choice. Contains no URLs you typed. |
| `sessionStorage` | Custom RPC URLs, and the selection if it points at one | Custom URLs can contain API keys, so they live only until the tab is closed. |

No cookies are set. No data is sent to any server other than the RPC endpoints described above.

### Status log and UI safety

All dynamic text is written with `textContent` or DOM APIs (never HTML strings), so wallet names, error messages, and RPC responses cannot inject markup.

---

## Configuration

All constants live in a single `CONFIG` object at the top of the app script (Script 3).

| Key | Value |
| --- | --- |
| `chainId` | `369` (PulseChain) |
| `rpcs` | `rpc.pulsechain.com`, `pulsechain-rpc.publicnode.com`, `rpc-pulsechain.g4mm4.io` |
| `token` (SHD) | `0xB95bC84f9B6D0373642D586b81979B067572f7bc` |
| `mining` (deposit target) | `0xa16C1FA26F13803083f0fd222D1EA083c1d6D650` |
| `decimals` | `18` |
| `explorer` | `https://ipfs.scan.pulsechain.com` |
| `version` | `2.0` |

The only contract functions the page calls:

```
token:   approve(address,uint256)  allowance(address,address)  balanceOf(address)
mining:  deposit(uint256)          rewardReserve()
```

> **Verify the two contract addresses** against your official announcement and the block explorer before depositing. The page can confirm a deposit would succeed; it cannot tell you whether a contract is the one you intend to fund or whether it is safe.

---

## Security model

**Content-Security-Policy** (set with a `<meta>` tag, because GitHub Pages cannot send custom headers):

- `default-src 'none'`: everything is denied unless allowed below.
- `script-src` and `style-src` allow only specific **SHA-256 hashes** of the inline blocks. No `unsafe-inline`, no `unsafe-eval`.
- `connect-src` allows only the three built-in RPC origins plus `http://localhost:*` and `http://127.0.0.1:*`.
- `img-src 'self' data:`, `font-src 'none'`, `object-src 'none'`, `base-uri 'none'`, `form-action 'none'`.
- `upgrade-insecure-requests`.
- `require-trusted-types-for 'script'; trusted-types 'none'`: string-to-HTML sinks (such as `innerHTML`) are blocked in supporting browsers, and the page creates no Trusted Types policies.

**Other protections**

- Anti-clickjacking guard (framing the page leaves it blank).
- Exact-amount approvals, with a Revoke button.
- Pre-flight simulation of `deposit`, and re-verification of account and chain immediately before each transaction.
- Strict number parsing and address checksum validation.
- Wallet icons validated, wallet names and errors rendered as text only.
- Custom RPC URLs rejected unless they are `https` (or loopback), carry no credentials, and match the CSP's allowed origins.

**Limits you should know about**

- A `<meta>` CSP cannot set `frame-ancestors` or security headers such as HSTS. For stronger hosting, serve the page from infrastructure that can send real headers.
- Anyone who can push to this repository or control the domain can change what users receive. Protect both with 2FA and branch protection.
- A malicious wallet extension is outside this page's threat model.
- This repository does not audit the deposit contract.

---

## Editing the page (CSP hashes)

The CSP lists the SHA-256 hash of every inline `<script>` and `<style>`. **If you change a single character inside one of those blocks (including comments), its hash changes and the browser will refuse to run or apply it.** After any edit, update the hash list in the `<meta http-equiv="Content-Security-Policy">` tag.

This script prints the current hashes and tells you which ones are missing from the CSP:

```python
import re, hashlib, base64

html = open("index.html", encoding="utf-8").read()
csp = re.search(r'Content-Security-Policy" content="([^"]*)"', html).group(1)

def sha256(text):
    return "sha256-" + base64.b64encode(hashlib.sha256(text.encode("utf-8")).digest()).decode()

for tag in ("script", "style"):
    for m in re.finditer(rf"<{tag}(?:\s[^>]*)?>(.*?)</{tag}>", html, re.S):
        h = sha256(m.group(1))
        print(tag, len(m.group(1)), h, "OK" if h in csp else "MISSING FROM CSP")
```

Replace any `MISSING` entry's old hash in the CSP with the new one, then re-run until everything reads `OK`.

Checklist after editing:

- [ ] All hashes read `OK`.
- [ ] Load the page with the browser DevTools console open and confirm there are no CSP or Trusted Types errors.
- [ ] Connect a wallet and complete a small test deposit on staging.
- [ ] Bump `CONFIG.version` and the footer text if you are releasing.

---

## Verifying the bundled ethers library

Script 2 is the official `ethers.umd.min.js` from `ethers@6.13.5`, preceded by a one-line comment. To confirm it has not been altered:

```bash
mkdir /tmp/ev && cd /tmp/ev
npm pack ethers@6.13.5
tar xzf ethers-6.13.5.tgz
sha256sum package/dist/ethers.umd.min.js
# expected: c8550f9644492f2d1278467b301c615c768a0d61d5c22d5bcd107ec7c9cbd329
```

Then check that this file's contents appear unchanged inside the second `<script>` block of `index.html` (everything except the header comment line and the trailing newline).

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Blank page | The page is being framed by another site, or the CSP blocked an inline block after an edit. Check the console and re-run the hash script. |
| "No wallet found" | No wallet extension is available. On mobile, open the page inside your wallet's built-in browser. |
| Connect works but balances show `—` | RPCs unreachable. Pick another RPC, enable failover, or choose "Your wallet's node". |
| "Wrong network" banner | Switch your wallet to PulseChain (chainId 369). |
| A custom RPC is rejected | Only built-in RPCs and a node on `localhost` / `127.0.0.1` can be reached. For any other remote node, add it to your wallet's own network settings and use "Your wallet's node". |
| Console shows a CSP or Trusted Types violation | A script or style was edited without updating its hash, or new code uses a blocked feature such as `innerHTML`. |
| Local node on `http://localhost` is not used | Some browsers may upgrade or restrict requests under `upgrade-insecure-requests`. If you rely on a local node, test it; if it fails, remove that directive. |

---

## License

Add your license here (for example, MIT) and include a `LICENSE` file in the repository.
