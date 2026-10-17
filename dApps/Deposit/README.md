# SHD Deposit — Community Mining Reward Funding

> **One-way community funding for the SHD mining reward reserve on PulseChain.**  
> Deposits are permanent and **non-refundable**.

This dApp lets anyone contribute **SHD** tokens into the mining contract’s reward reserve. Tokens deposited here top up the pool that pays rewards to miners. You do **not** receive tokens back and you do **not** earn mining rewards from depositing.

| | |
|---|---|
| **Network** | PulseChain (chain ID `369`) |
| **Version** | 1.5 |
| **Live (IPFS)** | [Open Deposit dApp](https://bafybeiatqofllwicbokkdhldzdztmf2figiyqntz62xuw5phpa2cf2pcqy.ipfs.inbrowser.link/) |
| **Repo path** | [`dApps/Deposit`](https://github.com/PBaieck-group/SnipeHead/tree/main/dApps/Deposit) |

---

## Contract addresses

| Contract | Address | Explorer |
|----------|---------|----------|
| **SHD Token** | [`0xb95bc84f9b6d0373642d586b81979b067572f7bc`](https://ipfs.scan.pulsechain.com/address/0xb95bc84f9b6d0373642d586b81979b067572f7bc) | PulseChain Scan |
| **Mining (reward reserve)** | [`0xa16C1FA26F13803083f0fd222D1EA083c1d6D650`](https://ipfs.scan.pulsechain.com/address/0xa16C1FA26F13803083f0fd222D1EA083c1d6D650) | PulseChain Scan |

- Token decimals: **18**
- Native currency: **PLS** (Pulse)

Always verify the addresses on-chain before depositing.

---

## How it works

1. Connect a wallet (MetaMask or any EIP-6963 / EIP-1193 wallet) on **PulseChain**.
2. Enter the amount of SHD you want to contribute.
3. Confirm that you understand the deposit is permanent and non-refundable.
4. Approve the mining contract to spend your SHD (if needed).
5. Confirm the deposit transaction.

Your SHD is transferred into the mining contract’s **reward reserve**. It is used to pay mining rewards to participants. There is no withdrawal, claim, or refund path for depositors.

---

## Features

- **Wallet support** — EIP-6963 multi-wallet discovery + legacy `window.ethereum` fallback
- **Network enforcement** — prompts to switch / add PulseChain if needed
- **RPC manager** — built-in nodes + custom RPCs, optional failover, status indicator
- **Confirm modal** — shows amount, token, destination contract, and network before sending
- **Approve + deposit flow** — static-call simulation, replacement-tx handling, revoke allowance option
- **Session restore** — reconnects only wallets the user previously connected on this page
- **Public reserve view** — reward reserve balance visible without connecting a wallet
- **Strict CSP** — no external scripts/fonts; styles and scripts are integrity-hashed
- **Mobile-friendly** — MetaMask deep-link hint on mobile browsers

---

## Built-in RPCs

| Name | URL |
|------|-----|
| PulseChain (official) | `https://rpc.pulsechain.com` |
| PublicNode | `https://pulsechain-rpc.publicnode.com` |
| G4mm4 | `https://rpc-pulsechain.g4mm4.io` |

You can add custom HTTPS RPC endpoints in the UI (stored in `localStorage`). Failover is enabled by default.

---

## Local usage

This is a single-file static dApp (`index.html`). No build step is required.

```bash
# Clone the repo
git clone https://github.com/PBaieck-group/SnipeHead.git
cd SnipeHead/dApps/Deposit

# Serve locally (any static server)
npx serve .
# or
python3 -m http.server 8080
```

Open the page in a browser with a PulseChain-capable wallet.

> **Note:** Some wallets and browsers require HTTPS (or `localhost`) for `eth_requestAccounts`. Prefer serving over `https://` or a local tunnel when testing.

---

## IPFS / decentralized access

The current deployment is available via IPFS:

**https://bafybeiatqofllwicbokkdhldzdztmf2figiyqntz62xuw5phpa2cf2pcqy.ipfs.inbrowser.link/**

You can also resolve the CID with any IPFS gateway:

```
https://ipfs.io/ipfs/bafybeiatqofllwicbokkdhldzdztmf2figiyqntz62xuw5phpa2cf2pcqy
```

---

## Security & safety notes

- **Deposits are permanent and non-refundable.** Only contribute amounts you are willing to give to the community reward pool.
- The page never asks for your seed phrase or private keys. It only interacts via your wallet’s standard provider APIs.
- Content-Security-Policy is strict: no external scripts, no external fonts, `connect-src https:` only.
- Always double-check the token and mining contract addresses before approving or depositing.
- Prefer verifying the page hash / IPFS CID when using gateways.

---

## Tech stack

- Vanilla HTML / CSS / JavaScript (single file)
- [ethers.js](https://docs.ethers.org/) (bundled) for contract interaction
- EIP-6963 wallet discovery + EIP-1193 provider
- Native `<dialog>` confirm modal
- PulseChain (chain ID 369)

---

## Related links

- **Main project:** [github.com/PBaieck-group/SnipeHead](https://github.com/PBaieck-group/SnipeHead)
- **Portal:** [snipehead.xyz](https://snipehead.xyz)
- **Explorer:** [ipfs.scan.pulsechain.com](https://ipfs.scan.pulsechain.com)

---

## Disclaimer

This is community funding software. Interacting with smart contracts involves risk of permanent loss of funds. There is no refund mechanism. Use at your own risk. The authors and contributors are not responsible for any losses incurred through use of this dApp or the associated contracts.

---

**SHD · PulseChain · Non-refundable community funding · v1.5**
