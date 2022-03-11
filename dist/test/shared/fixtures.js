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
Object.defineProperty(exports, "__esModule", { value: true });
exports.raritySocietyDAOProxyFixture = exports.raritySocietyDAOImplFixture = exports.gasBurnerFixture = exports.timelockFixture = exports.erc721TokenFixture = exports.erc1155TokenFixture = exports.raritySocietyAuctionHouseFixture = exports.wethFixture = void 0;
const hardhat_1 = require("hardhat");
const address_1 = require("@ethersproject/address");
const constants_1 = require("./constants");
const typechain_1 = require("../../typechain");
function wethFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const tokenFactory = new typechain_1.MockWETH__factory(deployer);
        const token = yield tokenFactory.deploy();
        return token;
    });
}
exports.wethFixture = wethFixture;
function raritySocietyAuctionHouseFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const weth = yield wethFixture(signers);
        const auctionHouseFactory = new typechain_1.RaritySocietyAuctionHouse__factory(deployer);
        const auctionHouse = yield auctionHouseFactory.deploy();
        const tokenFactory = new typechain_1.MockERC721Token__factory(deployer);
        const token = yield tokenFactory.deploy(auctionHouse.address, 10);
        return { weth, token, auctionHouse };
    });
}
exports.raritySocietyAuctionHouseFixture = raritySocietyAuctionHouseFixture;
function erc1155TokenFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const tokenFactory = new typechain_1.MockERC1155Token__factory(deployer);
        const token = yield tokenFactory.deploy(deployer.address, 10);
        return token;
    });
}
exports.erc1155TokenFixture = erc1155TokenFixture;
function erc721TokenFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const tokenFactory = new typechain_1.MockERC721Token__factory(deployer);
        const token = yield tokenFactory.deploy(deployer.address, 10);
        return token;
    });
}
exports.erc721TokenFixture = erc721TokenFixture;
function timelockFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const timelockFactory = new typechain_1.Timelock__factory(deployer);
        return yield timelockFactory.deploy(deployer.address, constants_1.Constants.TIMELOCK_DELAY);
    });
}
exports.timelockFixture = timelockFixture;
function gasBurnerFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const gasBurnerFactory = new typechain_1.GasBurner__factory(deployer);
        return yield gasBurnerFactory.deploy();
    });
}
exports.gasBurnerFixture = gasBurnerFixture;
function raritySocietyDAOImplFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const admin = signers[1];
        const vetoer = signers[2];
        const tokenFactory = new typechain_1.MockERC721Token__factory(deployer);
        const token = yield tokenFactory.deploy(deployer.address, 99);
        // 2nd TX MUST be daoImpl deployment
        const daoImplAddress = (0, address_1.getContractAddress)({
            from: deployer.address,
            nonce: (yield deployer.getTransactionCount()) + 1,
        });
        const timelockFactory = new typechain_1.Timelock__factory(deployer);
        const timelock = yield timelockFactory.deploy(daoImplAddress, constants_1.Constants.TIMELOCK_DELAY);
        const daoImplFactory = new typechain_1.RaritySocietyDAOImpl__factory(deployer);
        const daoImpl = yield daoImplFactory.deploy();
        return { token, timelock, daoImpl };
    });
}
exports.raritySocietyDAOImplFixture = raritySocietyDAOImplFixture;
function raritySocietyDAOProxyFixture(signers) {
    return __awaiter(this, void 0, void 0, function* () {
        const deployer = signers[0];
        const admin = signers[1];
        const vetoer = signers[2];
        const tokenFactory = new typechain_1.MockERC721Token__factory(deployer);
        const token = yield tokenFactory.deploy(deployer.address, 99);
        const daoImplFactory = new typechain_1.RaritySocietyDAOImpl__factory(deployer);
        const daoImpl = yield daoImplFactory.deploy();
        const proxyAdminFactory = new typechain_1.RaritySocietyProxyAdmin__factory(deployer);
        const proxyAdmin = yield proxyAdminFactory.deploy();
        const daoAddress = (0, address_1.getContractAddress)({
            from: deployer.address,
            nonce: (yield deployer.getTransactionCount()) + 1,
        });
        const timelockFactory = new typechain_1.Timelock__factory(deployer);
        const timelock = yield timelockFactory.deploy(daoAddress, constants_1.Constants.TIMELOCK_DELAY);
        const daoFactory = new typechain_1.RaritySocietyDAOProxy__factory(deployer);
        const iface = new hardhat_1.ethers.utils.Interface([
            "function initialize(address daoAdmin, address timelock_, address token_, address vetoer_, uint256 votingPeriod_, uint256 votingDelay_, uint256 proposalThreshold_, uint256 quorumVotesBPS_)",
        ]);
        const initCallData = iface.encodeFunctionData("initialize", [
            admin.address,
            timelock.address,
            token.address,
            vetoer.address,
            constants_1.Constants.VOTING_PERIOD,
            constants_1.Constants.VOTING_DELAY,
            constants_1.Constants.PROPOSAL_THRESHOLD,
            constants_1.Constants.QUORUM_VOTES_BPS,
        ]);
        const dao = yield daoFactory.deploy(daoImpl.address, proxyAdmin.address, initCallData);
        const daoProxyImpl = daoImplFactory.attach(dao.address);
        return { token, timelock, dao, daoProxyImpl, daoImpl, proxyAdmin };
    });
}
exports.raritySocietyDAOProxyFixture = raritySocietyDAOProxyFixture;
