import { utils, constants } from "ethers";
import { expect } from "chai";
import { Constants } from "../shared/constants";

export function testRaritySocietyDAOImplInitialize(): void {
  // Note MockRaritySocietyDAOImpl is used to trigger initialization without proxy delegation
  describe("RaritySocietyDAOImpl initialize functionality", function () {
    it("reverts when passing a zero address governance token", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          this.timelock.address,
          constants.AddressZero,
          this.vetoer.address,
          Constants.VOTING_PERIOD,
          Constants.VOTING_DELAY,
          Constants.PROPOSAL_THRESHOLD,
          Constants.QUORUM_VOTES_BPS
        )
      ).to.be.revertedWith("invalid governance token address");
    });

    it("reverts when passing a zero address timelock", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          constants.AddressZero,
          this.token.address,
          this.vetoer.address,
          Constants.VOTING_PERIOD,
          Constants.VOTING_DELAY,
          Constants.PROPOSAL_THRESHOLD,
          Constants.QUORUM_VOTES_BPS
        )
      ).to.be.revertedWith("invalid timelock address");
    });

    it("reverts when passing an invalid voting period", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          this.timelock.address,
          this.token.address,
          this.vetoer.address,
          Constants.MIN_VOTING_PERIOD - 1,
          Constants.VOTING_DELAY,
          Constants.PROPOSAL_THRESHOLD,
          Constants.QUORUM_VOTES_BPS
        )
      ).to.be.revertedWith("invalid voting period");
    });

    it("reverts when passing an invalid voting delay", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          this.timelock.address,
          this.token.address,
          this.vetoer.address,
          Constants.VOTING_PERIOD,
          Constants.MIN_VOTING_DELAY - 1,
          Constants.PROPOSAL_THRESHOLD,
          Constants.QUORUM_VOTES_BPS
        )
      ).to.be.revertedWith("invalid voting delay");
    });

    it("reverts when passing an invalid quorum threshold", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          this.timelock.address,
          this.token.address,
          this.vetoer.address,
          Constants.VOTING_PERIOD,
          Constants.VOTING_DELAY,
          Constants.PROPOSAL_THRESHOLD,
          0
        )
      ).to.be.revertedWith("invalid quorum votes threshold");
    });

    it("reverts when passing an invalid proposal threshold", async function () {
      await expect(
        this.daoImpl.initialize(
          this.admin.address,
          this.timelock.address,
          this.token.address,
          this.vetoer.address,
          Constants.VOTING_PERIOD,
          Constants.VOTING_DELAY,
          await this.token.totalSupply(),
          Constants.QUORUM_VOTES_BPS
        )
      ).to.be.revertedWith("invalid proposal threshold");
    });

    it("correctly initializes all storage variables", async function () {
      const daoImpl = await this.daoImpl.initialize(
        this.admin.address,
        this.timelock.address,
        this.token.address,
        this.vetoer.address,
        Constants.VOTING_PERIOD,
        Constants.VOTING_DELAY,
        Constants.PROPOSAL_THRESHOLD,
        Constants.QUORUM_VOTES_BPS
      );
      expect(await this.daoImpl.daoAdmin()).to.equal(this.admin.address);
      expect(await this.daoImpl.pendingAdmin()).to.equal(constants.AddressZero);
      expect(await this.daoImpl.vetoer()).to.equal(this.vetoer.address);
      expect(await this.daoImpl.votingPeriod()).to.equal(Constants.VOTING_PERIOD);
      expect(await this.daoImpl.votingDelay()).to.equal(Constants.VOTING_DELAY);
      expect(await this.daoImpl.proposalThreshold()).to.equal(
        Constants.PROPOSAL_THRESHOLD
      );
      expect(await this.daoImpl.quorumVotesBPS()).to.equal(
        Constants.QUORUM_VOTES_BPS
      );
      expect(await this.daoImpl.proposalCount()).to.equal(0);
      expect(await this.daoImpl.timelock()).to.equal(this.timelock.address);
      expect(await this.daoImpl.token()).to.equal(this.token.address);
    });

    it("correctly initializes all storage variables", async function () {
      await this.daoImpl.initialize(
        this.admin.address,
        this.timelock.address,
        this.token.address,
        this.vetoer.address,
        Constants.VOTING_PERIOD,
        Constants.VOTING_DELAY,
        Constants.PROPOSAL_THRESHOLD,
        Constants.QUORUM_VOTES_BPS
      );
      expect(await this.daoImpl.vetoer()).to.equal(this.vetoer.address);
      expect(await this.daoImpl.votingPeriod()).to.equal(Constants.VOTING_PERIOD);
      expect(await this.daoImpl.votingDelay()).to.equal(Constants.VOTING_DELAY);
      expect(await this.daoImpl.proposalThreshold()).to.equal(
        Constants.PROPOSAL_THRESHOLD
      );
      expect(await this.daoImpl.quorumVotesBPS()).to.equal(
        Constants.QUORUM_VOTES_BPS
      );
      expect(await this.daoImpl.proposalCount()).to.equal(0);
      expect(await this.daoImpl.timelock()).to.equal(this.timelock.address);
      expect(await this.daoImpl.token()).to.equal(this.token.address);
    });

    it("emits events for setting governance parameters", async function () {
      const tx = await this.daoImpl.initialize(
        this.admin.address,
        this.timelock.address,
        this.token.address,
        this.vetoer.address,
        Constants.VOTING_PERIOD,
        Constants.VOTING_DELAY,
        Constants.PROPOSAL_THRESHOLD,
        Constants.QUORUM_VOTES_BPS
      );
      await expect(tx)
        .to.emit(this.daoImpl, Constants.EVENT_VOTING_PERIOD_SET)
        .withArgs(0, Constants.VOTING_PERIOD);
      await expect(tx)
        .to.emit(this.daoImpl, Constants.EVENT_VOTING_DELAY_SET)
        .withArgs(0, Constants.VOTING_DELAY);
      await expect(tx)
        .to.emit(this.daoImpl, Constants.EVENT_PROPOSAL_THRESHOLD_SET)
        .withArgs(0, Constants.PROPOSAL_THRESHOLD);
      await expect(tx)
        .to.emit(this.daoImpl, Constants.EVENT_QUORUM_VOTES_BPS_SET)
        .withArgs(0, Constants.QUORUM_VOTES_BPS);
    });
  });
}
