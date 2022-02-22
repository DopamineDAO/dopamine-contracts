import { constants } from "ethers";
import { expect } from "chai";
import { Constants } from "../shared/constants";
import { supportsInterfaces, mintN } from "../shared/utils";

export function testRaritySocietyDAOImplSettings(): void {
  describe("RaritySocietyDAOImpl settings functionality", function () {

    describe("supports governance interfaces", function () {
      supportsInterfaces(["ERC165"]);
    });

    describe("initialize", function () {
      it("can only be initialized once", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .initialize(
							this.admin.address,
              this.timelock.address,
              this.token.address,
              this.vetoer.address,
              Constants.VOTING_PERIOD,
              Constants.VOTING_DELAY,
              Constants.PROPOSAL_THRESHOLD,
              Constants.QUORUM_VOTES_BPS
            )
        ).to.be.revertedWith("Initializable: contract is already initialized");
      });
    });

    describe("voting delay", function () {
      it("throws when not called by the admin", async function () {
        await expect(
          this.daoImpl.setVotingDelay(Constants.VOTING_DELAY + 1)
        ).to.be.revertedWith("admin only");
      });

      it("throws when setting a delay lower than the minimum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setVotingDelay(Constants.MIN_VOTING_DELAY - 1)
        ).to.be.revertedWith("invalid voting delay");
      });

      it("throws when setting a delay greater than the maximum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setVotingDelay(Constants.MAX_VOTING_DELAY + 1)
        ).to.be.revertedWith("invalid voting delay");
      });

      it("appropriately sets the new voting delay", async function () {
        await this.daoImpl
          .connect(this.admin)
          .setVotingDelay(Constants.VOTING_DELAY + 1);
        expect(await this.daoImpl.votingDelay()).to.equal(
          Constants.VOTING_DELAY + 1
        );
      });

      it("emits a VotingDelaySet event", async function () {
        const tx = await this.daoImpl
          .connect(this.admin)
          .setVotingDelay(Constants.VOTING_DELAY + 1);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_VOTING_DELAY_SET)
          .withArgs(Constants.VOTING_DELAY, Constants.VOTING_DELAY + 1);
      });
    });

    describe("quorum votes settings", function () {
      it("throws when not called by the admin", async function () {
        await expect(
          this.daoImpl.setQuorumVotesBPS(Constants.QUORUM_VOTES_BPS + 1)
        ).to.be.revertedWith("admin only");
      });

      it("throws when setting quorum votes lower than the minimum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setQuorumVotesBPS(Constants.MIN_QUORUM_VOTES_BPS - 1)
        ).to.be.revertedWith("invalid quorum votes threshold set");
      });

      it("throws when setting quorum votes greater than the max threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setQuorumVotesBPS(Constants.MAX_QUORUM_VOTES_BPS + 1)
        ).to.be.revertedWith("invalid quorum votes threshold set");
      });

      it("appropriately sets the new quorum votes thresold", async function () {
        await this.daoImpl
          .connect(this.admin)
          .setQuorumVotesBPS(Constants.QUORUM_VOTES_BPS + 1);
        expect(await this.daoImpl.quorumVotesBPS()).to.equal(
          Constants.QUORUM_VOTES_BPS + 1
        );
      });

      it("emits a QuorumVotesBPSSet event", async function () {
        const tx = await this.daoImpl
          .connect(this.admin)
          .setQuorumVotesBPS(Constants.QUORUM_VOTES_BPS + 1);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_QUORUM_VOTES_BPS_SET)
          .withArgs(Constants.QUORUM_VOTES_BPS, Constants.QUORUM_VOTES_BPS + 1);
      });
    });

    describe("Voting Period", function () {
      it("throws when not called by the admin", async function () {
        await expect(
          this.daoImpl.setVotingPeriod(Constants.VOTING_PERIOD + 1)
        ).to.be.revertedWith("admin only");
      });

      it("throws when setting a period lower than the minimum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setVotingPeriod(Constants.MIN_VOTING_PERIOD - 1)
        ).to.be.revertedWith("invalid voting period");
      });

      it("throws when setting a period greater than the maximum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setVotingPeriod(Constants.MAX_VOTING_PERIOD + 1)
        ).to.be.revertedWith("invalid voting period");
      });

      it("appropriately sets the new voting period", async function () {
        await this.daoImpl
          .connect(this.admin)
          .setVotingPeriod(Constants.VOTING_PERIOD + 1);
        expect(await this.daoImpl.votingPeriod()).to.equal(
          Constants.VOTING_PERIOD + 1
        );
      });

      it("emits a VotingPeriodSet event", async function () {
        const tx = await this.daoImpl
          .connect(this.admin)
          .setVotingPeriod(Constants.VOTING_PERIOD + 1);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_VOTING_PERIOD_SET)
          .withArgs(Constants.VOTING_PERIOD, Constants.VOTING_PERIOD + 1);
      });
    });

    describe("Proposal Threshold", function () {
      it("throws when not called by the admin", async function () {
        await expect(
          this.daoImpl.setProposalThreshold(Constants.PROPOSAL_THRESHOLD)
        ).to.be.revertedWith("admin only");
      });

      it("throws when setting a proposal threshold lower than the minimum threshold", async function () {
        await expect(
          this.daoImpl
            .connect(this.admin)
            .setProposalThreshold(Constants.MIN_PROPOSAL_THRESHOLD - 1)
        ).to.be.revertedWith("invalid proposal threshold");
      });

      context(
        "when ensuring the set proposal threshold is lower than the supply-based max threshold",
        function () {
          it("reverts when setting proposal thresholds above 1 when supply is 0", async function () {
            await expect(
              this.daoImpl
                .connect(this.admin)
                .setProposalThreshold(Constants.MIN_PROPOSAL_THRESHOLD + 1)
            ).to.be.revertedWith("invalid proposal threshold");
          });

          it("reverts when setting proposal thresholds above the supply-based maximum threshold", async function () {
            await mintN(this.token, 19);
            const maxThreshold = Math.floor(
              (19 * Constants.MAX_PROPOSAL_THRESHOLD_BPS) / 10000
            );
            await expect(
              this.daoImpl
                .connect(this.admin)
                .setProposalThreshold(maxThreshold + 1)
            ).to.be.revertedWith("invalid proposal threshold");
          });

          it("reverts or approves proposal threshold settings based on token supply", async function () {
            await mintN(this.token, 19);
            const maxThreshold = Math.floor(
              (19 * Constants.MAX_PROPOSAL_THRESHOLD_BPS) / 10000
            );
            await expect(
              this.daoImpl
                .connect(this.admin)
                .setProposalThreshold(maxThreshold + 1)
            ).to.be.revertedWith("invalid proposal threshold");
            await this.token.mint();
            await expect(
              this.daoImpl
                .connect(this.admin)
                .setProposalThreshold(maxThreshold + 1)
            ).not.to.be.reverted;
            expect(await this.daoImpl.proposalThreshold()).to.equal(
              maxThreshold + 1
            );
          });
        }
      );

      it("emits a ProposalThresholdSet event", async function () {
        await mintN(this.token, 20);
        const tx = await this.daoImpl
          .connect(this.admin)
          .setProposalThreshold(Constants.PROPOSAL_THRESHOLD + 1);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_THRESHOLD_SET)
          .withArgs(
            Constants.PROPOSAL_THRESHOLD,
            Constants.PROPOSAL_THRESHOLD + 1
          );
      });
    });

    describe("Setting pending admin", function () {
      it("throws when not called by the admin", async function () {
        await expect(
          this.daoImpl.setPendingAdmin(this.deployer.address)
        ).to.be.revertedWith("admin only");
      });

      it("appropriately sets the new pending admin", async function () {
        await this.daoImpl
          .connect(this.admin)
          .setPendingAdmin(this.deployer.address);
        expect(await this.daoImpl.pendingAdmin()).to.equal(
          this.deployer.address
        );
      });

      it("emits a NewPendingAdmin event", async function () {
        const tx = await this.daoImpl
          .connect(this.admin)
          .setPendingAdmin(this.deployer.address);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_NEW_PENDING_ADMIN)
          .withArgs(constants.AddressZero, this.deployer.address);
      });
    });

    describe("Setting admin", function () {
      it("throws when the pending admin has yet to be set", async function () {
        await expect(
          this.daoImpl.acceptAdmin()
        ).to.be.revertedWith("pending admin only");
      });

      it("throws when not accepted by the pending admin", async function () {
				await this.daoImpl.connect(this.admin).setPendingAdmin(this.admin.address);
        await expect(
          this.daoImpl.acceptAdmin()
        ).to.be.revertedWith("pending admin only");
      });

			it("appropriately sets the admin and unsets the pending admin", async function () {
				await this.daoImpl.connect(this.admin).setPendingAdmin(this.deployer.address);
				await this.daoImpl.acceptAdmin();
				expect(await this.daoImpl.pendingAdmin()).to.equal(
					constants.AddressZero
				);
				expect(await this.daoImpl.daoAdmin()).to.equal(
					this.deployer.address
				);
			});

			it("emits NewPendingAdmin and NewAdmin events", async function () {
				await this.daoImpl.connect(this.admin).setPendingAdmin(this.deployer.address);
				const tx = await this.daoImpl.acceptAdmin();
				await expect(tx)
					.to.emit(this.daoImpl, Constants.EVENT_NEW_ADMIN)
					.withArgs(this.admin.address, this.deployer.address);
				await expect(tx)
					.to.emit(this.daoImpl, Constants.EVENT_NEW_PENDING_ADMIN)
					.withArgs(this.deployer.address, constants.AddressZero);
			});

    });

    describe("vetoer settings", function () {
      it("throws unless invoked by the vetoer", async function () {
        await expect(
          this.daoImpl.connect(this.admin).setVetoer(this.deployer.address)
        ).to.be.revertedWith("vetoer only");
      });

      it("appropriately sets the new vetoer", async function () {
        await this.daoImpl
          .connect(this.vetoer)
          .setVetoer(this.deployer.address);
        expect(await this.daoImpl.vetoer()).to.equal(this.deployer.address);
      });

      it("emits a NewVetoer event", async function () {
        const tx = await this.daoImpl
          .connect(this.vetoer)
          .setVetoer(this.deployer.address);
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_NEW_VETOER)
          .withArgs(this.vetoer.address, this.deployer.address);
      });

      it("reverts when an address besides the vetoer tries revoking power", async function () {
        await expect(
          this.daoImpl.connect(this.admin).revokeVetoPower()
        ).to.be.revertedWith("vetoer only");
      });

      it("successfully revokes veto power when revoked by vetoer", async function () {
        const tx = await this.daoImpl.connect(this.vetoer).revokeVetoPower();
        await expect(tx)
          .to.emit(this.daoImpl, Constants.EVENT_NEW_VETOER)
          .withArgs(this.vetoer.address, constants.AddressZero);
        expect(await this.daoImpl.vetoer()).to.equal(constants.AddressZero);
        await expect(
          this.daoImpl.connect(this.vetoer).setVetoer(this.deployer.address)
        ).to.be.revertedWith("vetoer only");
      });
    });
  });
}
