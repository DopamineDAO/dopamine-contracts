import { utils, BigNumber, constants, Event } from "ethers";
import { expect } from "chai";
import { Constants } from "../shared/constants";
import { waffle, ethers } from "hardhat";
import { RaritySocietyDAOImpl } from "../../typechain";
import { stopMining, startMining, setNextBlockTimestamp, impersonate, stopImpersonating, encodeParameters, mineBlock, mintN, advanceBlocks } from "../shared/utils";

const TOTAL_SUPPLY = 29;

export function testRaritySocietyDAOImplPropose(): void {

	describe("RaritySocietyDAOImpl propose functionality", function () {

		let targets: string[];
		let values: string[];
		let signatures: string[];
		let calldatas: string[];

		beforeEach(async function () {
			targets = [this.token.address];
			values = ["0"];
			signatures = ["balanceOf(address)"];
			calldatas = [encodeParameters(['address'], [this.deployer.address])];
		});

		describe('basic proposal functionality', function () {

			beforeEach(async function () {
				await mintN(this.token, TOTAL_SUPPLY);
			});
			it('reverts when proposer voting power below proposal threshold', async function () {
				await expect(
					this.daoImpl.connect(this.voter).propose(targets, values, signatures, calldatas, "")
				).to.be.revertedWith("proposer votes below proposal threshold");
				const maxProposalThreshold = (await this.daoImpl.maxProposalThreshold()).toNumber();
				expect(maxProposalThreshold).to.equal(Math.floor(TOTAL_SUPPLY * Constants.MAX_PROPOSAL_THRESHOLD_BPS / 10000));
				await this.daoImpl.connect(this.admin).setProposalThreshold(maxProposalThreshold);
				for (let i=0; i < maxProposalThreshold - 1; i++) {
					await this.token.transferFrom(this.deployer.address, this.voter.address, i);
				}
				await expect(
					this.daoImpl.connect(this.voter).propose(targets, values, signatures, calldatas, "")
				).to.be.revertedWith("proposer votes below proposal threshold");
				await this.token.transferFrom(this.deployer.address, this.voter.address, maxProposalThreshold - 1);
				await expect(
					this.daoImpl.connect(this.voter).propose(targets, values, signatures, calldatas, "")
				).not.to.be.reverted;
			});

			it('reverts when there is an arity mismatch between targets, values, signatures, or calldatas', async function () {
				await expect(
					this.daoImpl.propose(targets.concat(targets), values, signatures, calldatas, "")
				).to.be.revertedWith("proposal function arity mismatch");
				await expect(
					this.daoImpl.propose(targets, values.concat(values), signatures, calldatas, "")
				).to.be.revertedWith("proposal function arity mismatch");
				await expect(
					this.daoImpl.propose(targets, values, signatures.concat(signatures), calldatas, "")
				).to.be.revertedWith("proposal function arity mismatch");
				await expect(
					this.daoImpl.propose(targets, values, signatures, calldatas.concat(calldatas), "")
				).to.be.revertedWith("proposal function arity mismatch");
			});

			it('reverts when no actions are provided', async function () {
				await expect(
					this.daoImpl.propose([], [], [], [], "")
				).to.be.revertedWith('actions not provided');
			});

			it('reverts when too many actions are provided', async function () {
				let actions: string[] = new Array(Constants.PROPOSAL_MAX_OPERATIONS + 1).fill(this.token.address);
				await expect(
					this.daoImpl.propose(actions, actions, actions, actions, "")
				).to.be.revertedWith('too many actions');
			});

			it('generates a proposal with the expected attributes', async function () {
				const tx = await this.daoImpl.propose(targets, values, signatures, calldatas, "test");
				const rx = await tx.wait();
				const startBlock = rx.blockNumber + Constants.VOTING_DELAY;
				const endBlock = startBlock + Constants.VOTING_PERIOD;
				const quorumVotes = Math.max(1, Math.floor(TOTAL_SUPPLY * Constants.QUORUM_VOTES_BPS / 10000))
				await expect(tx).to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_CREATED).withArgs(
					1,
					this.deployer.address,
					targets,
					values,
					signatures,
					calldatas,
					startBlock,
					endBlock,
					quorumVotes,
					"test"
				);
				const proposal = await this.daoImpl.proposals(1);
				expect(proposal.id).to.equal(1);
				expect(proposal.proposer).to.equal(this.deployer.address);
				expect(proposal.quorumVotes).to.equal(quorumVotes);
				expect(proposal.eta).to.equal(0);
				expect(proposal.forVotes).to.equal(0);
				expect(proposal.againstVotes).to.equal(0);
				expect(proposal.canceled).to.equal(false);
				expect(proposal.executed).to.equal(false);
				expect(proposal.vetoed).to.equal(false);
				expect(await this.daoImpl.latestProposalIds(proposal.proposer)).to.equal(1);
				const actions = await this.daoImpl.getActions(1);
				expect(actions.targets).to.deep.equal(targets);
				// expect(actions[1].map(i => i.toString())).to.deep.equal(values);
				expect(actions.signatures).to.deep.equal(signatures);
				expect(actions.calldatas).to.deep.equal(calldatas);
			});
		});

		describe('when submitting multiple proposals', function () {
			it('allows for two different addresses to make proposals concurrently', async function () {
				await mintN(this.token, 2);
				await this.token.transferFrom(this.deployer.address, this.voter.address, 1);
				await this.daoImpl.propose(targets, values, signatures, calldatas, "test");
				await expect(
					this.daoImpl.connect(this.voter).propose(targets, values, signatures, calldatas, "test")
				).not.to.be.reverted;
			});

			it('reverts when an address proposes while having a pending / active proposal', async function () {
				await this.token.mint();
				await stopMining();

				await this.daoImpl.propose(targets, values, signatures, calldatas, "test");
				await mineBlock();

				await advanceBlocks(Constants.VOTING_DELAY - 1);
				await expect(
					this.daoImpl.propose(targets, values, signatures, calldatas, "")
				).to.be.revertedWith("One proposal per proposer - pending proposal already found");
				await mineBlock();

				await advanceBlocks(Constants.VOTING_PERIOD - 1);
				await expect(
					this.daoImpl.propose(targets, values, signatures, calldatas, "")
				).to.be.revertedWith("One proposal per proposer - active proposal already found");
				await mineBlock();

				await startMining();
				await expect(
					this.daoImpl.propose(targets, values, signatures, calldatas, "")
				).not.to.be.reverted;
			});
		});

		describe('when proposing across different token supply levels', function () {
			it('does not allow proposals to be made when token supply is 0', async function () {
				expect(await this.token.totalSupply()).to.equal(0);
				await expect(
					this.daoImpl.propose(targets, values, signatures, calldatas.concat(calldatas), "")
				).to.be.revertedWith("proposer votes below proposal threshold");
			});

			it('changes proposal quorum votes based on supply', async function () {
				await mintN(this.token, 13);
				await this.token.transferFrom(this.deployer.address, this.voter.address, 1);
				await this.daoImpl.connect(this.voter).propose(targets, values, signatures, calldatas, "")
				expect((await this.daoImpl.proposals(1)).quorumVotes).to.equal(1);
				await this.token.transferFrom(this.deployer.address, this.admin.address, 2);
				await this.token.mint();
				expect(await this.token.totalSupply()).to.equal(14);
				await this.daoImpl.connect(this.admin).propose(targets, values, signatures, calldatas, "")
				expect((await this.daoImpl.proposals(2)).quorumVotes).to.equal(2);
			});

		});

	});
}
