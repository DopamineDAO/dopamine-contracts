import { BigNumber } from "ethers";
import { expect } from "chai";
import { Constants } from "../shared/constants";
import { ethers } from "hardhat";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  stopMining,
  startMining,
  encodeParameters,
  mineBlock,
  mintN,
  advanceBlocks,
  getChainId,
} from "../shared/utils";

type VoteFn = (
  voter: SignerWithAddress,
  proposalId: number,
  support: number
) => Promise<TransactionResponse>;

const SIGNING_DOMAIN_VERSION = "1";

const TYPES = {
  Ballot: [
    { name: "proposalId", type: "uint256" },
    { name: "support", type: "uint8" },
  ],
};

const TOTAL_SUPPLY = 20;
const VOTE_REASON = "web3 is the future";

export function testRaritySocietyDAOImplCastVote(): void {
  let chainId: BigNumber;
  let verifyingContract: string;
  let domainName: string;

  let targets: string[];
  let values: string[];
  let signatures: string[];
  let calldatas: string[];

  const castVote = async function (
    this: Mocha.Context,
    voter: SignerWithAddress,
    proposalId: number,
    support: number
  ) {
    return await this.daoImpl.connect(voter).castVote(proposalId, support);
  };

  const castVoteWithReason = async function (
    this: Mocha.Context,
    voter: SignerWithAddress,
    proposalId: number,
    support: number
  ) {
    return await this.daoImpl
      .connect(voter)
      .castVoteWithReason(proposalId, support, VOTE_REASON);
  };

  const castVoteBySig = async function (
    this: Mocha.Context,
    voter: SignerWithAddress,
    proposalId: number,
    support: number
  ) {
    const sig = await voter._signTypedData(
      {
        name: domainName,
        chainId: chainId,
        verifyingContract: verifyingContract,
        version: SIGNING_DOMAIN_VERSION,
      },
      TYPES,
      { proposalId: proposalId, support: support }
    );
    const { v, r, s } = ethers.utils.splitSignature(sig);
    return await this.daoImpl
      .connect(voter)
      .castVoteBySig(proposalId, support, v, r, s);
  };

  describe("RaritySocietyDAOImpl cast vote functionality", function () {
    beforeEach(async function () {
      chainId = BigNumber.from(await getChainId());
      domainName = await this.daoImpl.name();
      verifyingContract = this.daoImpl.address;
      targets = [this.token.address];
      values = ["0"];
      signatures = ["balanceOf(address)"];
      calldatas = [encodeParameters(["address"], [this.deployer.address])];
    });

    const expectedVotingBehavior = function (voteFunc: VoteFn, reason: string) {
      context("when votes are expected to be invalid", function () {
        beforeEach(async function () {
          await mintN(this.token, TOTAL_SUPPLY);
          await this.daoImpl.propose(
            targets,
            values,
            signatures,
            calldatas,
            ""
          );
        });

        it("throws when voting for a nonexistent proposal", async function () {
          await expect(
            voteFunc.bind(this)(this.deployer, 2, 0)
          ).to.be.revertedWith("Invalid proposal ID");
        });
        it("throws when attempting to vote while the proposal is not active", async function () {
          await stopMining();

          await advanceBlocks(Constants.VOTING_DELAY - 1);
          await expect(
            voteFunc.bind(this)(this.deployer, 1, 0)
          ).to.be.revertedWith("voting is closed");
          await mineBlock();

          await advanceBlocks(Constants.VOTING_PERIOD - 1);
          await expect(
            voteFunc.bind(this)(this.deployer, 1, 0)
          ).not.to.be.reverted;
          await mineBlock();

          await startMining();
          await expect(
            voteFunc.bind(this)(this.deployer, 1, 0)
          ).to.be.revertedWith("voting is closed");
        });

        it("throws when voting with an invalid vote type", async function () {
          await advanceBlocks(Constants.VOTING_DELAY);
          await expect(
            voteFunc.bind(this)(this.deployer, 1, 3)
          ).to.be.revertedWith("invalid vote type");
        });

        it("throws when voting multiple times for a proposal", async function () {
          await advanceBlocks(Constants.VOTING_DELAY);
          voteFunc.bind(this)(this.deployer, 1, 2);
          await expect(
            voteFunc.bind(this)(this.deployer, 1, 1)
          ).to.be.revertedWith("voter already voted");
        });
      });

      context("when votes are expected to be valid", function () {
        let expectedVotingPowerDeployer: number;
        let expectedVotingPowerVoter: number;

        beforeEach(async function () {
          await mintN(this.token, TOTAL_SUPPLY);
          await stopMining();
          await this.token.transferFrom(
            this.deployer.address,
            this.voter.address,
            0
          );
          await this.token.transferFrom(
            this.deployer.address,
            this.voter.address,
            1
          );
          await this.daoImpl.propose(
            targets,
            values,
            signatures,
            calldatas,
            ""
          );
          await mineBlock();

          expectedVotingPowerDeployer = await this.token.balanceOf(
            this.deployer.address
          );
          expectedVotingPowerVoter = await this.token.balanceOf(
            this.voter.address
          );

          await this.token.transferFrom(
            this.deployer.address,
            this.voter.address,
            2
          );
          await this.token
            .connect(this.voter)
            .transferFrom(this.voter.address, this.deployer.address, 0);
          await advanceBlocks(Constants.VOTING_DELAY);
          await startMining();
        });

        it("appropriately adjusts the proposals voting weights", async function () {
          let deployerReceipt = await this.daoImpl.getReceipt(
            1,
            this.deployer.address
          );
          let voterReceipt = await this.daoImpl.getReceipt(
            1,
            this.voter.address
          );
          let adminReceipt = await this.daoImpl.getReceipt(
            1,
            this.admin.address
          );

          expect(deployerReceipt.hasVoted).to.equal(false);
          expect(voterReceipt.hasVoted).to.equal(false);
          expect(adminReceipt.hasVoted).to.equal(false);

          let p = await this.daoImpl.proposals(1);
          expect(p.againstVotes).to.equal(0);
          expect(p.forVotes).to.equal(0);
          expect(p.abstainVotes).to.equal(0);

          await voteFunc.bind(this)(this.deployer, 1, 2);
          await voteFunc.bind(this)(this.voter, 1, 1);
          await voteFunc.bind(this)(this.admin, 1, 0);

          p = await this.daoImpl.proposals(1);

          deployerReceipt = await this.daoImpl.getReceipt(
            1,
            this.deployer.address
          );
          voterReceipt = await this.daoImpl.getReceipt(1, this.voter.address);
          adminReceipt = await this.daoImpl.getReceipt(1, this.admin.address);
          expect(deployerReceipt.hasVoted).to.equal(true);
          expect(deployerReceipt.support).to.equal(2);
          expect(deployerReceipt.votes).to.equal(expectedVotingPowerDeployer);

          expect(voterReceipt.hasVoted).to.equal(true);
          expect(voterReceipt.support).to.equal(1);
          expect(voterReceipt.votes).to.equal(expectedVotingPowerVoter);

          expect(adminReceipt.hasVoted).to.equal(true);
          expect(adminReceipt.support).to.equal(0);
          expect(adminReceipt.votes).to.equal(0);

          expect(p.againstVotes).to.equal(0);
          expect(p.forVotes).to.equal(expectedVotingPowerVoter);
          expect(p.abstainVotes).to.equal(expectedVotingPowerDeployer);
        });

        it("tallies based on voting power at block of proposal creation", async function () {
          await voteFunc.bind(this)(this.deployer, 1, 2);
          await voteFunc.bind(this)(this.voter, 1, 1);
          const deployerReceipt = await this.daoImpl.getReceipt(
            1,
            this.deployer.address
          );
          const voterReceipt = await this.daoImpl.getReceipt(
            1,
            this.voter.address
          );
          expect(deployerReceipt.votes).to.equal(expectedVotingPowerDeployer);
          expect(voterReceipt.votes).to.equal(expectedVotingPowerVoter);
        });

        it("emits a VoteCast event with an empty reason string", async function () {
          const tx = voteFunc.bind(this)(this.deployer, 1, 2);
          await expect(tx)
            .to.emit(this.daoImpl, Constants.EVENT_VOTE_CAST)
            .withArgs(
              this.deployer.address,
              1,
              2,
              expectedVotingPowerDeployer,
              reason
            );
        });
      });
    };

    describe("castVote()", function () {
      expectedVotingBehavior(castVote, "");
    });

    describe("castVoteWithReason()", function () {
      expectedVotingBehavior(castVoteWithReason, VOTE_REASON);
    });

    describe("castVoteBySig()", function () {
      expectedVotingBehavior(castVoteBySig, "");
    });
  });
}
