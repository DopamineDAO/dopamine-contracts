import { utils, constants } from "ethers";
import { expect } from "chai";
import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import {
  RaritySocietyDAOImpl__factory,
  RaritySocietyDAOImpl,
} from "../typechain";
import { raritySocietyDAOProxyFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { testRaritySocietyDAOImplPropose } from "./raritySocietyDAOImpl/propose.behavior";
import { testRaritySocietyDAOImplSettings } from "./raritySocietyDAOImpl/settings.behavior";
import { testRaritySocietyDAOImplCastVote } from "./raritySocietyDAOImpl/castVote.behavior";
import { testRaritySocietyDAOImplLifecycle } from "./raritySocietyDAOImpl/lifecycle.behavior";

const EVENT_NEW_IMPL = "NewImpl";

const { createFixtureLoader } = waffle;

describe("RaritySocietyDAOProxy", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];
  let daoImpl: RaritySocietyDAOImpl;

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.admin, this.vetoer, this.voter, this.delegator] =
      signers;

    loadFixture = createFixtureLoader([
      this.deployer,
      this.admin,
      this.vetoer,
    ] as Signer[] as Wallet[]);
  });

  beforeEach("instantiate fixtures for RaritySocietyDAO", async function () {
    ({
      token: this.token,
      timelock: this.timelock,
      dao: this.dao,
      daoProxyImpl: this.daoImpl,
      daoImpl: daoImpl,
    } = await loadFixture(raritySocietyDAOProxyFixture));
		this.contract = this.daoImpl;
  });

  describe("initialization", function () {
    it("initializes all RaritySocietyDAOProxyStorage variables", async function () {
      expect(await this.dao.impl()).to.equal(daoImpl.address);
      expect(await this.dao.admin()).to.equal(this.admin.address);
      expect(await this.dao.pendingAdmin()).to.equal(constants.AddressZero);
    });

    it("throws when implementation setter is not admin", async function () {
      await expect(this.dao.setImpl(constants.AddressZero)).to.be.revertedWith(
        "setImpl may only be called by admin"
      );
    });

    it("throws when implementation being set is not a contract", async function () {
      await expect(
        this.dao.connect(this.admin).setImpl(constants.AddressZero)
      ).to.be.revertedWith("implementation is not a contract");
    });

    it("can set new implementations", async function () {
      const daoImplFactory = new RaritySocietyDAOImpl__factory(this.deployer);
      const newImpl = await daoImplFactory.deploy();
      expect(newImpl.address).not.to.equal(await this.dao.impl());
      const tx = await this.dao.connect(this.admin).setImpl(newImpl.address);
      expect(await this.dao.impl()).to.equal(newImpl.address);
      expect(tx)
        .to.emit(this.dao, EVENT_NEW_IMPL)
        .withArgs(daoImpl.address, newImpl.address);
    });

    it("throws when receiving ether", async function () {
      expect(await ethers.provider.getBalance(this.dao.address)).to.equal(0);
      await expect(
        this.deployer.sendTransaction({
          to: this.dao.address,
          value: utils.parseEther("1.0"),
        })
      ).to.be.reverted;
    });
  });

  testRaritySocietyDAOImplSettings();
  testRaritySocietyDAOImplPropose();
  testRaritySocietyDAOImplCastVote();
  testRaritySocietyDAOImplLifecycle();
});
