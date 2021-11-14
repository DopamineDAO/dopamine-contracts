import { utils, BigNumber, constants, Event } from "ethers";
import { expect } from "chai";
import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import { RaritySocietyToken, IProxyRegistry, MockRaritySocietyDAOImpl__factory } from "../typechain";
import { raritySocietyTokenFixture, RaritySocietyTokenFixture, raritySocietyDAOImplFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { testRaritySocietyDAOImplInitialize } from './raritySocietyDAOImpl/initialize.behavior';
import { testRaritySocietyDAOImplPropose } from './raritySocietyDAOImpl/propose.behavior';
import { testRaritySocietyDAOImplSettings } from './raritySocietyDAOImpl/settings.behavior';
import { testRaritySocietyDAOImplCastVote } from './raritySocietyDAOImpl/castVote.behavior';
import { testRaritySocietyDAOImplLifecycle } from './raritySocietyDAOImpl/lifecycle.behavior';

const { createFixtureLoader } = waffle;

describe("RaritySocietyDAO", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
	let signers: SignerWithAddress[];

  before('initialize fixture loader', async function () {
		signers = await ethers.getSigners();
		[this.deployer, this.admin, this.vetoer, this.voter, this.delegator] = signers;

    loadFixture = createFixtureLoader([this.deployer, this.admin, this.vetoer] as Signer[] as Wallet[]);
  });

  beforeEach('instantiate fixtures for RaritySocietyDAOImpl', async function () {
		({ token: this.token, timelock: this.timelock, daoImplFactory: this.daoImplFactory, daoImpl: this.daoImpl } = await loadFixture(raritySocietyDAOImplFixture));
	});

	testRaritySocietyDAOImplInitialize();
	testRaritySocietyDAOImplSettings();
	testRaritySocietyDAOImplPropose();
	testRaritySocietyDAOImplCastVote();
	testRaritySocietyDAOImplLifecycle();
	
});
