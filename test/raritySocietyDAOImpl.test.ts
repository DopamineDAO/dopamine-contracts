import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import { raritySocietyDAOImplFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { testRaritySocietyDAOImplInitialize } from "./raritySocietyDAOImpl/initialize.behavior";
import { testRaritySocietyDAOImplPropose } from "./raritySocietyDAOImpl/propose.behavior";
import { testRaritySocietyDAOImplSettings } from "./raritySocietyDAOImpl/settings.behavior";
import { testRaritySocietyDAOImplCastVote } from "./raritySocietyDAOImpl/castVote.behavior";
import { testRaritySocietyDAOImplLifecycle } from "./raritySocietyDAOImpl/lifecycle.behavior";

const { createFixtureLoader } = waffle;

describe("RaritySocietyDAO", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

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

  beforeEach(
    "instantiate fixtures for RaritySocietyDAOImpl",
    async function () {
      ({
        token: this.token,
        timelock: this.timelock,
        daoImplFactory: this.daoImplFactory,
        daoImpl: this.daoImpl,
      } = await loadFixture(raritySocietyDAOImplFixture));
			this.contract = this.daoImpl;
			await this.token.createDrop("", 99);
    }
  );

  testRaritySocietyDAOImplInitialize();
  testRaritySocietyDAOImplSettings();
  testRaritySocietyDAOImplPropose();
  testRaritySocietyDAOImplCastVote();
  testRaritySocietyDAOImplLifecycle();
});
