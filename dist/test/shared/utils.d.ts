import { Event } from "ethers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { IRarityPass } from "../../typechain";
export interface ReceiptWithEvents extends TransactionReceipt {
    events: Event[];
}
export declare type TokensFromEvents = {
    minted: number[];
    burned: number[];
    existing: number[];
};
export declare const encodeParameters: (types: string[], values: unknown[]) => string;
export declare const extractEvents: (receipt: TransactionReceipt, name: string) => Event[];
export declare const extractTokensFromEvents: (events: Event[]) => {
    minted: number[];
    burned: number[];
    existing: number[];
};
export declare function supportsInterfaces(interfaces: string[]): void;
export declare function getChainId(): Promise<number>;
export declare function startMining(): Promise<void>;
export declare function stopMining(): Promise<void>;
export declare function mineBlock(): Promise<void>;
export declare function advanceBlocks(blocks: number): Promise<void>;
export declare function setNextBlockTimestamp(timestamp: number): Promise<void>;
export declare function impersonate(address: string): Promise<import("@nomiclabs/hardhat-ethers/signers").SignerWithAddress>;
export declare function stopImpersonating(address: string): Promise<void>;
export declare function mintN(token: IRarityPass, n: number): Promise<void>;
