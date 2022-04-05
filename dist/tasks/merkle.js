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
const merkletreejs_1 = __importDefault(require("merkletreejs"));
const keccak256_1 = __importDefault(require("keccak256"));
const config_1 = require("hardhat/config");
const ethers_1 = require("ethers");
(0, config_1.task)('merkle', 'Create a merkle distribution')
    .addVariadicPositionalParam('inputs', 'List of address:tokenId pairings', [])
    .setAction(({ inputs }, { ethers }) => __awaiter(void 0, void 0, void 0, function* () {
    const merkleTree = new merkletreejs_1.default(inputs.map((input) => merkleHash(input.split(':')[0], input.split(':')[1])), keccak256_1.default, { sortPairs: true });
    const merkleRoot = merkleTree.getHexRoot();
    process.stdout.write(merkleRoot);
}));
(0, config_1.task)('merkleproof', 'Get merkle proof')
    .addOptionalVariadicPositionalParam('inputs', 'List of address:tokenId pairings', [])
    .addOptionalParam('input', 'String in the format {address}:{id}', '', config_1.types.string)
    .setAction(({ inputs, input }, { ethers }) => __awaiter(void 0, void 0, void 0, function* () {
    const merkleTree = new merkletreejs_1.default(inputs.map((input) => merkleHash(input.split(':')[0], input.split(':')[1])), keccak256_1.default, { sortPairs: true });
    const merkleRoot = merkleTree.getHexRoot();
    const address = input.split(':')[0];
    const id = input.split(':')[1];
    const proof = merkleTree.getHexProof(merkleHash(address, id));
    console.log(proof);
    const encodedProof = ethers_1.utils.defaultAbiCoder.encode(["bytes32[]"], [proof]);
    process.stdout.write(encodedProof);
}));
function merkleHash(address, id) {
    return Buffer.from(ethers_1.utils.solidityKeccak256(["address", "uint256"], [address, id]).slice('0x'.length), 'hex');
}
