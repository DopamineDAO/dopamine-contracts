"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@typechain/hardhat");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-ethers");
require("solidity-coverage");
require("hardhat-abi-exporter");
require("./tasks/config");
require("./tasks/merkle");
require("./tasks/deploy");
require("./tasks/propose");
require("./tasks/mint");
dotenv_1.default.config();
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
const config = {
    solidity: {
        version: "0.8.9",
        settings: {
            optimizer: {
                enabled: true,
                runs: 10000,
            },
        },
    },
    typechain: {
        outDir: "typechain",
    },
    networks: {
        ropsten: {
            url: `https://ropsten.infura.io/v3/${process.env.PROJECT_ID}`,
            accounts: [process.env.PRIVATE_KEY].filter(Boolean),
        },
        goerli: {
            url: `https://eth-goerli.alchemyapi.io/v2/${process.env.API_KEY}`,
            accounts: [process.env.PRIVATE_KEY].filter(Boolean),
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
exports.default = config;
