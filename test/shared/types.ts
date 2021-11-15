import { BigNumber } from "ethers";
import { Event } from "ethers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";

export type Checkpoint = {
  fromBlock: BigNumber;
  votes: BigNumber;
};

export interface ReceiptWithEvents extends TransactionReceipt {
  events: Event[];
}
