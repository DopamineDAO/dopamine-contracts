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

const EVENT_UPGRADE = "Upgraded";
const EVENT_ADMIN_CHANGED = "AdminChanged";

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
			proxyAdmin: this.proxyAdmin,
    } = await loadFixture(raritySocietyDAOProxyFixture));
		this.contract = this.daoImpl;
  });

  describe("initialization", function () {
    it("initializes all proxy administrative variables", async function () {
      expect(await this.proxyAdmin.getProxyImplementation(this.dao.address)).to.equal(daoImpl.address);
      expect(await this.proxyAdmin.getProxyAdmin(this.dao.address)).to.equal(this.proxyAdmin.address);
    });

    it("throws when admin setter is not proxy admin", async function () {
      await expect(this.dao.changeAdmin(constants.AddressZero)).to.be.reverted;
    });

    it("throws when admin being set is the zero address", async function () {
      await expect(this.proxyAdmin.changeProxyAdmin(this.dao.address, constants.AddressZero))
			.to.be.revertedWith("ERC1967: new admin is the zero address")
    });

    it("throws when implementation setter is not proxy admin", async function () {
      await expect(this.dao.upgradeTo(constants.AddressZero)).to.be.reverted;
    });

    it("throws when implementation being set is not a contract", async function () {
      await expect(
        this.proxyAdmin.upgrade(this.dao.address, constants.AddressZero)
      ).to.be.revertedWith("ERC1967: new implementation is not a contract");
    });

    it("can set new implementations", async function () {
      const daoImplFactory = new RaritySocietyDAOImpl__factory(this.deployer);
      const newImpl = await daoImplFactory.deploy();

      const tx = await this.proxyAdmin.upgrade(this.dao.address, newImpl.address);
      expect(await this.proxyAdmin.getProxyImplementation(this.dao.address)).to.equal(newImpl.address);
      expect(tx)
        .to.emit(this.dao, EVENT_UPGRADE)
        .withArgs(newImpl.address);
    });

		it("can set new proxy admins", async function () {
      const tx = await this.proxyAdmin.changeProxyAdmin(this.dao.address, this.deployer.address);

			expect(tx).to.emit(this.dao, EVENT_ADMIN_CHANGED).withArgs(this.proxyAdmin.address, this.deployer.address);
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
