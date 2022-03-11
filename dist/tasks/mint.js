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
(0, config_1.task)('mint', 'Mint a Rarity Society NFT')
    .addOptionalParam('address', 'RaritySocietyToken address', '0xE70aDf9B0fbAA03Cee6f61daF6A3ebff46331c9e', config_1.types.string)
    .setAction(({ address }, { ethers }) => __awaiter(void 0, void 0, void 0, function* () {
    const factory = yield ethers.getContractFactory('RaritySocietyToken');
    const token = yield factory.attach(address);
    const receipt = yield (yield token.mint()).wait();
    console.log(receipt);
}));
