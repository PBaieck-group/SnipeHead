# SnipeHead Mining

A single-file web frontend for the SHD mining contract on PulseChain. Connect a wallet, mine SHD, claim rewards, and unmine, all from one static `index.html` with no backend, no build step, and no external scripts.

**Version:** 4.0.0
**Network:** PulseChain Mainnet (chain ID 369)

## Contracts

| Contract | Address |
| --- | --- |
| Mining | [`0xa16C1FA26F13803083f0fd222D1EA083c1d6D650`](https://ipfs.scan.pulsechain.com/address/0xa16C1FA26F13803083f0fd222D1EA083c1d6D650?tab=contract) |
| SHD token | [`0xB95bC84f9B6D0373642D586b81979B067572f7bc`](https://ipfs.scan.pulsechain.com/address/0xB95bC84f9B6D0373642D586b81979B067572f7bc) |

Contract source: [SnipeheadMiningDecentralizedV2](https://github.com/PBaieck-group/SnipeHead/tree/main/SnipeheadMiningDecentralizedV2)

Always check the verified source on the explorer against the repository before you trust any deployment.

## What it does

- **Dashboard:** estimated APR, total mined (mining power), reward reserve, contract balance, reward rate, and reserve health.
- **Mine:** approve SHD, then mine. This takes two transactions, and each needs PLS for gas.
- **Unmine:** withdraw your mined principal.
- **Claim:** collect pending rewards.
- **Your position:** wallet balance, mined amount, and pending rewards once a wallet is connected.

### About the numbers

- **Est. APR** is the current reward rate annualised: `rewardRate x blocks per year x 100`, assuming 10-second blocks. It does not compound, it assumes the reserve does not run out, and it changes as total mined and the reserve change. It is not a promise of future returns.
- **Reserve health** is the reward reserve divided by total mined. Rewards stop if the reserve empties.

## Safety features

The page is built so that it fails safe rather than guessing.

- **Exact approvals.** It approves only the amount you are mining, never an unlimited allowance.
- **Simulate before sending.** Each transaction is run as a read-only call first. If the contract would revert, you see the reason and nothing is sent.
- **Wallet network check.** The wallet's chain is re-read right before every transaction, and again between the approval and the mine step. If the wallet is not on PulseChain, nothing is sent.
- **Receipt confirmation.** "Success" appears only after a receipt with status 1. Reverted, cancelled, and replaced transactions are reported with the relevant hash, and a speed-up is followed to its replacement.
- **Contract presence check.** If no contract code is found at the mining or token address (wrong network, wrong address, or a dishonest RPC), transactions are disabled. The check is confirmed with other RPCs first so one bad node cannot lock the page by itself.
- **No wallet popups on load.** The page only asks the wallet to switch or add PulseChain after you click **Connect**.

## RPC handling

All on-chain reads go through the selected RPC. The wallet is used only to sign and send transactions.

- **Built-in endpoints:** `rpc.pulsechain.com`, `rpc-pulsechain.g4mm4.io`, `pulsechain-rpc.publicnode.com`, `rpc.pulsechainstats.com`.
- **Failover:** if the chosen RPC stops answering, the page moves to the next one and returns to your choice when it recovers. This can be turned off in the RPC menu.
- **Cross-checking:** for the numbers people act on, the page asks up to two other endpoints for the same block and compares the raw values. A difference is flagged with a banner. Nothing is switched automatically. This can be turned off in the RPC menu.
- **Custom RPCs:** you can add up to 5 of your own nodes, over `https://` or `http://localhost` for a node on your own machine. Each must answer as chain 369 before it is used, and must allow browser (CORS) requests. Custom URLs are saved only in your browser and are never handed to your wallet.
- **Batched reads:** reads use Multicall3 (`0xcA11bde05977b3631167028862bE2a173976CA11`) so a refresh costs one request per endpoint, and fall back to plain calls if an endpoint cannot serve it.

## Privacy

There is no backend, analytics, or tracking. The page sets `no-referrer`.

- The RPC you choose can see your IP address and the queries the page makes.
- With cross-checking on, your reads (including your wallet address once connected) also go to up to two other RPCs.
- Your RPC preferences are stored in your browser's `localStorage` under the key `shd_rpc_preference`. Nothing else is stored.

## Files

```
index.html             the entire app (HTML, CSS, JS, and ethers.js v6.15.0 embedded)
Logo_200.png           logo
shd-3d-token-v1.png    SHD token image
```

Images are loaded from the same directory, so keep them next to `index.html`.

## Running and hosting

It is a static site, so any static host works.

- **Locally:** open `index.html` in a browser, or serve the folder (for example `python3 -m http.server`). A browser wallet extension is needed to send transactions.
- **GitHub Pages:** publish the folder and, for a custom domain, add a `CNAME` file, set your DNS records, and enable **Enforce HTTPS** in the Pages settings.

## Security policy (CSP) and editing the code

The page ships with a strict Content Security Policy in a `<meta>` tag:

- No external scripts, fonts, or frames.
- Inline scripts run only if their SHA-256 hash is listed in the policy.
- Network requests are limited to `https:` and `localhost`, so custom RPCs work.

**If you edit either `<script>` block, the page will stop running until you update the hashes**, because the browser will refuse the changed code. Changes to HTML text or CSS do not affect the hashes.

To recompute them, run this next to `index.html` and replace the two `sha256-...` values in the CSP meta tag:

```python
import re, hashlib, base64
s = open("index.html", encoding="utf-8").read()
for m in re.finditer(r"<script>(.*?)</script>", s, re.S):
    h = base64.b64encode(hashlib.sha256(m.group(1).encode()).digest()).decode()
    print("'sha256-" + h + "'")
```

The first hash is the embedded ethers.js bundle and the second is the app script. After updating, open the page and confirm that the numbers load and Connect works.

GitHub Pages cannot send HTTP headers, so `frame-ancestors` (which blocks embedding in other sites) cannot be set from a `<meta>` tag. Your wallet's confirmation screen remains the final check on every transaction.

## Disclaimer

Mining involves smart-contract risk, and the contract may contain bugs or behave in ways you do not expect. Rewards are paid only from the reward reserve and stop if it empties. Nothing here is financial advice. Only mine what you can afford to lose, and verify the contract yourself before you use it.
