import { expect } from "chai";
import { Constants } from "../shared/constants";
import { ethers } from "hardhat";
import {
  stopMining,
  startMining,
  setNextBlockTimestamp,
  encodeParameters,
  mineBlock,
  mintN,
  advanceBlocks,
} from "../shared/utils";

const TOTAL_SUPPLY = 20;
const STATES = {
  PENDING: 0,
  ACTIVE: 1,
  CANCELED: 2,
  DEFEATED: 3,
  SUCCEEDED: 4,
  QUEUED: 5,
  EXPIRED: 6,
  EXECUTED: 7,
  VETOED: 8,
};

export function testRaritySocietyDAOImplLifecycle(): void {
  let targets: string[];
  let values: string[];
  let signatures: string[];
  let calldatas: string[];

  describe("RaritySocietyDAOImpl lifecycle functionality", function () {
    beforeEach(async function () {
      await mintN(this.token, TOTAL_SUPPLY);
      for (let i = 0; i < 10; i++) {
        await this.token.transferFrom(
          this.deployer.address,
          this.voter.address,
          i
        );
      }
      targets = [this.timelock.address];
      values = ["0"];
      signatures = ["setDelay(uint256)"];
      calldatas = [
        encodeParameters(["uint256"], [Constants.TIMELOCK_DELAY + 1]),
      ];
      await stopMining();

      await this.daoImpl.propose(
        targets,
        values,
        signatures,
        calldatas,
        "test"
      );
      await mineBlock();
    });

    it("reverts when querying invalid proposals", async function () {
      await expect(this.daoImpl.state(10)).to.be.revertedWith(
        "Invalid proposal ID"
      );
    });

    describe("state: pending", function () {
      it("correctly sets proposal state to pending upon creation", async function () {
        expect(await this.daoImpl.state(1)).to.equal(STATES.PENDING);
        await advanceBlocks(Constants.VOTING_DELAY);
        expect(await this.daoImpl.state(1)).to.equal(STATES.PENDING);
      });

      it("does not allow queuing a pending proposal", async function () {
        await expect(this.daoImpl.queue(1)).to.be.revertedWith(
          "proposal queueable only if succeeded"
        );
      });
    });

    describe("state: active", function () {
      it("ensures proposals past the voting delay are active", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await mineBlock();
        await expect(await this.daoImpl.state(1)).to.equal(STATES.ACTIVE);
        await advanceBlocks(Constants.VOTING_PERIOD - 1);
        await expect(await this.daoImpl.state(1)).to.equal(STATES.ACTIVE);
      });
    });

    describe("state: succeeded", function () {
      it("ensures proposals passing quorum threshold are successful", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        expect(await this.daoImpl.state(1)).to.equal(STATES.SUCCEEDED);
      });
    });

    describe("state: queued", function () {
      it("enables successful proposals to be queued", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        const tx = await this.daoImpl.queue(1);
        await mineBlock();
        const eta =
          (await ethers.provider.getBlock("latest")).timestamp +
          Constants.TIMELOCK_DELAY;
        expect((await this.daoImpl.proposals(1)).eta).to.equal(eta);
        expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_QUEUED)
          .withArgs(1, eta);
      });

      it("reverts on queuing identical actions", async function () {
        await this.daoImpl
          .connect(this.voter)
          .propose(
            targets.concat(targets),
            values.concat(values),
            signatures.concat(signatures),
            calldatas.concat(calldatas),
            "test repeat"
          );
        await mineBlock();
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(2, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        await expect(this.daoImpl.queue(2)).to.be.revertedWith(
          "identical proposal already queued at eta"
        );
      });

      it("reverts on queueing identical proposals in the same block", async function () {
        await this.token.transferFrom(
          this.deployer.address,
          this.admin.address,
          TOTAL_SUPPLY - 1
        );
        await mineBlock();
        await this.daoImpl
          .connect(this.voter)
          .propose(targets, values, signatures, calldatas, "test");
        await this.daoImpl
          .connect(this.admin)
          .propose(targets, values, signatures, calldatas, "test");
        await mineBlock();
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(2, 1);
        await this.daoImpl.castVote(3, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        await expect(this.daoImpl.queue(2)).not.to.be.reverted;
        await expect(this.daoImpl.queue(3)).to.be.revertedWith(
          "identical proposal already queued at eta"
        );
        await mineBlock();
        await expect(this.daoImpl.queue(3)).not.to.be.reverted;
      });
    });

    describe("state: executed", function () {
      it("executes queued proposals", async function () {
        expect(await this.timelock.delay()).to.equal(Constants.TIMELOCK_DELAY);

        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        let tx = await this.daoImpl.queue(1);
        expect((await this.daoImpl.proposals(1)).executed).to.equal(false);
        await mineBlock();
        const ts = (await ethers.provider.getBlock("latest")).timestamp;
        await setNextBlockTimestamp(ts + Constants.TIMELOCK_DELAY);
        tx = await this.daoImpl.execute(1);
        await mineBlock();
        expect((await this.daoImpl.proposals(1)).executed).to.equal(true);
        expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_EXECUTED)
          .withArgs(1);

        expect(await this.timelock.delay()).to.equal(
          Constants.TIMELOCK_DELAY + 1
        );
      });
    });

    describe("state: canceled", function () {
      it("allows canceling unexecuted proposals", async function () {
        expect((await this.daoImpl.proposals(1)).canceled).to.equal(false);
        expect(await this.daoImpl.state(1)).to.equal(STATES.PENDING);
        await this.daoImpl.cancel(1);
        await mineBlock();
        expect((await this.daoImpl.proposals(1)).canceled).to.equal(true);
      });

      it("allows cancellation by anyone if proposer votes drops below threshold", async function () {
        let proposerVotes = await this.token.getCurrentVotes(
          this.deployer.address
        );
        const proposalThreshold = await this.daoImpl.proposalThreshold();
        await expect(
          this.daoImpl.connect(this.voter).cancel(1)
        ).to.be.revertedWith(
          "only proposer can cancel unless their votes drop below proposal threshold"
        );
        while (proposerVotes >= proposalThreshold) {
          await this.token.burn(TOTAL_SUPPLY - proposerVotes--);
        }
        await mineBlock();
        await this.daoImpl.connect(this.voter).cancel(1);
        await mineBlock();
        expect((await this.daoImpl.proposals(1)).canceled).to.equal(true);
      });

      it("emits a ProposalCanceled event", async function () {
        const tx = await this.daoImpl.cancel(1);
        expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_CANCELED)
          .withArgs(1);
      });

      it("does not allow canceling an executed proposal", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        await this.daoImpl.queue(1);
        await mineBlock();
        const ts = (await ethers.provider.getBlock("latest")).timestamp;
        await setNextBlockTimestamp(ts + Constants.TIMELOCK_DELAY);
        await this.daoImpl.execute(1);
        await expect(this.daoImpl.cancel(1)).to.be.revertedWith(
          "proposal already executed"
        );
      });
    });

    describe("state: defeated", function () {
      it("ensures proposals with an equal or greater amount of against votes are defeated", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 0);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        expect(await this.daoImpl.state(1)).to.equal(STATES.DEFEATED);
      });

      it("ensures proposals whose for votes do not pass quorum are defeated", async function () {
        await this.token.transferFrom(
          this.deployer.address,
          this.admin.address,
          TOTAL_SUPPLY - 1
        );
        await this.daoImpl
          .connect(this.voter)
          .propose(targets, values, signatures, calldatas, "test2");
        await mineBlock();
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.connect(this.admin).castVote(2, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        expect(await this.daoImpl.state(2)).to.equal(STATES.DEFEATED);
      });
    });

    describe("state: expired", function () {
      it("reverts execution of expired proposals", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        await this.daoImpl.queue(1);
        await mineBlock();
        const ts = (await ethers.provider.getBlock("latest")).timestamp;
        await setNextBlockTimestamp(
          ts + Constants.TIMELOCK_DELAY + Constants.TIMELOCK_GRACE_PERIOD
        );
        await mineBlock();
        await expect(await this.daoImpl.state(1)).to.be.equal(STATES.EXPIRED);
        await expect(this.daoImpl.execute(1)).to.be.revertedWith(
          "proposal can only be executed if queued"
        );
      });
    });

    describe("state: vetoed", function () {
      it("allows vetoing proposals", async function () {
        expect((await this.daoImpl.proposals(1)).vetoed).to.equal(false);
        expect(await this.daoImpl.state(1)).to.equal(STATES.PENDING);
        await this.daoImpl.connect(this.vetoer).veto(1);
        await mineBlock();
        expect((await this.daoImpl.proposals(1)).vetoed).to.equal(true);
      });

      it("throws when trying to veto an executed proposal", async function () {
        await advanceBlocks(Constants.VOTING_DELAY);
        await this.daoImpl.castVote(1, 1);
        await advanceBlocks(Constants.VOTING_PERIOD);
        await mineBlock();
        await this.daoImpl.queue(1);
        await mineBlock();
        const ts = (await ethers.provider.getBlock("latest")).timestamp;
        await setNextBlockTimestamp(ts + Constants.TIMELOCK_DELAY);
        await this.daoImpl.execute(1);
        await expect(
          this.daoImpl.connect(this.vetoer).veto(1)
        ).to.be.revertedWith("cannot veto executed proposal");
      });

      it("emits a ProposalVetoed event", async function () {
        const tx = await this.daoImpl.connect(this.vetoer).veto(1);
        expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_VETOED)
          .withArgs(1);
      });
    });

    afterEach(async function () {
      await startMining();
    });
  });
}
