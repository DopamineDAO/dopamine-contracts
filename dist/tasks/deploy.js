"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const DopamineAuctionHouse_json_1 = __importDefault(require("../abi/src/auction/DopamineAuctionHouse.sol/DopamineAuctionHouse.json"));
const DopamineDAO_json_1 = __importDefault(require("../abi/src/governance/DopamineDAO.sol/DopamineDAO.json"));
const utils_1 = require("ethers/lib/utils");
const config_1 = require("hardhat/config");
// Listed in order of deployment. Wrong order results in error.
var Contract;
(function (Contract) {
    Contract[Contract["DopamintPass"] = 0] = "DopamintPass";
    Contract[Contract["DopamineAuctionHouse"] = 1] = "DopamineAuctionHouse";
    Contract[Contract["DopamineAuctionHouseProxy"] = 2] = "DopamineAuctionHouseProxy";
    Contract[Contract["Timelock"] = 3] = "Timelock";
    Contract[Contract["DopamineDAO"] = 4] = "DopamineDAO";
    Contract[Contract["DopamineDAOProxy"] = 5] = "DopamineDAOProxy";
})(Contract || (Contract = {}));
(0, config_1.task)("deploy-local", "Deploy Rarity Society contracts locally").setAction((args, { run }) => __awaiter(void 0, void 0, void 0, function* () {
    yield run("deploy", {
        chainid: 31337,
        registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
    });
}));
(0, config_1.task)("deploy-testing", "Deploy Rarity Society contracts to Rinkeby")
    .addParam("verify", "whether to verify on Etherscan", true, config_1.types.boolean)
    .setAction((args, { run }) => __awaiter(void 0, void 0, void 0, function* () {
    yield run("deploy", {
        chainid: 4,
        registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
        verify: args.verify,
    });
}));
(0, config_1.task)("deploy-staging", "Deploy Rarity Society contracts to Goerli")
    .addParam("verify", "whether to verify on Etherscan", true, config_1.types.boolean)
    .setAction((args, { run }) => __awaiter(void 0, void 0, void 0, function* () {
    yield run("deploy", {
        chainid: 5,
        registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
        verify: args.verify,
    });
}));
(0, config_1.task)("deploy-prod", "Deploy Rarity Society contracts to Ethereum Mainnet").setAction((args, { run }) => __awaiter(void 0, void 0, void 0, function* () {
    yield run("deploy", {
        chainid: 1,
        registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
    });
}));
(0, config_1.task)("deploy", "Deploys Dopamine contracts")
    .addParam("chainid", "expected network chain ID", undefined, config_1.types.int)
    .addParam("registry", "OpenSea proxy registry address", undefined, config_1.types.string)
    .addOptionalParam("verify", "whether to verify on Etherscan", true, config_1.types.boolean)
    .addOptionalParam("minter", "Rarity Society token minter", undefined, config_1.types.string)
    .addOptionalParam("vetoer", "Rarity Society DAO veto address", undefined, config_1.types.string)
    .addOptionalParam("timelockDelay", "timelock delay (seconds)", 60 * 60 * 24 * 2, config_1.types.int)
    .addOptionalParam("votingPeriod", "proposal voting period (# of blocks)", 32000, config_1.types.int)
    .addOptionalParam("votingDelay", "proposal voting delay (# of blocks)", 13000, config_1.types.int)
    .addOptionalParam("proposalThreshold", "proposal threshold (# of NFTs)", 1, config_1.types.int)
    .addOptionalParam("whitelistSize", "number of slots to reserve for whitelist minting", 10, config_1.types.int)
    .addOptionalParam("maxSupply", "total number of NFTs to reserve for minting", 9999, config_1.types.int)
    .addOptionalParam("treasurySplit", "% of auction revenue directed to Dopamine DAO", 50, config_1.types.int)
    .addOptionalParam("dropSize", "# of DopamintPasses to distribute for a given drop", 99, config_1.types.int)
    .addOptionalParam("dropDelay", "time in seconds to wait between drops", 60 * 60 * 24 * 33, config_1.types.int)
    .addOptionalParam("timeBuffer", "time in seconds to add for auction extensions", 60 * 10, config_1.types.int)
    .addOptionalParam("reservePrice", "starting reserve price for auctions", 1, config_1.types.int)
    .addOptionalParam("duration", "how long each auction should last", 60 * 10, config_1.types.int)
    .addOptionalParam("quorumVotesBPS", "proposal quorum votes (basis points)", 1000, config_1.types.int)
    .setAction((args, { ethers, run }) => __awaiter(void 0, void 0, void 0, function* () {
    const gasPrice = yield ethers.provider.getGasPrice();
    const network = yield ethers.provider.getNetwork();
    if (network.chainId != args.chainid) {
        console.log(`invalid chain ID, expected: ${args.chainid} got: ${network.chainId}`);
        return;
    }
    console.log(`Deploying Rarity Society contracts to chain ${network.chainId}`);
    const [deployer] = yield ethers.getSigners();
    console.log(`Deployer address: ${deployer.address}`);
    console.log(`Deployer balance: ${ethers.utils.formatEther(yield deployer.getBalance())} ETH`);
    const nonce = yield deployer.getTransactionCount();
    let currNonce = nonce;
    const deployContract = function (contract, args, currNonce) {
        return __awaiter(this, void 0, void 0, function* () {
            console.log(`\nDeploying contract ${contract}:`);
            const expectedNonce = nonce + Contract[contract];
            if (currNonce != expectedNonce) {
                throw new Error(`Unexpected transaction nonce, got: ${currNonce} expected: ${expectedNonce}`);
            }
            const contractFactory = yield ethers.getContractFactory(contract);
            const gas = yield contractFactory.signer.estimateGas(contractFactory.getDeployTransaction(...args, { gasPrice }));
            const cost = ethers.utils.formatUnits(gas.mul(gasPrice), "ether");
            console.log(`Estimated deployment cost for ${contract}: ${cost}ETH`);
            const deployedContract = yield contractFactory.deploy(...args);
            yield deployedContract.deployed();
            console.log(`Contract ${contract} deployed to ${deployedContract.address}`);
            return deployedContract.address;
        });
    };
    // 1. Deploy DopamintPass:
    const dopamintPassArgs = [
        ethers.utils.getContractAddress({
            from: deployer.address,
            nonce: nonce + Contract.DopamineAuctionHouseProxy,
        }),
        args.registry,
        args.dropSize,
        args.dropDelay,
        args.whitelistSize,
        args.maxSupply
    ];
    const dopamintPass = yield deployContract(Contract[Contract.DopamintPass], dopamintPassArgs, currNonce++);
    // 2. Deploy auction house.
    const dopamineAuctionHouse = yield deployContract(Contract[Contract.DopamineAuctionHouse], [], currNonce++);
    // 3. Deploy auction house proxy.
    const dopamineAuctionHouseProxyArgs = [
        dopamineAuctionHouse,
        new utils_1.Interface(DopamineAuctionHouse_json_1.default).encodeFunctionData('initialize', [
            dopamintPass,
            deployer.address,
            ethers.utils.getContractAddress({
                from: deployer.address,
                nonce: nonce + Contract.DopamineDAOProxy,
            }),
            args.treasurySplit,
            args.timeBuffer,
            args.reservePrice,
            args.duration
        ]),
    ];
    const dopamineAuctionHouseProxy = yield deployContract(Contract[Contract.DopamineAuctionHouseProxy], dopamineAuctionHouseProxyArgs, currNonce++);
    // 4. Deploy timelock.
    const timelockArgs = [
        ethers.utils.getContractAddress({
            from: deployer.address,
            nonce: nonce + Contract.DopamineDAOProxy,
        }),
        args.timelockDelay,
    ];
    const timelock = yield deployContract(Contract[Contract.Timelock], timelockArgs, currNonce++);
    // 5. Deploy Dopamine DAO
    const dopamineDAOArgs = [
        ethers.utils.getContractAddress({
            from: deployer.address,
            nonce: nonce + Contract.DopamineDAOProxy,
        }),
    ];
    const dopamineDAO = yield deployContract(Contract[Contract.DopamineDAO], dopamineDAOArgs, currNonce++);
    // 6. Deploy Dopamine DAO Proxy
    const dopamineDAOProxyArgs = [
        dopamineDAO,
        new utils_1.Interface(DopamineDAO_json_1.default).encodeFunctionData('initialize', [
            timelock,
            dopamintPass,
            args.vetoer || deployer.address,
            args.votingPeriod,
            args.votingDelay,
            args.proposalThreshold,
            args.quorumVotesBPS
        ]),
    ];
    const dopamineDAOProxy = yield deployContract(Contract[Contract.DopamineDAOProxy], dopamineDAOProxyArgs, currNonce++);
    if (args.verify) {
        const toVerify = {
            dopamintPass: {
                address: dopamintPass,
                args: dopamintPassArgs,
            },
            dopamineAuctionHouse: {
                address: dopamineAuctionHouse,
                args: [],
            },
            dopamineAuctionHouseProxy: {
                address: dopamineAuctionHouseProxy,
                args: dopamineAuctionHouseProxyArgs,
                path: "src/auction/DopamineAuctionHouseProxy.sol:DopamineAuctionHouseProxy",
            },
            timelock: {
                address: timelock,
                args: timelockArgs,
            },
            dopamineDAO: {
                address: dopamineDAO,
                args: dopamineDAOArgs,
            },
            dopamineDAOProxy: {
                address: dopamineDAOProxy,
                args: dopamineDAOProxyArgs,
                path: "src/governance/DopamineDAOProxy.sol:DopamineDAOProxy",
            }
        };
        for (const contract in toVerify) {
            console.log(`\nVerifying contract ${contract}:`);
            for (let i = 0; i < 3; i++) {
                try {
                    if (toVerify[contract].path) {
                        yield run("verify:verify", {
                            address: toVerify[contract].address,
                            constructorArguments: toVerify[contract].args,
                            contract: toVerify[contract].path,
                        });
                    }
                    else {
                        yield run("verify:verify", {
                            address: toVerify[contract].address,
                            constructorArguments: toVerify[contract].args,
                        });
                    }
                    console.log(`Contract ${contract} succesfully verified!`);
                    break;
                }
                catch (e) {
                    let msg;
                    if (e instanceof Error) {
                        msg = e.message;
                    }
                    else {
                        msg = String(e);
                    }
                    if (msg.includes('Already Verified')) {
                        console.log(`Contract ${contract} already verified!`);
                        break;
                    }
                    console.log(`Error verifying contract ${contract}: ${msg}`, msg);
                }
            }
        }
    }
    // if (!fs.existsSync('logs')) {
    // 	fs.mkdirSync('logs');
    // }
    // fs.writeFileSync(
    // 	'logs/deploy.json',
    // 	JSON.stringify({
    // 		addresses: {
    // 		},
    // 	}),
    // 	{ flag: 'w' },
    // );
}));
