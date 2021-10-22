import { BigNumber } from "ethers";
import { Event } from "ethers";
import { TransactionResponse, TransactionReceipt } from "@ethersproject/abstract-provider";

export type Checkpoint = {
	fromBlock: BigNumber
	votes: BigNumber
}

export interface ReceiptWithEvents extends TransactionReceipt {
	events: Event[]
}


