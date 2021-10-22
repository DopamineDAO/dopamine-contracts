import { ethers, network } from "hardhat";
import { Event } from "ethers";
import { expect } from "chai";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { BigNumber } from "ethers";

interface Map {
  [key: string]: string
}

const INTERFACE_ID_MAP: Map = {
	ERC165: '0x01ffc9a7',
	ERC721: '0x80ac58cd',
	ERC721TokenReceiver: '0x150b7a02',
	ERC721Metadata: '0x5b5e139f',
	ERC721Enumerable: '0x780e9d63',
}

export interface ReceiptWithEvents extends TransactionReceipt {
	events: Event[]
}

export type TokensFromEvents = {
  minted: Number[];
  burned: Number[];
  existing: Number[];
};

export const extractEvents = (receipt: TransactionReceipt, name: string) => {
	const events = (receipt as ReceiptWithEvents).events;
	return events.filter((e: Event) => e.event == name);
}

export const extractTokensFromEvents = (events: Event[]) => {
		const minted = events.reduce((a:Number[], e:Event) => {
			if (e.event == 'Mint' && e.args && e.args.length > 0) {
				a.push(e.args[0].toNumber());
			}
			return a;
		}, [])
		const burned = events.reduce((a:Number[], e:Event) => {
			if (e.event == 'Burn' && e.args && e.args.length > 0) {
				a.push(e.args[0].toNumber());
			}
			return a;
		}, [])
		const existing = minted.filter(n => !burned.includes(n));
		return { minted: minted, burned: burned, existing };
}

export function supportsInterfaces(interfaces:string[]) {
	interfaces.forEach( (iface) => {
		describe(iface, function () {
			it('supports the given interface id', async function () {
				expect(await this.contract.supportsInterface(INTERFACE_ID_MAP[iface])).to.be.true;
			});

			it('consumes less than 30k gas', async function () {
				const gas = await this.contract.estimateGas.supportsInterface(INTERFACE_ID_MAP[iface]);
				expect(gas.lte(BigNumber.from("30000"))).to.be.true;
			});
		});
	});
}

export async function getChainId() {
		return (await ethers.provider.getNetwork()).chainId;
}

export async function startMining() {
	await network.provider.send('evm_setAutomine', [true]);
}

export async function stopMining() {
	await network.provider.send('evm_setAutomine', [false]);
	await network.provider.send('evm_setIntervalMining', [0]);
}

export async function mineBlock() {
	await network.provider.send('evm_mine');
}
