import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import { raritySocietyTokenFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  shouldBehaveLikeERC721,
  shouldBehaveLikeERC721Enumerable,
  shouldBehaveLikeERC721Metadata,
} from "./ERC721.behavior";
import { shouldBehaveLikeERC721Checkpointable } from "./ERC721Checkpointable.behavior";

const { createFixtureLoader } = waffle;

describe("RaritySocietyToken", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.receiver, this.approved, this.operator] = signers;

    loadFixture = createFixtureLoader([this.deployer] as Signer[] as Wallet[]);
  });

  beforeEach("instantiate Rarity Society token fixture", async function () {
    ({ token: this.token, registry: this.registry } = await loadFixture(
      raritySocietyTokenFixture
    ));
    this.from = this.deployer;
    this.to = this.receiver;
    this.sender = this.deployer;
    this.contract = this.token;
  });

  shouldBehaveLikeERC721();
  shouldBehaveLikeERC721Enumerable();
  shouldBehaveLikeERC721Metadata();
  shouldBehaveLikeERC721Checkpointable();
});
