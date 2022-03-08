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
import "./tasks/deploy";
import "./tasks/propose";
import "./tasks/mint";

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10_000,
      },
			remappings: [
				"ds-test/=lib/ds-test/contracts/",
			],
    },
  },
  typechain: {
    outDir: "typechain",
  },
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.PROJECT_ID}`,
      accounts: [process.env.PRIVATE_KEY!].filter(Boolean),
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.PROJECT_ID}`,
      accounts: [process.env.PRIVATE_KEY!].filter(Boolean),
    },
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
