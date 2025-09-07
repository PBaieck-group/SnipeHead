import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseSignature, getAddress } from "viem";
import { network } from "hardhat";

describe("SnipeHead", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [deployerClient, recipientClient] = await viem.getWalletClients();
  const deployer = deployerClient.account;
  const recipient = recipientClient.account;

  it("Should deploy with correct name, symbol, and decimals", async function () {
    const snipeHead = await viem.deployContract("SnipeHead", [recipient!.address]);

    assert.equal(await snipeHead.read.name(), "SnipeHead");
    assert.equal(await snipeHead.read.symbol(), "SHD");
    assert.equal(Number(await snipeHead.read.decimals()), 18);
  });

  it("Should mint 21 billion tokens to the recipient on deployment", async function () {
    const snipeHead = await viem.deployContract("SnipeHead", [recipient!.address]);
    const totalSupply = 21_000_000_000n * 10n ** 18n; // 21 billion * 10^18

    assert.equal(await snipeHead.read.totalSupply(), totalSupply);
    assert.equal(await snipeHead.read.balanceOf([recipient!.address]), totalSupply);
    assert.equal(await snipeHead.read.balanceOf([deployer!.address]), 0n);
  });

  it("Should emit Transfer event on token transfer", async function () {
    const snipeHead = await viem.deployContract("SnipeHead", [recipient!.address]);
    const transferAmount = 1_000_000n * 10n ** 18n; // 1 million tokens

    await viem.assertions.emitWithArgs(
      snipeHead.write.transfer([deployer!.address, transferAmount], {
        account: recipient,
      }),
      snipeHead,
      "Transfer",
      [
        getAddress(recipient!.address), // Checksummed
        getAddress(deployer!.address), // Checksummed
        transferAmount,
      ],
    );

    assert.equal(await snipeHead.read.balanceOf([deployer!.address]), transferAmount);
    assert.equal(
      await snipeHead.read.balanceOf([recipient!.address]),
      21_000_000_000n * 10n ** 18n - transferAmount,
    );
  });

  it("Should allow permit-based approval and transferFrom", async function () {
    const snipeHead = await viem.deployContract("SnipeHead", [recipient!.address]);
    const amount = 1_000_000n * 10n ** 18n; // 1 million tokens
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now

    // Get nonce with explicit bigint cast for uint256 return
    const nonce = (await snipeHead.read.nonces([recipient!.address])) as bigint;

    // Generate permit signature
    const signature = await recipientClient.signTypedData({
      domain: {
        name: "SnipeHead",
        version: "1",
        chainId: Number(await publicClient.getChainId()), // getChainId returns number
        verifyingContract: snipeHead.address,
      },
      types: {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      primaryType: "Permit", // Required for ERC20Permit type inference
      message: {
        owner: recipient!.address,
        spender: deployer!.address,
        value: amount,
        nonce,
        deadline,
      },
    });

    // Parse the signature into r, s, yParity (modern Viem format)
    const parsedSig = parseSignature(signature);
    const v = Number(parsedSig.yParity) + 27; // Convert yParity (0/1) to v (27/28)

    // Submit permit
    await snipeHead.write.permit([
      recipient!.address,
      deployer!.address,
      amount,
      deadline,
      v,
      parsedSig.r,
      parsedSig.s,
    ]);

    // Verify allowance
    assert.equal(
      await snipeHead.read.allowance([recipient!.address, deployer!.address]),
      amount,
    );

    // Perform transferFrom
    await snipeHead.write.transferFrom([recipient!.address, deployer!.address, amount], {
      account: deployer,
    });

    assert.equal(await snipeHead.read.balanceOf([deployer!.address]), amount);
    assert.equal(
      await snipeHead.read.balanceOf([recipient!.address]),
      21_000_000_000n * 10n ** 18n - amount,
    );
  });
});