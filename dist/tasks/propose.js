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
const config_1 = require("hardhat/config");
(0, config_1.task)('propose', 'Create a governance proposal')
    .addOptionalParam('address', 'The Rarity Society DAO proxy address', '0xd3f50dFeCa7CC48E394C0863a4B8559447573608', config_1.types.string)
    .setAction(({ address }, { ethers }) => __awaiter(void 0, void 0, void 0, function* () {
    const factory = yield ethers.getContractFactory('RaritySocietyDAOImpl');
    const dao = yield factory.attach(address);
    const [deployer] = yield ethers.getSigners();
    const val = ethers.utils.parseEther('1');
    const receipt = yield (yield dao.propose([deployer.address], [val], [''], ['0x'], 'Test proposal')).wait();
    console.log(receipt);
}));
