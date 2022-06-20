import dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-ethers";
import "solidity-coverage";
import "hardhat-abi-exporter";

import "./tasks/config";
import "./tasks/merkle";
import "./tasks/deploy-honoraries";
import "./tasks/mint-honorary";

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10_000,
      },
    },
  },
  typechain: {
    outDir: "typechain",
  },
  networks: {
		mainnet: {
			url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.MAINNET_API_KEY}`,
			accounts: [process.env.PRIVATE_KEY!].filter(Boolean),
		},
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.GOERLI_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY!].filter(Boolean),
    },
    rinkebyDev: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.RINKEBY_API_KEY}`,
      accounts: [process.env.DEV_PRIVATE_KEY!].filter(Boolean),
    },
    rinkebyStaging: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.RINKEBY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY!].filter(Boolean),
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    pretty: true,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
	mocha: {
		timeout: 60000
	},
	paths: {
		sources: "./src",
	},
};

export default config;
