import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import {
  erc721TokenFixture,
} from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  shouldBehaveLikeERC721,
  shouldBehaveLikeERC721Enumerable,
  shouldBehaveLikeERC721Metadata,
} from "./ERC721.behavior";
import { shouldBehaveLikeERC721Checkpointable } from "./ERC721Checkpointable.behavior";

const { createFixtureLoader } = waffle;

describe("ERC721 features", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.receiver, this.approved, this.operator] = signers;

    loadFixture = createFixtureLoader([this.deployer] as Signer[] as Wallet[]);
  });

  beforeEach("instantiate ERC721token fixture", async function () {
    this.token = await loadFixture(
      erc721TokenFixture
    );
    this.from = this.deployer;
    this.to = this.receiver;
    this.sender = this.deployer;
    this.contract = this.token;
  });

   // shouldBehaveLikeERC721();
   // shouldBehaveLikeERC721Enumerable();
   // shouldBehaveLikeERC721Metadata();
   shouldBehaveLikeERC721Checkpointable();
});
