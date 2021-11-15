import { utils, constants } from "ethers";
import { expect } from "chai";
import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { Timelock__factory } from "../typechain";
import { timelockFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  stopMining,
  startMining,
  setNextBlockTimestamp,
  impersonate,
  stopImpersonating,
  encodeParameters,
  mineBlock,
} from "./shared/utils";

const { createFixtureLoader } = waffle;

const TIMELOCK_GRACE_PERIOD = 60 * 60 * 24 * 14; // 2 days
const TIMELOCK_MIN_DELAY = 60 * 60 * 24 * 2; // 2 days
const TIMELOCK_DELAY = 60 * 60 * 24 * 3; // 3 days
const TIMELOCK_MAX_DELAY = 60 * 60 * 24 * 30; // 30 days

const EVENT_NEW_DELAY = "NewDelay";
const EVENT_NEW_ADMIN = "NewAdmin";
const EVENT_NEW_PENDING_ADMIN = "NewPendingAdmin";
const EVENT_QUEUE_TRANSACTION = "QueueTransaction";
const EVENT_CANCEL_TRANSACTION = "CancelTransaction";
const EVENT_EXECUTE_TRANSACTION = "ExecuteTransaction";

describe("Timelock", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.admin] = signers;

    loadFixture = createFixtureLoader([this.deployer] as Signer[] as Wallet[]);
  });

  describe("Constructor", function () {
    it("reverts when passing in a delay less than the minimum delay", async function () {
      await expect(
        new Timelock__factory(this.deployer).deploy(
          this.deployer.address,
          TIMELOCK_MIN_DELAY - 1
        )
      ).to.be.revertedWith("Delay exceeds min delay");
    });

    it("reverts when passing in a delay exceeding maximum delay", async function () {
      await expect(
        new Timelock__factory(this.deployer).deploy(
          this.deployer.address,
          TIMELOCK_MAX_DELAY + 1
        )
      ).to.be.revertedWith("Delay exceeds max delay");
    });

    it("does not revert when passing a valid delay", async function () {
      await expect(
        new Timelock__factory(this.deployer).deploy(
          this.deployer.address,
          TIMELOCK_DELAY
        )
      ).not.to.be.reverted;
    });
  });

  describe("Functions", function () {
    beforeEach("instantiate timelock fixture", async function () {
      this.timelock = await loadFixture(timelockFixture);
    });

    context("variable initialization", function () {
      it("correctly sets admin", async function () {
        expect(await this.timelock.admin()).to.equal(this.deployer.address);
      });

      it("correctly sets the delay", async function () {
        expect(await this.timelock.delay()).to.equal(TIMELOCK_DELAY);
      });

      it("initializes the pending admin to the zero address", async function () {
        expect(await this.timelock.pendingAdmin()).to.equal(
          constants.AddressZero
        );
      });
    });

    context("receiving ether", function () {
      it("allows receiving of ether via receive()", async function () {
        await expect(
          this.deployer.sendTransaction({
            to: this.timelock.address,
            value: utils.parseEther("1.0"),
          })
        ).not.to.be.reverted;
        expect(
          await ethers.provider.getBalance(this.timelock.address)
        ).to.equal(utils.parseEther("1.0"));
      });

      it("allows receiving of ether via fallback()", async function () {
        await expect(
          this.deployer.sendTransaction({
            to: this.timelock.address,
            value: utils.parseEther("1.0"),
            data: "0xdeadbeef",
          })
        ).not.to.be.reverted;
        expect(
          await ethers.provider.getBalance(this.timelock.address)
        ).to.equal(utils.parseEther("1.0"));
      });
    });

    describe("setDelay()", function () {
      context("when not invoked via the contract", function () {
        it("throws", async function () {
          await expect(
            this.timelock.setDelay(TIMELOCK_DELAY)
          ).to.be.revertedWith("Call must come from Timelock");
        });
      });

      context("when invoked via the contract itself", function () {
        let contractSigner: SignerWithAddress;

        beforeEach(async function () {
          contractSigner = await impersonate(this.timelock.address);
          await this.deployer.sendTransaction({
            to: contractSigner.address,
            value: utils.parseEther("1.0"),
          });
        });

        afterEach(async function () {
          await stopImpersonating(this.timelock.address);
        });

        it("throws when delay is below min delay", async function () {
          await expect(
            this.timelock
              .connect(contractSigner)
              .setDelay(TIMELOCK_MIN_DELAY - 1)
          ).to.be.revertedWith("Delay exceeds min delay");
        });

        it("throws when delay is above max delay", async function () {
          await expect(
            this.timelock
              .connect(contractSigner)
              .setDelay(TIMELOCK_MAX_DELAY + 1)
          ).to.be.revertedWith("Delay exceeds max delay");
        });

        it("correctly sets the delay", async function () {
          await this.timelock
            .connect(contractSigner)
            .setDelay(TIMELOCK_DELAY + 1);
          expect(await this.timelock.delay()).to.equal(TIMELOCK_DELAY + 1);
        });

        it("emits a NewDelay event", async function () {
          const tx = await this.timelock
            .connect(contractSigner)
            .setDelay(TIMELOCK_DELAY + 1);
          expect(tx)
            .to.emit(this.timelock, EVENT_NEW_DELAY)
            .withArgs(TIMELOCK_DELAY, TIMELOCK_DELAY + 1);
        });
      });
    });

    describe("setPendingAdmin()", function () {
      context("when not invoked via the contract", function () {
        it("throws", async function () {
          await expect(
            this.timelock.setPendingAdmin(this.deployer.address)
          ).to.be.revertedWith("must call from timelock");
        });
      });

      context("when invoked via the contract itself", function () {
        let contractSigner: SignerWithAddress;

        beforeEach(async function () {
          contractSigner = await impersonate(this.timelock.address);
          await this.deployer.sendTransaction({
            to: contractSigner.address,
            value: utils.parseEther("1.0"),
          });
        });

        afterEach(async function () {
          await stopImpersonating(this.timelock.address);
        });

        it("correctly sets the pending admin", async function () {
          await this.timelock
            .connect(contractSigner)
            .setPendingAdmin(this.deployer.address);
          expect(await this.timelock.pendingAdmin()).to.equal(
            this.deployer.address
          );
        });

        it("emits a NewPendingAdmin event", async function () {
          const tx = await this.timelock
            .connect(contractSigner)
            .setPendingAdmin(this.deployer.address);
          expect(tx)
            .to.emit(this.timelock, EVENT_NEW_PENDING_ADMIN)
            .withArgs(constants.AddressZero, this.deployer.address);
        });
      });
    });

    describe("acceptAdmin()", function () {
      beforeEach(async function () {
        const contractSigner = await impersonate(this.timelock.address);
        await this.deployer.sendTransaction({
          to: contractSigner.address,
          value: utils.parseEther("1.0"),
        });
        await this.timelock
          .connect(contractSigner)
          .setPendingAdmin(this.admin.address);
        await stopImpersonating(this.timelock.address);
      });

      context("when not called by the pending admin", function () {
        it("throws", async function () {
          await expect(this.timelock.acceptAdmin()).to.be.revertedWith(
            "Call must come from pending admin"
          );
        });
      });

      context("when called by the pending admin", function () {
        let tx: TransactionResponse;

        beforeEach(async function () {
          tx = await this.timelock.connect(this.admin).acceptAdmin();
        });

        it("assigns the admin to the pending admin", async function () {
          expect(await this.timelock.admin()).to.equal(this.admin.address);
        });

        it("resets the pending admin to the zero address", async function () {
          expect(await this.timelock.pendingAdmin()).to.equal(
            constants.AddressZero
          );
        });

        it("emits a NewPendingAdmin event", async function () {
          expect(tx)
            .to.emit(this.timelock, EVENT_NEW_PENDING_ADMIN)
            .withArgs(this.admin.address, constants.AddressZero);
        });

        it("emits a NewAdmin event", async function () {
          expect(tx)
            .to.emit(this.timelock, EVENT_NEW_ADMIN)
            .withArgs(this.deployer.address, this.admin.address);
        });
      });
    });

    context("when performing transactional operations", function () {
      const value = String(0);
      const signature = "setDelay(uint256)";
      const callData: string = encodeParameters(
        ["uint256"],
        [TIMELOCK_MAX_DELAY]
      );
      let timestamp: number;
      let txHash: string;

      beforeEach(async function () {
        timestamp = (await ethers.provider.getBlock("latest")).timestamp + 1;
        await setNextBlockTimestamp(timestamp);
        txHash = utils.keccak256(
          encodeParameters(
            ["address", "uint256", "string", "bytes", "uint256"],
            [
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY,
            ]
          )
        );
      });

      describe("queueTransaction()", function () {
        context("when not called by the admin", function () {
          it("throws", async function () {
            await expect(
              this.timelock
                .connect(this.admin)
                .queueTransaction(
                  this.timelock.address,
                  value,
                  signature,
                  callData,
                  0
                )
            ).to.be.revertedWith("admin only");
          });
        });

        context("when called by the admin", function () {
          it("throws if eta less than block timestamp + delay", async function () {
            await expect(
              this.timelock.queueTransaction(
                this.timelock.address,
                value,
                signature,
                callData,
                timestamp + TIMELOCK_DELAY - 1
              )
            ).to.be.revertedWith("execution block must satisfy delay");
          });

          it("succesfully queues the transaction", async function () {
            const eta = timestamp + TIMELOCK_DELAY;
            await this.timelock.queueTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              eta
            );
            expect(await this.timelock.queuedTransactions(txHash)).to.equal(
              true
            );
          });

          it("emits a queue transaction event", async function () {
            const eta = timestamp + TIMELOCK_DELAY;
            const tx = await this.timelock.queueTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              eta
            );
            await expect(tx)
              .to.emit(this.timelock, EVENT_QUEUE_TRANSACTION)
              .withArgs(
                txHash,
                this.timelock.address,
                value,
                signature,
                callData,
                eta
              );
          });
        });
      });

      describe("cancelTransaction()", function () {
        beforeEach(async function () {
          await this.timelock.queueTransaction(
            this.timelock.address,
            value,
            signature,
            callData,
            timestamp + TIMELOCK_DELAY
          );
        });

        context("when not called by the admin", function () {
          it("throws", async function () {
            await expect(
              this.timelock
                .connect(this.admin)
                .cancelTransaction(
                  this.timelock.address,
                  value,
                  signature,
                  callData,
                  0
                )
            ).to.be.revertedWith("admin only");
          });
        });

        context("when called by the admin", function () {
          it("cancels a queued transaction", async function () {
            expect(await this.timelock.queuedTransactions(txHash)).to.equal(
              true
            );
            await this.timelock.cancelTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY
            );
            expect(await this.timelock.queuedTransactions(txHash)).to.equal(
              false
            );
          });

          it("emits a cancel transaction event", async function () {
            const tx = await this.timelock.cancelTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY
            );
            await expect(tx)
              .to.emit(this.timelock, EVENT_CANCEL_TRANSACTION)
              .withArgs(
                txHash,
                this.timelock.address,
                value,
                signature,
                callData,
                timestamp + TIMELOCK_DELAY
              );
          });
        });
      });

      describe("executeTransaction()", function () {
        const iface = new ethers.utils.Interface([
          "function setDelay(uint256 delay_)",
        ]);
        const callDataWithSig = iface.encodeFunctionData("setDelay", [
          TIMELOCK_MAX_DELAY,
        ]);
        const revertCallData = encodeParameters(
          ["uint256"],
          [TIMELOCK_MIN_DELAY - 1]
        );

        beforeEach(async function () {
          stopMining();
          await this.timelock.queueTransaction(
            this.timelock.address,
            value,
            "",
            callDataWithSig,
            timestamp + TIMELOCK_DELAY
          );
          await this.timelock.queueTransaction(
            this.timelock.address,
            value,
            signature,
            callData,
            timestamp + TIMELOCK_DELAY
          );
          await this.timelock.queueTransaction(
            this.timelock.address,
            value,
            signature,
            revertCallData,
            timestamp + TIMELOCK_DELAY
          );
          mineBlock();
          startMining();
        });

        context("when not called by the admin", function () {
          it("throws", async function () {
            await expect(
              this.timelock
                .connect(this.admin)
                .executeTransaction(
                  this.timelock.address,
                  value,
                  signature,
                  callData,
                  0
                )
            ).to.be.revertedWith("admin only");
          });
        });

        context("when called by the admin", function () {
          it("throws when transaction not queued", async function () {
            await expect(
              this.timelock.executeTransaction(
                this.timelock.address,
                value,
                signature,
                callData,
                0
              )
            ).to.be.revertedWith("not yet queued");
          });

          it("throws when current block timestamp not greater than eta", async function () {
            await expect(
              this.timelock.executeTransaction(
                this.timelock.address,
                value,
                signature,
                callData,
                timestamp + TIMELOCK_DELAY
              )
            ).to.be.revertedWith("not yet passed timelock");
          });

          it("throws when current block timestamp greater than eta + grace period", async function () {
            await setNextBlockTimestamp(
              timestamp + TIMELOCK_DELAY + TIMELOCK_GRACE_PERIOD + 1
            );
            await expect(
              this.timelock.executeTransaction(
                this.timelock.address,
                value,
                signature,
                callData,
                timestamp + TIMELOCK_DELAY
              )
            ).to.be.revertedWith("tx is stale");
          });

          it("throws when target call fails", async function () {
            await setNextBlockTimestamp(timestamp + TIMELOCK_DELAY);
            await expect(
              this.timelock.executeTransaction(
                this.timelock.address,
                value,
                signature,
                revertCallData,
                timestamp + TIMELOCK_DELAY
              )
            ).to.be.revertedWith("tx execution reverted");
          });

          it("cancels a queued transaction on success", async function () {
            expect(await this.timelock.queuedTransactions(txHash)).to.equal(
              true
            );
            await setNextBlockTimestamp(timestamp + TIMELOCK_DELAY);
            await this.timelock.executeTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY
            );
            expect(await this.timelock.queuedTransactions(txHash)).to.equal(
              false
            );
          });

          it("emits an execute transaction event", async function () {
            await setNextBlockTimestamp(timestamp + TIMELOCK_DELAY);
            const tx = await this.timelock.executeTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY
            );
            await expect(tx)
              .to.emit(this.timelock, EVENT_EXECUTE_TRANSACTION)
              .withArgs(
                txHash,
                this.timelock.address,
                value,
                signature,
                callData,
                timestamp + TIMELOCK_DELAY
              );
          });

          it("performs invocations as expected", async function () {
            expect(await this.timelock.delay()).to.equal(TIMELOCK_DELAY);
            await setNextBlockTimestamp(timestamp + TIMELOCK_DELAY);
            await this.timelock.executeTransaction(
              this.timelock.address,
              value,
              signature,
              callData,
              timestamp + TIMELOCK_DELAY
            );
            expect(await this.timelock.delay()).to.equal(TIMELOCK_MAX_DELAY);
          });

          it("executes properly when including sig in calldata", async function () {
            await setNextBlockTimestamp(timestamp + TIMELOCK_DELAY);
            expect(await this.timelock.delay()).to.equal(TIMELOCK_DELAY);
            await this.timelock.executeTransaction(
              this.timelock.address,
              value,
              "",
              callDataWithSig,
              timestamp + TIMELOCK_DELAY
            );
            expect(await this.timelock.delay()).to.equal(TIMELOCK_MAX_DELAY);
          });
        });
      });
    });
  });
});
