import { BigNumber, BigNumberish, constants, Event } from "ethers";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { MockERC1155Receiver__factory } from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { extractTokensFromEvents, supportsInterfaces } from "./shared/utils";

const ERC1155_RECEIVER_MAGIC_VALUE = "0xf23a6e61";
const ERC1155_BATCH_RECEIVER_MAGIC_VALUE ="0xbc197c81";

const DATA = "0xdeadbeef";
const TOKEN_ID_0 = BigNumber.from("0");
const TOKEN_AMOUNT_0 = BigNumber.from("4");
const TOKEN_ID_1 = BigNumber.from("1");
const TOKEN_AMOUNT_1 = BigNumber.from("3");
const TOKEN_ID_NON_EXISTENT = BigNumber.from("4");

type TransferFn = (
  from: string,
  to: string,
  tokenId: BigNumberish[],
	amount: BigNumberish[],
  sender: SignerWithAddress,
	data: string
) => Promise<TransactionResponse>;

const safeTransferFrom = function (
  this: Mocha.Context,
  from: string,
  to: string,
  tokenIds: BigNumberish[],
	amounts: BigNumberish[],
  sender: SignerWithAddress,
	data: string
) {
  return this.token
    .connect(sender)
    ["safeTransferFrom(address,address,uint256,uint256,bytes)"](from, to, tokenIds[0], amounts[0], data);
};

const safeBatchTransferFrom = function (
  this: Mocha.Context,
  from: string,
  to: string,
  tokenIds: BigNumberish[],
	amounts: BigNumberish[],
  sender: SignerWithAddress,
	data: string
) {
  return this.token
    .connect(sender)
    ["safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"](
      from,
      to,
      tokenIds,
			amounts,
      data
    );
};

export function shouldBehaveLikeERC1155(): void {
  describe("ERC1155 functionality", function () {
    beforeEach(async function () {
      await this.token.mint(TOKEN_AMOUNT_0);
      await this.token.mint(TOKEN_AMOUNT_1);
    });

    describe("supports ERC1155 interfaces", function () {
      supportsInterfaces(["ERC165", "ERC1155", "ERC1155MetadataURI"]);
    });

    describe("balanceOf()", function () {
			it("returns the number of tokens held by an address", async function () {
				expect(await this.token.balanceOf(this.from.address, TOKEN_ID_0)).to.equal(
          TOKEN_AMOUNT_0
        );
        expect(await this.token.balanceOf(this.from.address, TOKEN_ID_1)).to.equal(
          TOKEN_AMOUNT_1
        );
      });

      it("returns 0 for addresses with no owned tokens", async function () {
        expect(await this.token.balanceOf(this.to.address, TOKEN_ID_0)).to.equal(
          0
        );
      });

    });

    describe("balanceOfBatch()", function () {

			it("throws when owners and ids have different lengths", async function () {
				await expect(this.token.balanceOfBatch(
					[this.from.address, this.from.address],
					[TOKEN_ID_1]
				)).to.be.revertedWith("ArrayMismatch");
			});

      it("returns the number of tokens held by multiple addresses", async function () {
        const balances = await this.token.balanceOfBatch(
					[this.from.address, this.from.address],
					[TOKEN_ID_0, TOKEN_ID_1]
				);
				expect(balances[0]).to.equal(TOKEN_AMOUNT_0);
				expect(balances[1]).to.equal(TOKEN_AMOUNT_1);
      });

      it("returns 0 for addresses with no owned tokens", async function () {
        const tokens = await this.token.balanceOfBatch([this.to.address, this.to.address], [TOKEN_ID_0, TOKEN_ID_1])
				expect(tokens[0]).to.equal(0);
				expect(tokens[1]).to.equal(0);
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
          tx = await this.token.setApprovalForAll(this.operator.address, true);
        });
        setApprovalForAllBehavior(true);
      });

      context("when owner revokes operator approval", function () {
        beforeEach(async function () {
          tx = await this.token.setApprovalForAll(this.operator.address, false);
        });
        setApprovalForAllBehavior(false);
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

    context("safeTransferFrom()", function () {
      const expectedSafeTransferFromTransferBehavior = function (
        tokenId: BigNumberish,
				amount: BigNumberish,
				data: string
      ) {
        let tx: Promise<TransactionResponse>;
        let fromBalance: BigNumber;
        let toBalance: BigNumber;

        context(
          "when transferring owner's token to to a non-zero address",
					function () {
            beforeEach(async function () {
              fromBalance = await this.token.balanceOf(this.from.address, TOKEN_ID_0);
              toBalance = await this.token.balanceOf(this.to.address, TOKEN_ID_0);
							tx = await this.token.connect(this.sender).safeTransferFrom(
								this.from.address,
								this.to.address,
								tokenId,
								amount,
								data
							);
            });

            it("adjust's the owner's balance", async function () {
              expect(await this.token.balanceOf(this.from.address, TOKEN_ID_0)).to.equal(
                this.from != this.to
                  ? fromBalance.sub(BigNumber.from(amount))
									: fromBalance
							);
            });

            it("adjust's the receiver's balance", async function () {
              expect(await this.token.balanceOf(this.to.address, TOKEN_ID_0)).to.equal(
                this.from != this.to
                  ? toBalance.add(amount)
                  : toBalance
              );
            });


            it("emits a TransferSingle event", async function () {
              expect(tx)
                .to.emit(this.token, "TransferSingle")
                .withArgs(this.sender.address, this.from.address, this.to.address, tokenId, amount);
            });

          }
        );

        it("throws when `_from` is not the actual owner", async function () {
          await expect(
						this.token.connect(this.sender).safeTransferFrom(
							this.receiver.address,
							this.to.address,
							tokenId,
							amount,
							data
						)
          ).to.be.revertedWith("InvalidOperator");
        });

        it("throws when `_tokenId` is not valid", async function () {
          await expect(
						this.token.connect(this.sender).safeTransferFrom(
							this.from.address,
							this.to.address,
							TOKEN_ID_NON_EXISTENT,
							amount,
							data
						)
          ).to.be.revertedWith("InsufficientBalance");
        });

				it("throws when receiver is the 0 address", async function () {
          await expect(
						this.token.connect(this.sender).safeTransferFrom(
							this.from.address,
							constants.AddressZero,
							tokenId,
							amount,
							data
						)
          ).to.be.revertedWith("ZeroAddressReceiver");
        });
      };

      const expectedSafeTransferFromOperatorBehavior = function (
        data: string
      ) {
        it("throws when sender is not owner, authorized operator, or approved address", async function () {
          await expect(
						this.token.connect(this.receiver).safeTransferFrom(
							this.from.address,
							constants.AddressZero,
							TOKEN_ID_0,
							1,
							data
						)
          ).to.be.revertedWith(
            "InvalidOperator"
          );
        });

        context("when owner invokes transfer to receiver", function () {
          expectedSafeTransferFromTransferBehavior(TOKEN_ID_0, TOKEN_AMOUNT_0, data);
        });

        context("when owner invokes transfer to self", function () {
          beforeEach(async function () {
            this.to = this.deployer;
          });
          expectedSafeTransferFromTransferBehavior(TOKEN_ID_0, TOKEN_AMOUNT_0, data);
        });

        context(
          "when authorized operator invokes transfer to receiver",
          function () {
            beforeEach(async function () {
              this.sender = this.operator;
              await this.token.setApprovalForAll(this.operator.address, true);
            });
            expectedSafeTransferFromTransferBehavior(TOKEN_ID_0, TOKEN_AMOUNT_0, data);
          }
        );

      };

      const expectedSafeTransferFromBehavior = function (
        data: string
      ) {
        context("when transferring to an EOA", function () {
          expectedSafeTransferFromOperatorBehavior(data);
        });

        context("when transferring to a contract", function () {
          describe("when the contract is a valid ERC1155 receiver", function () {
            beforeEach(async function () {
              this.to = await new MockERC1155Receiver__factory(
                this.deployer
              ).deploy(ERC1155_RECEIVER_MAGIC_VALUE, false);
            });

            expectedSafeTransferFromOperatorBehavior(data);

            it("calls onERC1155Received()", async function () {
              await expect(
								this.token.connect(this.sender).safeTransferFrom(
									this.from.address,
									this.to.address,
									TOKEN_ID_0,
									1,
									data
								)
              )
                .to.emit(this.to, "ERC1155Received")
                .withArgs(
                  this.sender.address,
                  this.from.address,
                  TOKEN_ID_0,
									1,
                  data,
                );
            });
          });

          it("throws when onERC1155Received() returns the wrong magic value", async function () {
            this.to = await new MockERC1155Receiver__factory(
              this.deployer
            ).deploy("0xDEADBEEF", false);
            await expect(
							this.token.connect(this.sender).safeTransferFrom(
								this.from.address,
								this.to.address,
								TOKEN_ID_0,
								1,
								data
							)
            ).to.be.revertedWith(
              "InvalidReceiver"
            );
          });

          it("throws when onERC1155Received() throws", async function () {
            this.to = await new MockERC1155Receiver__factory(
              this.deployer
            ).deploy("0xDEADBEEF", true);
            await expect(
							this.token.connect(this.sender).safeTransferFrom(
								this.from.address,
								this.to.address,
								TOKEN_ID_0,
								1,
								data
							)
            ).to.be.revertedWith("MockERC1155ReceiverError");
          });

          it("throws when onERC1155Received() is not implemented", async function () {
            this.to = this.token;
            await expect(
							this.token.connect(this.sender).safeTransferFrom(
								this.from.address,
								this.to.address,
								TOKEN_ID_0,
								1,
								data
							)
            ).to.be.reverted;
          });
        });
      };

			expectedSafeTransferFromBehavior("0x");
			expectedSafeTransferFromBehavior(DATA);

    });

  });
}
