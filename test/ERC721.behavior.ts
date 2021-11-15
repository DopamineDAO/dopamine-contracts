import { BigNumber, BigNumberish, constants, Event } from "ethers";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { MockERC721Receiver__factory } from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { extractTokensFromEvents, supportsInterfaces } from "./shared/utils";

const ERC721_RECEIVER_MAGIC_VALUE = "0x150b7a02";

const DATA = "0xdeadbeef";
const TOKEN_ID_0 = BigNumber.from("0");
const TOKEN_ID_1 = BigNumber.from("1");
const TOKEN_ID_NON_EXISTENT = BigNumber.from("4");

type TransferFn = (
  from: string,
  to: string,
  tokenId: BigNumberish,
  sender: SignerWithAddress
) => Promise<TransactionResponse>;

const transferFrom = function (
  this: Mocha.Context,
  from: string,
  to: string,
  tokenId: BigNumberish,
  sender: SignerWithAddress
) {
  return this.token.connect(sender).transferFrom(from, to, tokenId);
};

const safeTransferFromWithoutData = function (
  this: Mocha.Context,
  from: string,
  to: string,
  tokenId: BigNumberish,
  sender: SignerWithAddress
) {
  return this.token
    .connect(sender)
    ["safeTransferFrom(address,address,uint256)"](from, to, tokenId);
};

const safeTransferFromWithData = function (
  this: Mocha.Context,
  from: string,
  to: string,
  tokenId: BigNumberish,
  sender: SignerWithAddress
) {
  return this.token
    .connect(sender)
    ["safeTransferFrom(address,address,uint256,bytes)"](
      from,
      to,
      tokenId,
      DATA
    );
};

export function shouldBehaveLikeERC721(): void {
  describe("ERC721 functionality", function () {
    beforeEach(async function () {
      await this.token.mint();
      await this.token.mint();
    });

    describe("supports ERC721 interfaces", function () {
      supportsInterfaces(["ERC165", "ERC721"]);
    });

    describe("balanceOf()", function () {
      it("returns the number of tokens held by an address", async function () {
        expect(await this.token.balanceOf(this.from.address)).to.equal(
          BigNumber.from("2")
        );
      });

      it("returns 0 for addresses with no owned tokens", async function () {
        expect(await this.token.balanceOf(this.to.address)).to.equal(
          BigNumber.from("0")
        );
      });

      it("throws for queries to the zero address", async function () {
        await expect(
          this.token.balanceOf(constants.AddressZero)
        ).to.be.revertedWith("ERC721: balance query for the zero address");
      });
    });

    describe("ownerOf()", function () {
      it("returns the address of the owner of a token", async function () {
        expect(await this.token.ownerOf(TOKEN_ID_0)).to.equal(
          this.from.address
        );
      });

      it("throws for queries to tokens assigned to the zero address", async function () {
        await expect(
          this.token.ownerOf(TOKEN_ID_NON_EXISTENT)
        ).to.be.revertedWith("ERC721: owner query for nonexistent token");
      });
    });

    context("transfer functions", function () {
      const expectedTransferBehavior = function (
        transferFunc: TransferFn,
        tokenId: BigNumberish
      ) {
        let tx: Promise<TransactionResponse>;
        let fromBalance: BigNumber;
        let toBalance: BigNumber;

        context(
          "when transferring owner's token to to a non-zero address",
          function () {
            beforeEach(async function () {
              fromBalance = await this.token.balanceOf(this.from.address);
              toBalance = await this.token.balanceOf(this.to.address);
              tx = transferFunc.bind(this)(
                this.from.address,
                this.to.address,
                tokenId,
                this.sender
              );
              await Promise.resolve(tx);
            });

            it("adjust's the owner's balance", async function () {
              expect(await this.token.balanceOf(this.from.address)).to.equal(
                this.from != this.to
                  ? fromBalance.sub(BigNumber.from("1"))
                  : fromBalance
              );
            });

            it("adjust's the receiver's balance", async function () {
              expect(await this.token.balanceOf(this.to.address)).to.equal(
                this.from != this.to
                  ? toBalance.add(BigNumber.from("1"))
                  : toBalance
              );
            });

            it("transfers ownership to the receiver", async function () {
              expect(await this.token.ownerOf(tokenId)).to.equal(
                this.to.address
              );
            });

            it("emits a Transfer event", async function () {
              expect(tx)
                .to.emit(this.token, "Transfer")
                .withArgs(this.from.address, this.to.address, tokenId);
            });

            it("emits an Approval event", async function () {
              expect(tx)
                .to.emit(this.token, "Approval")
                .withArgs(this.from.address, constants.AddressZero, tokenId);
            });
          }
        );

        it("throws when `_from` is not the actual owner", async function () {
          await expect(
            transferFunc.bind(this)(
              this.receiver.address,
              this.to.address,
              tokenId,
              this.sender
            )
          ).to.be.revertedWith("ERC721: transfer of token that is not own");
        });

        it("throws when `_tokenId` is not valid", async function () {
          await expect(
            transferFunc.bind(this)(
              this.from.address,
              this.to.address,
              BigNumber.from("9999"),
              this.sender
            )
          ).to.be.revertedWith("ERC721: operator query for nonexistent token");
        });
      };

      const expectedTransferFunctionBehavior = function (
        transferFunc: TransferFn
      ) {
        it("throws when sender is not owner, authorized operator, or approved address", async function () {
          await expect(
            transferFunc.bind(this)(
              this.from.address,
              this.to.address,
              TOKEN_ID_0,
              this.receiver
            )
          ).to.be.revertedWith(
            "ERC721: transfer caller is not owner nor approved"
          );
        });

        context("when owner invokes transfer to receiver", function () {
          expectedTransferBehavior(transferFunc, TOKEN_ID_0);
        });

        context("when owner invokes transfer to self", function () {
          beforeEach(async function () {
            this.to = this.deployer;
          });
          expectedTransferBehavior(transferFunc, TOKEN_ID_0);
        });

        context(
          "when authorized operator invokes transfer to receiver",
          function () {
            beforeEach(async function () {
              this.sender = this.operator;
              await this.token.setApprovalForAll(this.operator.address, true);
            });
            expectedTransferBehavior(transferFunc, TOKEN_ID_0);
          }
        );

        context(
          "when approved address invokes transfer to receiver",
          function () {
            beforeEach(async function () {
              this.sender = this.approved;
              await this.token.approve(this.approved.address, TOKEN_ID_0);
            });
            expectedTransferBehavior(transferFunc, TOKEN_ID_0);
          }
        );
      };

      const expectedSafeTransferFunctionBehavior = function (
        transferFunc: TransferFn
      ) {
        context("when transferring to an EOA", function () {
          expectedTransferFunctionBehavior(transferFunc);
        });

        context("when transferring to a contract", function () {
          describe("when the contract is a valid ERC721 receiver", function () {
            beforeEach(async function () {
              this.to = await new MockERC721Receiver__factory(
                this.deployer
              ).deploy(ERC721_RECEIVER_MAGIC_VALUE, false);
            });

            expectedTransferFunctionBehavior(transferFunc);

            it("calls onERC721Received()", async function () {
              await expect(
                transferFunc.bind(this)(
                  this.from.address,
                  this.to.address,
                  TOKEN_ID_0,
                  this.sender
                )
              )
                .to.emit(this.to, "ERC721Received")
                .withArgs(
                  this.from.address,
                  this.sender.address,
                  TOKEN_ID_0,
                  transferFunc == safeTransferFromWithData ? DATA : "0x"
                );
            });
          });

          it("throws when onERC721Received() returns the wrong magic value", async function () {
            this.to = await new MockERC721Receiver__factory(
              this.deployer
            ).deploy("0xDEADBEEF", false);
            await expect(
              transferFunc.bind(this)(
                this.from.address,
                this.to.address,
                TOKEN_ID_0,
                this.sender
              )
            ).to.be.revertedWith(
              "ERC721: transfer to non ERC721Receiver implementer"
            );
          });

          it("throws when onERC721Received() throws", async function () {
            this.to = await new MockERC721Receiver__factory(
              this.deployer
            ).deploy("0xDEADBEEF", true);
            await expect(
              transferFunc.bind(this)(
                this.from.address,
                this.to.address,
                TOKEN_ID_0,
                this.sender
              )
            ).to.be.revertedWith("MockERC721Receiver: throwing");
          });

          it("throws when onERC721Received() is not implemented", async function () {
            this.to = this.token;
            await expect(
              transferFunc.bind(this)(
                this.from.address,
                this.to.address,
                TOKEN_ID_0,
                this.sender
              )
            ).to.be.revertedWith(
              "ERC721: transfer to non ERC721Receiver implementer"
            );
          });
        });
      };

      describe("transferFrom()", function () {
        expectedTransferFunctionBehavior(transferFrom);
      });

      describe("safeTransferFrom()", function () {
        expectedSafeTransferFunctionBehavior(safeTransferFromWithData);
        expectedSafeTransferFunctionBehavior(safeTransferFromWithoutData);
      });
    });

    describe("approve()", function () {
      let tx: Promise<TransactionResponse>;

      const successfulApprovalBehavior = function () {
        it("correctly clears or sets the new approved address", async function () {
          expect(await this.token.getApproved(TOKEN_ID_0)).to.equal(
            this.clearedOrApprovedAddress
          );
        });

        it("emits an approval event", async function () {
          expect(tx)
            .to.emit(this.token, "Approval")
            .withArgs(
              this.from.address,
              this.clearedOrApprovedAddress,
              TOKEN_ID_0
            );
        });
      };

      context("when owner approves another address", function () {
        beforeEach(async function () {
          this.clearedOrApprovedAddress = this.approved.address;
          tx = this.token.approve(this.clearedOrApprovedAddress, TOKEN_ID_0);
          await Promise.resolve(tx);
        });
        successfulApprovalBehavior();
      });

      context("when owner clears approval", function () {
        beforeEach(async function () {
          this.clearedOrApprovedAddress = constants.AddressZero;
          tx = this.token.approve(this.clearedOrApprovedAddress, TOKEN_ID_0);
          await Promise.resolve(tx);
        });
        successfulApprovalBehavior();
      });

      context("when operator approves another address", function () {
        beforeEach(async function () {
          this.clearedOrApprovedAddress = this.approved.address;
          await this.token.setApprovalForAll(this.operator.address, true);
          tx = this.token
            .connect(this.operator)
            .approve(this.clearedOrApprovedAddress, TOKEN_ID_0);
          await Promise.resolve(tx);
        });
        successfulApprovalBehavior();
      });

      context("when operator clears approval", function () {
        beforeEach(async function () {
          this.clearedOrApprovedAddress = constants.AddressZero;
          await this.token.setApprovalForAll(this.operator.address, true);
          tx = this.token
            .connect(this.operator)
            .approve(this.clearedOrApprovedAddress, TOKEN_ID_0);
          await Promise.resolve(tx);
        });
        successfulApprovalBehavior();
      });

      it("throws when approver approves self", async function () {
        await expect(
          this.token.approve(this.from.address, TOKEN_ID_0)
        ).to.be.revertedWith("ERC721: approval to current owner");
      });

      it("throws when approver is not the owner or an approved operator", async function () {
        await expect(
          this.token
            .connect(this.approved)
            .approve(this.approved.address, TOKEN_ID_0)
        ).to.be.revertedWith(
          "ERC721: approve caller is not owner nor approved for all"
        );
      });
    });

    describe("setApprovalForAll()", function () {
      let tx: Promise<TransactionResponse>;

      const setApprovalForAllBehavior = function (approved: boolean) {
        it("correctly changes the operator's authorization", async function () {
          expect(
            await this.token.isApprovedForAll(
              this.from.address,
              this.operator.address
            )
          ).to.equal(approved);
        });

        it("emits an ApprovalForAll event", async function () {
          expect(tx)
            .to.emit(this.token, "ApprovalForAll")
            .withArgs(this.from.address, this.operator.address, approved);
        });
      };

      context("when owner grants operator approval", function () {
        beforeEach(async function () {
          tx = this.token.setApprovalForAll(this.operator.address, true);
          return await Promise.resolve(tx);
        });
        setApprovalForAllBehavior(true);
      });

      context("when owner revokes operator approval", function () {
        beforeEach(async function () {
          await this.token.setApprovalForAll(this.operator.address, true);
          tx = this.token.setApprovalForAll(this.operator.address, false);
          return await Promise.resolve(tx);
        });
        setApprovalForAllBehavior(false);
      });

      it("throws when owner grants operator approval to self", async function () {
        await expect(
          this.token.setApprovalForAll(this.from.address, true)
        ).to.be.revertedWith("ERC721: approve to caller");
      });
    });

    describe("getApproved()", function () {
      beforeEach(async function () {
        await this.token.approve(this.approved.address, TOKEN_ID_0);
      });

      it("should return the approved address for a token", async function () {
        expect(await this.token.getApproved(TOKEN_ID_0)).to.equal(
          this.approved.address
        );
      });

      it("should return the zero address for tokens with no approved addresses", async function () {
        expect(await this.token.getApproved(TOKEN_ID_1)).to.equal(
          constants.AddressZero
        );
      });

      it("throws when `_tokenId` is not valid", async function () {
        await expect(
          this.token.getApproved(TOKEN_ID_NON_EXISTENT)
        ).to.be.revertedWith("ERC721: approved query for nonexistent token");
      });
    });

    describe("isApprovedForAll()", function () {
      beforeEach(async function () {
        await this.token.setApprovalForAll(this.operator.address, true);
      });

      it("should return true for approved operators of an owner", async function () {
        expect(
          await this.token.isApprovedForAll(
            this.from.address,
            this.operator.address
          )
        ).to.equal(true);
      });

      it("should return false for unapproved operators of an owner", async function () {
        expect(
          await this.token.isApprovedForAll(
            this.from.address,
            this.approved.address
          )
        ).to.equal(false);
      });
    });
  });
}

export function shouldBehaveLikeERC721Enumerable(): void {
  describe("ERC721Enumerable functionality", function () {
    let circulatingTokens: number[];

    beforeEach(async function () {
      const events: Event[] = [];
      events.push(...(await (await this.token.mint()).wait()).events);
      events.push(...(await (await this.token.mint()).wait()).events);
      events.push(...(await (await this.token.mint()).wait()).events);
      events.push(...(await (await this.token.burn(TOKEN_ID_0)).wait()).events);
      await this.token.transferFrom(
        this.from.address,
        this.to.address,
        TOKEN_ID_1
      );
      ({ existing: circulatingTokens } = extractTokensFromEvents(events));
    });

    describe("supports ERC721Enumerable interface", function () {
      supportsInterfaces(["ERC721Enumerable"]);
    });

    describe("totalSupply()", function () {
      it("returns the correct total supply", async function () {
        expect(await this.token.totalSupply()).to.equal(
          circulatingTokens.length
        );
      });

      it("decreases when tokens are burned", async function () {
        await this.token.burn(2);
        expect(await this.token.totalSupply()).to.equal(
          circulatingTokens.length - 1
        );
      });

      it("increases when new tokens are issued", async function () {
        await this.token.mint();
        expect(await this.token.totalSupply()).to.equal(
          circulatingTokens.length + 1
        );
      });
    });

    describe("tokenByIndex()", function () {
      it("enumerates all circulating tokens", async function () {
        const allTokens = await Promise.all(
          [...Array(circulatingTokens.length).keys()].map((i) =>
            this.token.tokenByIndex(i)
          )
        );
        expect(allTokens.map((i) => i.toNumber())).to.have.same.members(
          circulatingTokens
        );
      });

      it("throws for index queries greater or equal to the total supply", async function () {
        await expect(
          this.token.tokenByIndex(BigNumber.from("2"))
        ).to.be.revertedWith("ERC721Enumerable: global index out of bounds");
      });
    });

    describe("tokenOfOwnerByIndex()", function () {
      it("enumerates all owned tokens for an owner", async function () {
        const numOwned = await this.token.balanceOf(this.from.address);
        const enumerated = await Promise.all(
          [...Array(numOwned).keys()].map((i) =>
            this.token.tokenOfOwnerByIndex(this.from.address, i)
          )
        );
        const ownedTokens: number[] = [];
        await Promise.all(
          circulatingTokens.map(async (i) => {
            if ((await this.token.ownerOf(i)) == this.from.address) {
              ownedTokens.push(i);
            }
          })
        );
        expect(enumerated.map((i) => i.toNumber())).to.have.same.members(
          ownedTokens
        );
      });

      it("throws when index is greater than or equal to number of owned tokens", async function () {
        const numOwned = await this.token.balanceOf(this.from.address);
        await expect(
          this.token.tokenOfOwnerByIndex(this.from.address, numOwned)
        ).to.be.revertedWith("ERC721Enumerable: owner index out of bounds");
      });

      it("throws when queried address owns no tokens", async function () {
        await expect(
          this.token.tokenOfOwnerByIndex(this.approved.address, 0)
        ).to.be.revertedWith("ERC721Enumerable: owner index out of bounds");
      });
    });
  });
}

export function shouldBehaveLikeERC721Metadata(): void {
  describe("ERC721Metadata functionality", function () {
    describe("supports ERC721Metadata interface", function () {
      supportsInterfaces(["ERC721Metadata"]);
    });

    it("returns the name", async function () {
      expect(await this.token.name()).to.equal("Rarity Society");
    });

    it("returns the symbol", async function () {
      expect(await this.token.symbol()).to.equal("RARITY");
    });

    it("returns the correct URI for a token", async function () {
      await this.token.mint();
      expect(await this.token.tokenURI(TOKEN_ID_0)).to.equal(
        "https://raritysociety.com/0"
      );
    });

    it("throws for URI queries of nonexistent tokens", async function () {
      await expect(this.token.tokenURI(TOKEN_ID_0)).to.be.revertedWith(
        "ERC721Metadata: URI query for nonexistent token"
      );
    });
  });
}
