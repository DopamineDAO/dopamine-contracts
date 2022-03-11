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
exports.mintN = exports.stopImpersonating = exports.impersonate = exports.setNextBlockTimestamp = exports.advanceBlocks = exports.mineBlock = exports.stopMining = exports.startMining = exports.getChainId = exports.supportsInterfaces = exports.extractTokensFromEvents = exports.extractEvents = exports.encodeParameters = void 0;
const hardhat_1 = require("hardhat");
const chai_1 = require("chai");
const ethers_1 = require("ethers");
const INTERFACE_ID_MAP = {
    ERC165: "0x01ffc9a7",
    ERC1155: "0xd9b67a26",
    ERC1155MetadataURI: "0x0e89341c",
    ERC721: "0x80ac58cd",
    ERC721TokenReceiver: "0x150b7a02",
    ERC721Metadata: "0x5b5e139f",
    ERC721Enumerable: "0x780e9d63",
};
const encodeParameters = (types, values) => {
    const abi = new hardhat_1.ethers.utils.AbiCoder();
    return abi.encode(types, values);
};
exports.encodeParameters = encodeParameters;
const extractEvents = (receipt, name) => {
    const events = receipt.events;
    return events.filter((e) => e.event == name);
};
exports.extractEvents = extractEvents;
const extractTokensFromEvents = (events) => {
    const minted = events.reduce((a, e) => {
        if (e.event == "Mint" && e.args && e.args.length > 0) {
            a.push(e.args[0].toNumber());
        }
        return a;
    }, []);
    const burned = events.reduce((a, e) => {
        if (e.event == "Burn" && e.args && e.args.length > 0) {
            a.push(e.args[0].toNumber());
        }
        return a;
    }, []);
    const existing = minted.filter((n) => !burned.includes(n));
    return { minted: minted, burned: burned, existing };
};
exports.extractTokensFromEvents = extractTokensFromEvents;
function supportsInterfaces(interfaces) {
    interfaces.forEach((iface) => {
        describe(iface, function () {
            it("supports the given interface id", function () {
                return __awaiter(this, void 0, void 0, function* () {
                    (0, chai_1.expect)(yield this.contract.supportsInterface(INTERFACE_ID_MAP[iface])).to.be.true;
                });
            });
            it("consumes less than 30k gas", function () {
                return __awaiter(this, void 0, void 0, function* () {
                    const gas = yield this.contract.estimateGas.supportsInterface(INTERFACE_ID_MAP[iface]);
                    (0, chai_1.expect)(gas.lte(ethers_1.BigNumber.from("30000"))).to.be.true;
                });
            });
        });
    });
}
exports.supportsInterfaces = supportsInterfaces;
function getChainId() {
    return __awaiter(this, void 0, void 0, function* () {
        return (yield hardhat_1.ethers.provider.getNetwork()).chainId;
    });
}
exports.getChainId = getChainId;
function startMining() {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("evm_setAutomine", [true]);
    });
}
exports.startMining = startMining;
function stopMining() {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("evm_setAutomine", [false]);
        yield hardhat_1.network.provider.send("evm_setIntervalMining", [0]);
    });
}
exports.stopMining = stopMining;
function mineBlock() {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("evm_mine");
    });
}
exports.mineBlock = mineBlock;
function advanceBlocks(blocks) {
    return __awaiter(this, void 0, void 0, function* () {
        for (let i = 0; i < blocks; i++) {
            yield mineBlock();
        }
    });
}
exports.advanceBlocks = advanceBlocks;
function setNextBlockTimestamp(timestamp) {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    });
}
exports.setNextBlockTimestamp = setNextBlockTimestamp;
function impersonate(address) {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("hardhat_impersonateAccount", [address]);
        return hardhat_1.ethers.getSigner(address);
    });
}
exports.impersonate = impersonate;
function stopImpersonating(address) {
    return __awaiter(this, void 0, void 0, function* () {
        yield hardhat_1.network.provider.send("hardhat_stopImpersonatingAccount", [address]);
    });
}
exports.stopImpersonating = stopImpersonating;
function mintN(token, n) {
    return __awaiter(this, void 0, void 0, function* () {
        for (let i = 0; i < n; i++) {
            yield token.mint();
        }
    });
}
exports.mintN = mintN;
