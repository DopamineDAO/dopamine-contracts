import { BigNumber, constants } from "ethers";
import {
  TransactionResponse,
  TransactionReceipt,
} from "@ethersproject/abstract-provider";
import { ethers } from "hardhat";
import { Checkpoint } from "./shared/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  startMining,
  stopMining,
  mineBlock,
  extractEvents,
  getChainId,
} from "./shared/utils";
import { expect } from "chai";

const SIGNING_DOMAIN_VERSION = "1";

const TYPES = {
  Delegation: [
    { name: "delegator", type: "address" },
    { name: "delegatee", type: "address" },
    { name: "nonce", type: "uint256" },
    { name: "expiry", type: "uint256" },
  ],
};

const TOKEN_ID_0 = BigNumber.from("0");
const TOKEN_ID_1 = BigNumber.from("1");

const EVENT_DELEGATE_VOTES_CHANGED = "DelegateVotesChanged";
const EVENT_DELEGATE_CHANGED = "DelegateChanged";

type DelegateFn = (
  sender: SignerWithAddress,
  delegatee: string
) => Promise<TransactionResponse>;

export function shouldBehaveLikeERC721Checkpointable(): void {
  describe("ERC721Checkpointable functionality", function () {
    let chainId: BigNumber;
    let verifyingContract: string;
    let domainName: string;

    const delegate = async function (
      this: Mocha.Context,
      sender: SignerWithAddress,
      delegatee: string
    ) {
      return await this.token.connect(sender).delegate(delegatee);
    };

    const delegateBySig = async function (
      this: Mocha.Context,
      sender: SignerWithAddress,
      delegatee: string
    ) {
      const nonce = await this.contract.nonces(sender.address);
      const expiry = 10e9;
      const sig = await sender._signTypedData(
        {
          name: domainName,
          chainId: chainId,
          verifyingContract: verifyingContract,
          version: SIGNING_DOMAIN_VERSION,
        },
        TYPES,
        { delegator: sender.address, delegatee: delegatee, nonce: nonce, expiry: expiry }
      );
      const { v, r, s } = ethers.utils.splitSignature(sig);
      return await this.token
        .connect(sender)
        .delegateBySig(sender.address, delegatee, expiry, v, r, s);
    };

    beforeEach(async function () {
      chainId = BigNumber.from(await getChainId());
      domainName = await this.token.name();
      verifyingContract = this.token.address;
    });

    describe("delegation", function () {
      const expectedDelegationBehavior = function (delegateFunc: DelegateFn) {
        context(
          "when delegating with a non-zero balance to another address",
          function () {
            let tx: TransactionResponse;
            let rx: TransactionReceipt;
            let mintTx: TransactionResponse;
            let mintRx: TransactionReceipt;

            beforeEach(async function () {
              mintTx = await this.token.mint();
              mintRx = await mintTx.wait();
              tx = await delegateFunc.bind(this)(this.from, this.to.address);
              rx = await tx.wait();
              await mineBlock();
            });

            it("should correctly reassign delegatee of the delegator", async function () {
              expect(await this.token.delegates(this.from.address)).to.equal(
                this.to.address
              );
            });

            it("should emit a single DelegateChanged event", async function () {
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_CHANGED)
                .withArgs(
                  this.from.address,
                  this.from.address,
                  this.to.address
                );
              expect(extractEvents(rx, EVENT_DELEGATE_CHANGED).length).to.equal(
                1
              );
            });

            it("should emit two DelegateVotesChanged events", async function () {
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 1, 0);
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 0, 1);
              expect(
                extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
            });

            it("should reduce the vote balance of the delegator", async function () {
              expect(
                await this.token.getCurrentVotes(this.from.address)
              ).to.equal(0);
            });

            it("should increase the vote balance of the delgatee", async function () {
              expect(
                await this.token.getCurrentVotes(this.to.address)
              ).to.equal(1);
            });

            it("should add another checkpoint for the delegator", async function () {
              expect(
                await this.token.numCheckpoints(this.from.address)
              ).to.equal(2);
              const mintCp: Checkpoint = await this.token.checkpoints(
                this.from.address,
                0
              );
              const cp: Checkpoint = await this.token.checkpoints(
                this.from.address,
                1
              );
              expect(mintCp.fromBlock).to.equal(mintRx.blockNumber);
              expect(mintCp.votes).to.equal(1);
              expect(cp.fromBlock).to.equal(rx.blockNumber);
              expect(cp.votes).to.equal(0);
            });

            it("should add a single checkpoint for the delegatee", async function () {
              expect(await this.token.numCheckpoints(this.to.address)).to.equal(
                1
              );
              const cp: Checkpoint = await this.token.checkpoints(
                this.to.address,
                0
              );
              expect(cp.fromBlock).to.equal(rx.blockNumber);
              expect(cp.votes).to.equal(1);
            });

            it("should correctly retrieve prior votes", async function () {
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  mintRx.blockNumber - 1
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  mintRx.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  rx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  mintRx.blockNumber - 1
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  mintRx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(this.to.address, rx.blockNumber)
              ).to.equal(1);
            });
          }
        );

        context("when self-delegating", function () {
          let tx: TransactionResponse;
          let rx: TransactionReceipt;
          let mintRx: TransactionReceipt;

          beforeEach(async function () {
            mintRx = await (await this.token.mint()).wait();
            tx = await delegateFunc.bind(this)(this.from, constants.AddressZero);
            rx = await tx.wait();
            await mineBlock();
          });

          it("should correctly reassign delegatee of the delegator", async function () {
            expect(await this.token.delegates(this.from.address)).to.equal(
              this.from.address
            );
          });

          it("should emit a single DelegateChanged event", async function () {
            expect(tx)
              .to.emit(this.token, EVENT_DELEGATE_CHANGED)
              .withArgs(
                this.from.address,
                this.from.address,
                this.from.address
              );
            expect(extractEvents(rx, EVENT_DELEGATE_CHANGED).length).to.equal(
              1
            );
          });

          it("should emit no DelegateVotesChanged events", async function () {
            expect(tx).not.to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED);
          });

          it("should maintain the vote balance of the delegator", async function () {
            expect(
              await this.token.getCurrentVotes(this.from.address)
            ).to.equal(1);
          });

          it("should not add a checkpoint for the delegator", async function () {
            expect(await this.token.numCheckpoints(this.from.address)).to.equal(
              1
            );
            const cp: Checkpoint = await this.token.checkpoints(
              this.from.address,
              0
            );
            expect(cp.fromBlock).to.equal(mintRx.blockNumber);
            expect(cp.votes).to.equal(1);
          });

          it("should correctly retrieve prior votes", async function () {
            expect(
              await this.token.getPriorVotes(
                this.from.address,
                mintRx.blockNumber
              )
            ).to.equal(1);
            expect(
              await this.token.getPriorVotes(
                this.from.address,
                mintRx.blockNumber - 1
              )
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(this.from.address, rx.blockNumber)
            ).to.equal(1);
          });
        });

        context("when delegating with a zero balance", function () {
          let tx: TransactionResponse;
          let rx: TransactionReceipt;

          beforeEach(async function () {
            tx = await delegateFunc.bind(this)(this.from, this.to.address);
            rx = await tx.wait();
            await mineBlock();
          });

          it("should correctly reassign delegatee of the delegator", async function () {
            expect(await this.token.delegates(this.from.address)).to.equal(
              this.to.address
            );
          });

          it("should emit a single DelegateChanged event", async function () {
            expect(tx)
              .to.emit(this.token, EVENT_DELEGATE_CHANGED)
              .withArgs(this.from.address, this.from.address, this.to.address);
            expect(extractEvents(rx, EVENT_DELEGATE_CHANGED).length).to.equal(
              1
            );
          });

          it("should emit no DelegateVotesChanged events", async function () {
            expect(tx).not.to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED);
            expect(
              extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED).length
            ).to.equal(0);
          });

          it("should maintain the zero vote balance of the delegator", async function () {
            expect(
              await this.token.getCurrentVotes(this.from.address)
            ).to.equal(0);
          });

          it("should maintain the balance of the delgatee", async function () {
            expect(await this.token.getCurrentVotes(this.to.address)).to.equal(
              0
            );
          });

          it("should result in no added checkpoints", async function () {
            expect(await this.token.numCheckpoints(this.from.address)).to.equal(
              0
            );
            expect(await this.token.numCheckpoints(this.to.address)).to.equal(
              0
            );
          });

          it("should correctly retrieve prior votes", async function () {
            expect(
              await this.token.getPriorVotes(
                this.from.address,
                rx.blockNumber - 1
              )
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(this.from.address, rx.blockNumber)
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(
                this.to.address,
                rx.blockNumber - 1
              )
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(this.to.address, rx.blockNumber)
            ).to.equal(0);
          });
        });

        context(
          "when sender delegates prior to transferring a token",
          function () {
            let transferTx: TransactionResponse;
            let transferRx: TransactionReceipt;
            let tx: TransactionResponse;
            let rx: TransactionReceipt;

            beforeEach(async function () {
              this.delegate = this.operator;
              await (await this.token.mint()).wait();
              tx = await delegateFunc.bind(this)(
                this.from,
                this.delegate.address
              );
              rx = await tx.wait();
              transferTx = await this.token.transferFrom(
                this.from.address,
                this.to.address,
                TOKEN_ID_0
              );
              transferRx = await transferTx.wait();
              await mineBlock();
            });

            it("should emit a single DelegateChanged event", async function () {
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_CHANGED)
                .withArgs(
                  this.from.address,
                  this.from.address,
                  this.delegate.address
                );
              expect(extractEvents(rx, EVENT_DELEGATE_CHANGED).length).to.equal(
                1
              );
              expect(
                extractEvents(transferRx, EVENT_DELEGATE_CHANGED).length
              ).to.equal(0);
            });

            it("should emit four DelegateVotesChanged events", async function () {
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 0, 1);
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 1, 0);
              expect(
                extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
              expect(transferTx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 1, 0);
              expect(transferTx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 0, 1);
              expect(
                extractEvents(transferRx, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
            });

            it("should decrease sender voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.from.address)
              ).to.equal(0);
            });

            it("should decrease delegate voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.delegate.address)
              ).to.equal(0);
            });

            it("should increase receiver voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.to.address)
              ).to.equal(1);
            });

            it("should add a single additional checkpoint for the sender", async function () {
              expect(
                await this.token.numCheckpoints(this.from.address)
              ).to.equal(2);
              const cp: Checkpoint = await this.token.checkpoints(
                this.from.address,
                1
              );
              expect(cp.fromBlock).to.equal(rx.blockNumber);
              expect(cp.votes).to.equal(0);
            });

            it("should add two checkpoints for the delegatee", async function () {
              expect(
                await this.token.numCheckpoints(this.delegate.address)
              ).to.equal(2);
              const delegateCp: Checkpoint = await this.token.checkpoints(
                this.delegate.address,
                0
              );
              expect(delegateCp.fromBlock).to.equal(rx.blockNumber);
              expect(delegateCp.votes).to.equal(1);
              const transferCp: Checkpoint = await this.token.checkpoints(
                this.delegate.address,
                1
              );
              expect(transferCp.fromBlock).to.equal(transferRx.blockNumber);
              expect(transferCp.votes).to.equal(0);
            });

            it("should add a single checkpoint for the receiver", async function () {
              expect(await this.token.numCheckpoints(this.to.address)).to.equal(
                1
              );
              const cp: Checkpoint = await this.token.checkpoints(
                this.to.address,
                0
              );
              expect(cp.fromBlock).to.equal(transferRx.blockNumber);
              expect(cp.votes).to.equal(1);
            });

            it("should correctly retrieve prior votes", async function () {
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  rx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  rx.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(this.to.address, rx.blockNumber)
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  transferRx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  transferRx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  transferRx.blockNumber
                )
              ).to.equal(1);
            });
          }
        );

        context(
          "when receiver delegates prior to receiving a token",
          function () {
            let transferTx: TransactionResponse;
            let transferRx: TransactionReceipt;
            let tx: TransactionResponse;
            let rx: TransactionReceipt;

            beforeEach(async function () {
              this.delegate = this.operator;
              await (await this.token.mint()).wait();
              tx = await delegateFunc.bind(this)(
                this.to,
                this.delegate.address
              );
              rx = await tx.wait();
              transferTx = await this.token.transferFrom(
                this.from.address,
                this.to.address,
                TOKEN_ID_0
              );
              transferRx = await transferTx.wait();
              await mineBlock();
            });

            it("should emit a single DelegateChanged event", async function () {
              expect(tx)
                .to.emit(this.token, EVENT_DELEGATE_CHANGED)
                .withArgs(
                  this.to.address,
                  this.to.address,
                  this.delegate.address
                );
              expect(extractEvents(rx, EVENT_DELEGATE_CHANGED).length).to.equal(
                1
              );
              expect(
                extractEvents(transferRx, EVENT_DELEGATE_CHANGED).length
              ).to.equal(0);
            });

            it("should emit two DelegateVotesChanged events", async function () {
              expect(
                extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(0);
              expect(transferTx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 0, 1);
              expect(transferTx)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 1, 0);
              expect(
                extractEvents(transferRx, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
            });

            it("should decrease sender voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.from.address)
              ).to.equal(0);
            });

            it("should decrease receiver voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.delegate.address)
              ).to.equal(1);
            });

            it("should increase delegate voting balance", async function () {
              expect(
                await this.token.getCurrentVotes(this.delegate.address)
              ).to.equal(1);
            });

            it("should add a single additional checkpoint for the sender", async function () {
              expect(
                await this.token.numCheckpoints(this.from.address)
              ).to.equal(2);
              const cp: Checkpoint = await this.token.checkpoints(
                this.from.address,
                1
              );
              expect(cp.fromBlock).to.equal(transferRx.blockNumber);
              expect(cp.votes).to.equal(0);
            });

            it("should add a single checkpoint for the delegatee", async function () {
              expect(
                await this.token.numCheckpoints(this.delegate.address)
              ).to.equal(1);
              const delegateCp: Checkpoint = await this.token.checkpoints(
                this.delegate.address,
                0
              );
              expect(delegateCp.fromBlock).to.equal(transferRx.blockNumber);
              expect(delegateCp.votes).to.equal(1);
            });

            it("should add no checkpoints for the receiver", async function () {
              expect(
                await this.token.numCheckpoints(this.receiver.address)
              ).to.equal(0);
            });

            it("should correctly retrieve prior votes", async function () {
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  rx.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  rx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(this.to.address, rx.blockNumber)
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  transferRx.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  transferRx.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  transferRx.blockNumber
                )
              ).to.equal(0);
            });
          }
        );

        context(
          "when multiple transfers and delegations coincide among multiple blocks",
          function () {
            let transferTx1: TransactionResponse;
            let transferRx1: TransactionReceipt;
            let transferTx2: TransactionResponse;
            let transferRx2: TransactionReceipt;
            let delegateTx3: TransactionResponse;
            let delegateRx3: TransactionReceipt;
            let delegateTx4: TransactionResponse;
            let delegateRx4: TransactionReceipt;
            let transferTx5: TransactionResponse;
            let transferRx5: TransactionReceipt;

            beforeEach(async function () {
              this.delegate = this.operator;
              await (await this.token.mint()).wait();
              await (await this.token.mint()).wait();
              await (await this.token.mint()).wait();

              await stopMining();

              transferTx1 = await this.token.transferFrom(
                this.from.address,
                this.to.address,
                TOKEN_ID_0
              );
              transferTx2 = await this.token.transferFrom(
                this.from.address,
                this.delegate.address,
                TOKEN_ID_1
              );

              await mineBlock();

              transferRx1 = await transferTx1.wait();
              transferRx2 = await transferTx2.wait();

              delegateTx3 = await delegateFunc.bind(this)(
                this.from,
                this.to.address
              );

              await mineBlock();

              delegateRx3 = await delegateTx3.wait();

              delegateTx4 = await delegateFunc.bind(this)(
                this.to,
                this.delegate.address
              );

              await mineBlock();

              delegateRx4 = await delegateTx4.wait();

              transferTx5 = await this.token
                .connect(this.delegate)
                .transferFrom(
                  this.delegate.address,
                  this.from.address,
                  TOKEN_ID_1
                );

              await mineBlock();
              transferRx5 = await transferTx5.wait();

              await startMining();
              await mineBlock();
            });

            it("should emit the appropriate DelegateChanged events", async function () {
              expect(
                extractEvents(transferRx1, EVENT_DELEGATE_CHANGED).length
              ).to.equal(0);
              expect(
                extractEvents(transferRx2, EVENT_DELEGATE_CHANGED).length
              ).to.equal(0);
              expect(delegateTx3)
                .to.emit(this.token, EVENT_DELEGATE_CHANGED)
                .withArgs(
                  this.from.address,
                  this.from.address,
                  this.to.address
                );
              expect(
                extractEvents(delegateRx3, EVENT_DELEGATE_CHANGED).length
              ).to.equal(1);
              expect(delegateTx4)
                .to.emit(this.token, EVENT_DELEGATE_CHANGED)
                .withArgs(
                  this.to.address,
                  this.to.address,
                  this.delegate.address
                );
              expect(
                extractEvents(delegateRx4, EVENT_DELEGATE_CHANGED).length
              ).to.equal(1);
              expect(
                extractEvents(transferRx5, EVENT_DELEGATE_CHANGED).length
              ).to.equal(0);
            });

            it("should emit the appropriate DelegateVotesChanged events", async function () {
              expect(transferTx1)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 3, 2);
              expect(transferTx1)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 0, 1);
              expect(
                extractEvents(transferRx1, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
              expect(transferTx2)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 2, 1);
              expect(transferTx2)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 0, 1);
              expect(
                extractEvents(transferRx2, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
              expect(delegateTx3)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.from.address, 1, 0);
              expect(delegateTx3)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 1, 2);
              expect(
                extractEvents(delegateRx3, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
              expect(delegateTx4)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 2, 1);
              expect(delegateTx4)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 1, 2);
              expect(
                extractEvents(delegateRx4, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
              expect(transferTx5)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.delegate.address, 2, 1);
              expect(transferTx5)
                .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
                .withArgs(this.to.address, 1, 2);
              expect(
                extractEvents(transferRx5, EVENT_DELEGATE_VOTES_CHANGED).length
              ).to.equal(2);
            });

            it("should adjust voting balances appropriately", async function () {
              expect(
                await this.token.getCurrentVotes(this.from.address)
              ).to.equal(0);
              expect(
                await this.token.getCurrentVotes(this.delegate.address)
              ).to.equal(1);
              expect(
                await this.token.getCurrentVotes(this.to.address)
              ).to.equal(2);
            });

            it("should add the appropriate number of checkpoints", async function () {
              // 3 for each mint, 1 for the first two transfers (same block), 1 for the delegation
              expect(
                await this.token.numCheckpoints(this.from.address)
              ).to.equal(5);
              let cp: Checkpoint = await this.token.checkpoints(
                this.from.address,
                3
              );
              expect(cp.fromBlock).to.equal(transferRx2.blockNumber);
              expect(cp.fromBlock).to.equal(transferRx1.blockNumber);
              expect(cp.votes).to.equal(1);
              cp = await this.token.checkpoints(this.from.address, 4);
              expect(cp.fromBlock).to.equal(delegateRx3.blockNumber);
              expect(cp.votes).to.equal(0);

              expect(await this.token.numCheckpoints(this.to.address)).to.equal(
                4
              );
              cp = await this.token.checkpoints(this.to.address, 0);
              expect(cp.fromBlock).to.equal(transferRx1.blockNumber);
              expect(cp.votes).to.equal(1);
              cp = await this.token.checkpoints(this.to.address, 1);
              expect(cp.fromBlock).to.equal(delegateRx3.blockNumber);
              expect(cp.votes).to.equal(2);
              cp = await this.token.checkpoints(this.to.address, 2);
              expect(cp.fromBlock).to.equal(delegateRx4.blockNumber);
              expect(cp.votes).to.equal(1);
              cp = await this.token.checkpoints(this.to.address, 3);
              expect(cp.fromBlock).to.equal(transferRx5.blockNumber);
              expect(cp.votes).to.equal(2);

              expect(
                await this.token.numCheckpoints(this.delegate.address)
              ).to.equal(3);
              cp = await this.token.checkpoints(this.delegate.address, 0);
              expect(cp.fromBlock).to.equal(transferRx2.blockNumber);
              expect(cp.votes).to.equal(1);
              cp = await this.token.checkpoints(this.delegate.address, 1);
              expect(cp.fromBlock).to.equal(delegateRx4.blockNumber);
              expect(cp.votes).to.equal(2);
              cp = await this.token.checkpoints(this.delegate.address, 2);
              expect(cp.fromBlock).to.equal(transferRx5.blockNumber);
              expect(cp.votes).to.equal(1);
            });

            it("should correctly retrieve prior votes", async function () {
              // transferTx1 / transferTx2.block
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  transferRx1.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  transferRx1.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  transferRx1.blockNumber
                )
              ).to.equal(1);

              // delegateTx3.block
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  delegateRx3.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  delegateRx3.blockNumber
                )
              ).to.equal(2);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  delegateRx3.blockNumber
                )
              ).to.equal(1);

              // delegateTx4.block
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  delegateRx4.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  delegateRx4.blockNumber
                )
              ).to.equal(1);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  delegateRx4.blockNumber
                )
              ).to.equal(2);

              // transferTx5.block
              expect(
                await this.token.getPriorVotes(
                  this.from.address,
                  transferRx5.blockNumber
                )
              ).to.equal(0);
              expect(
                await this.token.getPriorVotes(
                  this.to.address,
                  transferRx5.blockNumber
                )
              ).to.equal(2);
              expect(
                await this.token.getPriorVotes(
                  this.delegate.address,
                  transferRx5.blockNumber
                )
              ).to.equal(1);
            });
          }
        );
      };

      context(
        "when transferring tokens without explicit delegation",
        function () {
          let tx: TransactionResponse;
          let rx: TransactionReceipt;

          beforeEach(async function () {
            await (await this.token.mint()).wait();
            tx = await this.token.transferFrom(
              this.from.address,
              this.to.address,
              TOKEN_ID_0
            );
            rx = await tx.wait();
            await mineBlock();
          });

          it("should emit no DelegateChanged events", async function () {
            expect(tx).not.to.emit(this.token, EVENT_DELEGATE_CHANGED);
          });

          it("should emit two DelegateVotesChanged events", async function () {
            expect(tx)
              .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
              .withArgs(this.to.address, 0, 1);
            expect(tx)
              .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
              .withArgs(this.from.address, 1, 0);
            expect(
              extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED).length
            ).to.equal(2);
          });

          it("should decrease sender voting balance", async function () {
            expect(
              await this.token.getCurrentVotes(this.from.address)
            ).to.equal(0);
          });

          it("should increase receiver voting balance", async function () {
            expect(await this.token.getCurrentVotes(this.to.address)).to.equal(
              1
            );
          });

          it("should add a checkpoint for the sender", async function () {
            expect(await this.token.numCheckpoints(this.from.address)).to.equal(
              2
            );
            const cp: Checkpoint = await this.token.checkpoints(
              this.from.address,
              1
            );
            expect(cp.fromBlock).to.equal(rx.blockNumber);
            expect(cp.votes).to.equal(0);
          });

          it("should add a checkpoint for the receiver", async function () {
            expect(await this.token.numCheckpoints(this.to.address)).to.equal(
              1
            );
            const cp: Checkpoint = await this.token.checkpoints(
              this.to.address,
              0
            );
            expect(cp.fromBlock).to.equal(rx.blockNumber);
            expect(cp.votes).to.equal(1);
          });

          it("should correctly retrieve prior votes", async function () {
            expect(
              await this.token.getPriorVotes(
                this.from.address,
                rx.blockNumber - 1
              )
            ).to.equal(1);
            expect(
              await this.token.getPriorVotes(this.from.address, rx.blockNumber)
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(
                this.to.address,
                rx.blockNumber - 1
              )
            ).to.equal(0);
            expect(
              await this.token.getPriorVotes(this.to.address, rx.blockNumber)
            ).to.equal(1);
          });
        }
      );

      context("when minting without explicit delegation", function () {
        let tx: TransactionResponse;
        let rx: TransactionReceipt;

        beforeEach(async function () {
          tx = await this.token.mint();
          rx = await tx.wait();
        });

        it("should ensure delegator's delegate is themself", async function () {
          expect(await this.token.delegates(this.from.address)).to.equal(
            this.from.address
          );
        });

        it("should return a voting balance equal to number of tokens held", async function () {
          expect(await this.token.getCurrentVotes(this.from.address)).to.equal(
            1
          );
        });

        it("should return a voting balance of 0 for accounts with no token balance", async function () {
          expect(await this.token.getCurrentVotes(this.to.address)).to.equal(0);
        });

        it("should ensure voting allocations of 0 for blocks existing prior to minting", async function () {
          const blockNum = rx.blockNumber;
          expect(
            await this.token.getPriorVotes(this.from.address, blockNum - 1)
          ).to.equal(0);
        });

        it("ensures existence of a single checkpoint for an address with a single token mint", async function () {
          expect(await this.token.numCheckpoints(this.from.address)).to.equal(
            1
          );
          const cp: Checkpoint = await this.token.checkpoints(
            this.from.address,
            0
          );
          expect(cp.fromBlock).to.equal(rx.blockNumber);
          expect(cp.votes).to.equal(1);
        });

        it("should allocate 0 checkpoints for addresses with no tokens", async function () {
          expect(await this.token.numCheckpoints(this.to.address)).to.equal(0);
        });

        it("should emit a single DelegateVotesChanged event", async function () {
          expect(tx)
            .to.emit(this.token, EVENT_DELEGATE_VOTES_CHANGED)
            .withArgs(this.from.address, 0, 1);
          expect(tx).not.to.emit(this.token, EVENT_DELEGATE_CHANGED);
          const events = extractEvents(rx, EVENT_DELEGATE_VOTES_CHANGED);
          expect(events.length).to.equal(1);
        });
      });

      context("when delegating", function () {
        describe("delegate()", function () {
          expectedDelegationBehavior(delegate);
        });

        describe("delegateBySig()", function () {
          expectedDelegationBehavior(delegateBySig);

          it("initializes nonce with value 0", async function () {
            expect(await this.token.nonces(this.sender.address)).to.equal(0);
          });

          it("rejects expired signatures", async function () {
            const nonce = await this.contract.nonces(this.sender.address);
            const expiry = 0;
            const sig = await this.sender._signTypedData(
              {
                name: domainName,
                chainId: chainId,
                verifyingContract: verifyingContract,
                version: SIGNING_DOMAIN_VERSION,
              },
              TYPES,
              { delegator: this.sender.address, delegatee: this.to.address, nonce: nonce, expiry: expiry }
            );
            const { v, r, s } = ethers.utils.splitSignature(sig);
            await expect(
              this.token.delegateBySig(this.sender.address, this.to.address, expiry, v, r, s)
            ).to.be.revertedWith(
              "ERC721Checkpointable::delegateBySig: signature expired"
            );
          });

          it("rejects signature reuse", async function () {
            const nonce = await this.contract.nonces(this.sender.address);
            const expiry = 10e9;
            const sig = await this.sender._signTypedData(
              {
                name: domainName,
                chainId: chainId,
                verifyingContract: verifyingContract,
                version: SIGNING_DOMAIN_VERSION,
              },
              TYPES,
              { delegator: this.sender.address, delegatee: this.to.address, nonce: nonce, expiry: expiry }
            );
            const { v, r, s } = ethers.utils.splitSignature(sig);
            await this.token.delegateBySig(
							this.sender.address,
              this.to.address,
              expiry,
              v,
              r,
              s
            );
            await expect(
              this.token.delegateBySig(
								this.sender.address,
                this.to.address,
                expiry,
                v,
                r,
                s
              )
            ).to.be.revertedWith(
              "invalid signature"
            );
          });

          it("rejects delegating delegatees different from that signed", async function () {
            const nonce = await this.contract.nonces(this.sender.address);
            const expiry = 10e9;
            const sig = await this.sender._signTypedData(
              {
                name: domainName,
                chainId: chainId,
                verifyingContract: verifyingContract,
                version: SIGNING_DOMAIN_VERSION,
              },
              TYPES,
              { delegator: this.sender.address, delegatee: this.to.address, nonce: nonce, expiry: expiry }
            );
            const { v, r, s } = ethers.utils.splitSignature(sig);
            await expect(
							this.token.delegateBySig(
								this.sender.address,
								this.operator.address,
								expiry,
								v,
								r,
								s
							)
            ).to.be.revertedWith(
              "invalid signature"
            );
          });
        });
      });

      context("numCheckpoints()", function () {
        it("returns 0 for accounts with no checkpoints", async function () {
          expect(await this.token.numCheckpoints(this.to.address)).to.equal(0);
        });
      });

      context("getCurrentVotes()", function () {
        it("returns 0 for accounts with no checkpoints", async function () {
          expect(await this.token.numCheckpoints(this.to.address)).to.equal(0);
        });
      });

      context("getPriorVotes()", function () {
        let tx: TransactionResponse;
        let rx: TransactionReceipt;

        beforeEach(async function () {
          await (await this.token.mint()).wait();
          tx = await this.token.delegate(this.to.address);
          rx = await tx.wait();
        });

        it("throws when querying for the current block", async function () {
          await expect(
            this.token.getPriorVotes(this.from.address, rx.blockNumber)
          ).to.be.revertedWith(
            "ERC721Checkpointable::getPriorVotes: not yet determined"
          );
        });

        it("returns 0 for valid queries to addresses with no prior votes", async function () {
          expect(
            await this.token.getPriorVotes(this.to.address, rx.blockNumber - 1)
          ).to.equal(0);
        });
      });
    });

		describe("uint32 downcasting functionality", function () {
			it("throws when given a uint whose value does not fit within 32 bytes", async function () {
					await expect(
            this.token.testSafe32(BigNumber.from(0xFFFFFFFF).add(1))
					).to.be.revertedWith(
						"value does not fit within 32 bits"
					);
			});
			it("does not throw when given a number less than or equal to the uint32 max", async function () {
					await expect(
            this.token.testSafe32(BigNumber.from(0xFFFFFFFF))
					).not.to.be.reverted;
			});
		});

  });
}
