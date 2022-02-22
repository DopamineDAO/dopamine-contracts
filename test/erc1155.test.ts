import { Fixture } from "ethereum-waffle";
import { Signer } from "@ethersproject/abstract-signer";
import { waffle, ethers } from "hardhat";
import { Wallet } from "@ethersproject/wallet";
import {
  erc1155TokenFixture,
} from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  shouldBehaveLikeERC1155,
  // shouldBehaveLikeERC1155MetadataURI,
} from "./ERC1155.behavior";
// import { shouldBehaveLikeERC1155Votable } from "./ERC1155Votable.behavior";

const { createFixtureLoader } = waffle;

describe("ERC1155 features", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.receiver, this.approved, this.operator] = signers;

    loadFixture = createFixtureLoader([this.deployer] as Signer[] as Wallet[]);
  });

  beforeEach("instantiate ERC1155 fixture", async function () {
    this.token = await loadFixture(
      erc1155TokenFixture
    );
    this.from = this.deployer;
    this.to = this.receiver;
    this.sender = this.deployer;
    this.contract = this.token;
  });

   shouldBehaveLikeERC1155();
   // shouldBehaveLikeERC721Enumerable();
   // shouldBehaveLikeERC721Metadata();
   // shouldBehaveLikeERC721Checkpointable();
});
