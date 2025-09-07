import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.20",
      },
      production: {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    pulsechain: {
      type: "http",
      chainType: "l1",
      url: configVariable("PULSECHAIN_RPC_URL"),
      accounts: [configVariable("PULSECHAIN_PRIVATE_KEY")],
      chainId: 369,
    },
    pulsechainTestnet: {
      type: "http",
      chainType: "l1",
      url: configVariable("PULSECHAIN_TESTNET_RPC_URL"),
      accounts: [configVariable("PULSECHAIN_TESTNET_PRIVATE_KEY")],
      chainId: 943,
    },
  },
};

export default config;
