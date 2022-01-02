import { Fixture } from "ethereum-waffle";
import { BigNumber, BigNumberish, Event } from "ethers";
import { constants } from "ethers";
import { expect } from "chai";
import { Signer } from "@ethersproject/abstract-signer";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { waffle, ethers } from "hardhat";
import { Constants } from "./shared/constants";
import { Wallet } from "@ethersproject/wallet";
import { raritySocietyAuctionHouseFixture, gasBurnerFixture } from "./shared/fixtures";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
	mintN,
  stopMining,
  startMining,
  setNextBlockTimestamp,
  mineBlock,
} from "./shared/utils";

const { createFixtureLoader } = waffle;

type SettleAuctionFn = (
  sender: SignerWithAddress,
) => Promise<TransactionResponse>;

describe("RaritySocietyAuctionHouse", function () {
  let loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  let signers: SignerWithAddress[];

  before("initialize fixture loader", async function () {
    signers = await ethers.getSigners();
    [this.deployer, this.reserve, this.bidderA, this.bidderB] = signers;

    loadFixture = createFixtureLoader([this.deployer] as Signer[] as Wallet[]);
  });

  beforeEach(
    "instantiate fixtures for RaritySocietyAuctionHouse",
    async function () {
      ({
        token: this.token,
        weth: this.weth,
        auctionHouse: this.auctionHouse,
      } = await loadFixture(raritySocietyAuctionHouseFixture));
    }
  );

	it("throws when initialized with incorrect settings", async function () {
			await expect(
				this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.TREASURY_SPLIT,
					Constants.MIN_TIME_BUFFER - 1,
					Constants.RESERVE_PRICE,
					Constants.DURATION
				)
			).to.be.revertedWith("time buffer is invalid");

			await expect(
				this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.TREASURY_SPLIT,
					Constants.TIME_BUFFER,
					Constants.MAX_RESERVE_PRICE.add(1),
					Constants.DURATION
				)
			).to.be.revertedWith("reserve price is invalid");

			await expect(
				this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.MAX_TREASURY_SPLIT + 1,
					Constants.TIME_BUFFER,
					Constants.RESERVE_PRICE,
					Constants.DURATION
				)
			).to.be.revertedWith("treasury split is invalid");

			await expect(
				this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.TREASURY_SPLIT,
					Constants.TIME_BUFFER,
					Constants.MAX_RESERVE_PRICE,
					Constants.MAX_DURATION + 1,
				)
			).to.be.revertedWith("duration is invalid");
	});

	context("when properly initialized", function () {

		let tx: TransactionResponse;

		beforeEach(async function () {
				tx = await this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.TREASURY_SPLIT,
					Constants.TIME_BUFFER,
					Constants.RESERVE_PRICE,
					Constants.DURATION,
				)
		});

		describe("initialization", function () {
			it("correctly initializes all parameters and variables", async function () {
				expect(await this.auctionHouse.token()).to.equal(this.token.address);
				expect(await this.auctionHouse.weth()).to.equal(this.weth.address);
				expect(await this.auctionHouse.reserve()).to.equal(this.reserve.address);
				expect(await this.auctionHouse.timeBuffer()).to.equal(Constants.TIME_BUFFER);
				expect(await this.auctionHouse.treasurySplit()).to.equal(Constants.TREASURY_SPLIT);
				expect(await this.auctionHouse.reservePrice()).to.equal(Constants.RESERVE_PRICE);
				expect(await this.auctionHouse.duration()).to.equal(Constants.DURATION);
			});

			it("emits events for all set parameters", async function () {
          expect(tx)
            .to.emit(this.auctionHouse, Constants.EVENT_AUCTION_TREASURY_SPLIT_SET)
            .withArgs(Constants.TREASURY_SPLIT).and
            .to.emit(this.auctionHouse, Constants.EVENT_AUCTION_TIME_BUFFER_SET)
            .withArgs(Constants.TIME_BUFFER).and
						.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_RESERVE_PRICE_SET)
						.withArgs(Constants.RESERVE_PRICE).and
						.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_DURATION_SET)
						.withArgs(Constants.DURATION);
			});

			it("throws when reinitialized again", async function () {
				await expect(this.auctionHouse.initialize(
					this.token.address,
					this.reserve.address,
					this.weth.address,
					Constants.TREASURY_SPLIT,
					Constants.TIME_BUFFER,
					Constants.RESERVE_PRICE,
					Constants.DURATION,
				)).to.be.revertedWith('Initializable: contract is already initialized')
			});

			it("pauses the auction house", async function () {
				expect(await this.auctionHouse.paused()).to.equal(true);
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_PAUSED).withArgs(this.deployer.address);
			});

			it("transfers ownership to the deployer", async function () {
				expect(await this.auctionHouse.owner()).to.equal(this.deployer.address);
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_OWNERSHIP_TRANSFERRED).withArgs(constants.AddressZero, this.deployer.address);
			});
		});

		describe("setters", function () {

			context("when setting the treasury split", function () {
				it("appropriately sets valid treasury split values", async function () {
					const tx = await this.auctionHouse.setTreasurySplit(Constants.MAX_TREASURY_SPLIT);
					expect(await this.auctionHouse.treasurySplit()).to.equal(Constants.MAX_TREASURY_SPLIT);
					expect(tx).to.emit(this.auctionHouse, Constants.EVENT_AUCTION_TREASURY_SPLIT_SET).withArgs(Constants.MAX_TREASURY_SPLIT);
				});

				it("reverts when setting a treasury split above 100%", async function () {
					await expect(this.auctionHouse.setTreasurySplit(Constants.MAX_TREASURY_SPLIT + 1)).to.be.revertedWith('treasury split is invalid')
				});
			});

			context("when setting the time buffer", function () {
				it("appropriately sets valid time buffers", async function () {
					const tx = await this.auctionHouse.setTimeBuffer(Constants.MAX_TIME_BUFFER);
					expect(await this.auctionHouse.timeBuffer()).to.equal(Constants.MAX_TIME_BUFFER);
					expect(tx).to.emit(this.auctionHouse, Constants.EVENT_AUCTION_TIME_BUFFER_SET).withArgs(Constants.MAX_TIME_BUFFER);
				});

				it("reverts when setting a time buffer above the max or below min", async function () {
					await expect(this.auctionHouse.setTimeBuffer(Constants.MAX_TIME_BUFFER + 1)).to.be.revertedWith('time buffer is invalid')
					await expect(this.auctionHouse.setTimeBuffer(Constants.MIN_TIME_BUFFER - 1)).to.be.revertedWith('time buffer is invalid')
				});
			});

			context("when setting the reserve price", function () {
				it("appropriately sets valid reserve prices", async function () {
					const tx = await this.auctionHouse.setReservePrice(Constants.MAX_RESERVE_PRICE);
					expect(await this.auctionHouse.reservePrice()).to.equal(Constants.MAX_RESERVE_PRICE);
					expect(tx).to.emit(this.auctionHouse, Constants.EVENT_AUCTION_RESERVE_PRICE_SET).withArgs(Constants.MAX_RESERVE_PRICE);
				});

				it("reverts when setting a reserve price above the max or below min", async function () {
					await expect(this.auctionHouse.setReservePrice(Constants.MAX_RESERVE_PRICE.add(1))).to.be.revertedWith('reserve price is invalid')
					await expect(this.auctionHouse.setReservePrice(Constants.MIN_RESERVE_PRICE - 1)).to.be.revertedWith('reserve price is invalid')
				});
			});

			context("when setting the duration", function () {
				it("appropriately sets valid durations", async function () {
					const tx = await this.auctionHouse.setDuration(Constants.MAX_DURATION);
					expect(await this.auctionHouse.duration()).to.equal(Constants.MAX_DURATION);
					expect(tx).to.emit(this.auctionHouse, Constants.EVENT_AUCTION_DURATION_SET).withArgs(Constants.MAX_DURATION);
				});

				it("reverts when setting a duration above the max or below min", async function () {
					await expect(this.auctionHouse.setDuration(Constants.MAX_DURATION + 1)).to.be.revertedWith('duration is invalid')
					await expect(this.auctionHouse.setDuration(Constants.MIN_DURATION - 1)).to.be.revertedWith('duration is invalid')
				});
			});
		});

		describe("unpausing", function () {

			it("should allow the owner to unpause the contract", async function () {
				const tx = await this.auctionHouse.unpause();
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_UNPAUSED).withArgs(this.deployer.address);
				expect(await this.auctionHouse.paused()).to.equal(false);
			});

			it("should throw when unpaused by a non-owner", async function () {
					await expect(this.auctionHouse.connect(this.bidderA).unpause()).to.be.revertedWith('Ownable: caller is not the owner')
			});

			it("should throw when unpausing an already unpaused auction", async function () {
					await this.auctionHouse.unpause();
					await expect(this.auctionHouse.unpause()).to.be.revertedWith('Pausable: not paused');
			});

			it("creates an auction when unpaused for the first time", async function () {
				expect(await this.token.totalSupply()).to.equal(0);
        const timestamp = (await ethers.provider.getBlock("latest")).timestamp + 1;
        await setNextBlockTimestamp(timestamp);
				const tx = await this.auctionHouse.unpause();
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_AUCTION_CREATED).withArgs(
					0,
					timestamp,
					timestamp + Constants.DURATION,
				);
				expect(await this.token.totalSupply()).to.equal(1);
			});

			it("remains paused when unpaused for the first time and minting fails", async function () {
				const tokenSupply = await this.token.maxSupply();
				await mintN(this.token, tokenSupply); // Max capacity reached.
				const tx = await this.auctionHouse.unpause();
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_PAUSED).withArgs(this.deployer.address);
				expect(await this.auctionHouse.paused()).to.equal(true);
				expect(await this.token.totalSupply()).to.equal(tokenSupply);
			});

			
		});

		describe("pausing", function () {

			it("should throw when pausing an already-paused contract", async function () {
					await expect(this.auctionHouse.pause()).to.be.revertedWith('Pausable: paused');
			});

			it("should allow the owner to pause the contract", async function () {
				await this.auctionHouse.unpause();
				const tx = await this.auctionHouse.pause();
				expect(tx).to.emit(this.auctionHouse, Constants.EVENT_PAUSED).withArgs(this.deployer.address);
			});

			it("should throw when paused by a non-owner", async function () {
					await this.auctionHouse.unpause();
					await expect(this.auctionHouse.connect(this.bidderA).pause()).to.be.revertedWith('Ownable: caller is not the owner')
			});

		});
		
		describe("bidding", function () {

			var timestamp: number;

			beforeEach(async function () {
        timestamp = (await ethers.provider.getBlock("latest")).timestamp + 1;
        await setNextBlockTimestamp(timestamp);
				await this.auctionHouse.unpause(); // creates auction
			});

			it("throws when bidding for a token not yet up for auction", async function () {
				await expect(this.auctionHouse.createBid(1)).to.be.revertedWith('Rarity Pass not up for auction')
			});

			it("throws when bidding for an expired auction", async function () {
				const endTime = timestamp + Constants.DURATION;
        await setNextBlockTimestamp(endTime);
				await expect(this.auctionHouse.createBid(0)).to.be.revertedWith('Auction expired');
			});

			it("throws when specifying a bid with no value", async function () {
				await expect(this.auctionHouse.createBid(0)).to.be.revertedWith('Bid lower than reserve price');
				await expect(this.auctionHouse.createBid(0, {value: 0})).to.be.revertedWith('Bid lower than reserve price');
			});

			it("throws when specifying a bid less than the reserve price", async function () {
				await expect(this.auctionHouse.createBid(0, {value: Constants.RESERVE_PRICE - 1})).to.be.revertedWith('Bid lower than reserve price');
			});

			it("throws when bidding less than 5% of the previous bid", async function () {
				
				await this.auctionHouse.createBid(0, {value: 100});
				await expect(this.auctionHouse.createBid(0, {value: 104})).to.be.revertedWith('Bid must be at least 5% greater than last bid');
				await expect(this.auctionHouse.createBid(0, {value: 105})).not.to.be.reverted;
			});

			it("ensures valid unextended bids update auction events and metadata accordingly", async function () {
				expect((await this.auctionHouse.auction()).tokenId).to.equal(0);
				expect((await this.auctionHouse.auction()).amount).to.equal(0);
				expect((await this.auctionHouse.auction()).startTime).to.equal(timestamp);
				expect((await this.auctionHouse.auction()).endTime).to.equal(timestamp + Constants.DURATION);
				expect((await this.auctionHouse.auction()).bidder).to.equal(constants.AddressZero);
				expect((await this.auctionHouse.auction()).settled).to.equal(false);

				const tx = await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});

				expect((await this.auctionHouse.auction()).tokenId).to.equal(0);
				expect((await this.auctionHouse.auction()).amount).to.equal(Constants.RESERVE_PRICE);
				expect((await this.auctionHouse.auction()).startTime).to.equal(timestamp);
				expect((await this.auctionHouse.auction()).endTime).to.equal(timestamp + Constants.DURATION);
				expect((await this.auctionHouse.auction()).bidder).to.equal(this.bidderA.address);
				expect((await this.auctionHouse.auction()).settled).to.equal(false);

				expect(tx)
					.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_BID)
					.withArgs(0, this.bidderA.address, Constants.RESERVE_PRICE, false).and
					.to.not.emit(this.auctionHouse, Constants.EVENT_AUCTION_EXTENDED)
			});

			it("refunds previous bidder after a new bid is placed", async function () {
				await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
				const preNewBidBalance = await this.bidderA.getBalance();

				await this.auctionHouse.connect(this.bidderB).createBid(0, {value: 2 * Constants.RESERVE_PRICE});
				const postNewBidBalance = await this.bidderA.getBalance();

				expect(postNewBidBalance).to.equal(preNewBidBalance.add(Constants.RESERVE_PRICE));
			});

			it("should extend the auction when a bid is received within the time buffer", async function () {
				expect((await this.auctionHouse.auction()).endTime).equals(timestamp + Constants.DURATION);

				const endTime = timestamp + Constants.DURATION;
        await setNextBlockTimestamp(endTime - 1);
				const tx = await this.auctionHouse.createBid(0, {value: Constants.RESERVE_PRICE});
				expect((await this.auctionHouse.auction()).endTime).equals(endTime - 1 + Constants.TIME_BUFFER);
				expect(tx)
					.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_EXTENDED)
					.withArgs(0, endTime - 1 + Constants.TIME_BUFFER).and
					.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_BID)
					.withArgs(0, this.deployer.address, Constants.RESERVE_PRICE, true)
			});

			it("should not extend the auction when a bid is received before the time buffer window", async function () {
				expect((await this.auctionHouse.auction()).endTime).equals(timestamp + Constants.DURATION);

				const endTime = timestamp + Constants.DURATION - Constants.TIME_BUFFER;
				await setNextBlockTimestamp(endTime - 1);
				const tx = await this.auctionHouse.createBid(0, {value: Constants.RESERVE_PRICE});
				expect((await this.auctionHouse.auction()).endTime).equals(timestamp + Constants.DURATION);
			});

			it("should not allow past malicious bidders to create inexorbiant gas bidding prices", async function () {
				const gasBurner = await loadFixture(gasBurnerFixture);
				
				await (await gasBurner.connect(this.bidderA).createBid(
					this.auctionHouse.address, 0, {value: Constants.RESERVE_PRICE}
				)).wait();

				const gasHeavyTx = await this.auctionHouse.connect(this.bidderB).createBid(
					0, {value: Constants.RESERVE_PRICE * 2, gasLimit: 300_000}
				);
				const gasHeavyReceipt = await gasHeavyTx.wait();

				expect(gasHeavyReceipt.gasUsed.toNumber()).to.be.lessThan(150_000);
				expect(await this.weth.balanceOf(gasBurner.address)).to.equal(Constants.RESERVE_PRICE);
			});
		});

		describe("auction settlement", function () {
			
			var timestamp: number;

			describe("settleAuction()", function () {

				beforeEach(async function () {
					timestamp = (await ethers.provider.getBlock("latest")).timestamp + 1;
					await setNextBlockTimestamp(timestamp);
				});

				it("throws when trying to settle an auction that has not yet begun", async function () {
          await expect(this.auctionHouse.settleAuction()).to.be.revertedWith("Auction hasn't begun");
				});

				context("when settling an initiated auction", function () {

					beforeEach(async function () {
						await this.auctionHouse.unpause();
					});

					it("throws when settling an already settled auction", async function () {
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);

							await this.auctionHouse.pause()
							await expect(this.auctionHouse.settleAuction()).not.to.be.reverted;
							await expect(this.auctionHouse.settleAuction()).to.be.revertedWith("Auction has already been settled")
					});

					it("throws when settling an auction yet to complete", async function () {
							const endTime = timestamp + Constants.DURATION - 1;
							await setNextBlockTimestamp(endTime);
							await this.auctionHouse.pause()
							await expect(this.auctionHouse.settleAuction()).not.be.revertedWith("Auction hasn't completed");
					});

					it("transfers the auctioned NFT to the owner if no bids were made", async function () {
							expect(await this.token.balanceOf(this.deployer.address)).to.equal(0);
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);

							await this.auctionHouse.pause();
							await this.auctionHouse.settleAuction();

							expect(await this.token.balanceOf(this.deployer.address)).to.equal(1);
					});

					it("awards the auctioned NFT to the last bidder", async function () {

							expect(await this.token.balanceOf(this.bidderA.address)).to.equal(0);
							expect(await this.token.balanceOf(this.bidderB.address)).to.equal(0);
							await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
							await this.auctionHouse.connect(this.bidderB).createBid(0, {value: 2 * Constants.RESERVE_PRICE});
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);
							await this.auctionHouse.pause();
							await this.auctionHouse.settleAuction();
							expect(await this.token.balanceOf(this.bidderA.address)).to.equal(0);
							expect(await this.token.balanceOf(this.bidderB.address)).to.equal(1);
					});

					it("sends the auction proceeds to the treasury and team", async function () {
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						const endTime = timestamp + Constants.DURATION;
						await setNextBlockTimestamp(endTime);
						await this.auctionHouse.pause();

						const ownerPrevBalance = await ethers.provider.getBalance(await this.auctionHouse.owner());
						const reservePrevBalance = await ethers.provider.getBalance(await this.auctionHouse.reserve());

						await this.auctionHouse.connect(this.bidderA).settleAuction();

						const treasuryProceeds = Math.floor(Constants.RESERVE_PRICE * Constants.TREASURY_SPLIT / 100);
						console.log(treasuryProceeds)
						const reserveProceeds = Constants.RESERVE_PRICE - treasuryProceeds;

						const actualOwnerBalance = await ethers.provider.getBalance(await this.auctionHouse.owner());
						const actualReserveBalance = await ethers.provider.getBalance(await this.auctionHouse.reserve());

						expect(ownerPrevBalance.add(treasuryProceeds)).to.equal(actualOwnerBalance);
						expect(reservePrevBalance.add(reserveProceeds)).to.equal(actualReserveBalance);
					});

					it("emits an AuctionSettled event", async function () {
						const endTime = timestamp + Constants.DURATION;
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						await setNextBlockTimestamp(endTime);
						await this.auctionHouse.pause();

						const tx = await this.auctionHouse.settleAuction();
						expect(tx)
							.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_SETTLED)
							.withArgs(0, this.bidderA.address, Constants.RESERVE_PRICE)
					});

					it("correctly updates auction state", async function () {
						const endTime = timestamp + Constants.DURATION;
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						await setNextBlockTimestamp(endTime);
						await this.auctionHouse.pause();
						await this.auctionHouse.settleAuction();
						
						expect((await this.auctionHouse.auction()).tokenId).to.equal(0);
						expect((await this.auctionHouse.auction()).amount).to.equal(Constants.RESERVE_PRICE);
						expect((await this.auctionHouse.auction()).startTime).to.equal(timestamp);
						expect((await this.auctionHouse.auction()).endTime).to.equal(endTime);
						expect((await this.auctionHouse.auction()).bidder).to.equal(this.bidderA.address);
						expect((await this.auctionHouse.auction()).settled).to.equal(true);
					});
					
				});
			});

			describe("settleCurrentAndCreateNewAuction()", function () {
				
				it("throws when trying to settle an auction that has not yet begun", async function () {
          await expect(this.auctionHouse.settleCurrentAndCreateNewAuction()).to.be.revertedWith("Pausable: paused");
				});

				context("when settling an initiated auction", function () {
					beforeEach(async function () {
						timestamp = (await ethers.provider.getBlock("latest")).timestamp + 1;
						await setNextBlockTimestamp(timestamp);
						await this.auctionHouse.unpause(); // creates auction
					});

					it("throws when settling an already settled auction", async function () {
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);

							await this.auctionHouse.pause()
							await expect(this.auctionHouse.settleAuction()).not.to.be.reverted;
							await expect(this.auctionHouse.settleCurrentAndCreateNewAuction()).to.be.revertedWith("Pausable: paused")
					});

					it("throws when settling an auction yet to complete", async function () {
							const endTime = timestamp + Constants.DURATION - 1;
							await setNextBlockTimestamp(endTime);
							await expect(this.auctionHouse.settleCurrentAndCreateNewAuction()).to.be.revertedWith("Auction hasn't completed");
					});

					it("transfers the auctioned NFT to the owner if no bids were made", async function () {
							expect(await this.token.balanceOf(this.deployer.address)).to.equal(0);
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);
							await this.auctionHouse.settleCurrentAndCreateNewAuction();
							expect(await this.token.balanceOf(this.deployer.address)).to.equal(1);
					});

					it("awards the auctioned NFT to the last bidder", async function () {

							expect(await this.token.balanceOf(this.bidderA.address)).to.equal(0);
							expect(await this.token.balanceOf(this.bidderB.address)).to.equal(0);
							await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
							await this.auctionHouse.connect(this.bidderB).createBid(0, {value: 2 * Constants.RESERVE_PRICE});
							const endTime = timestamp + Constants.DURATION;
							await setNextBlockTimestamp(endTime);
							await this.auctionHouse.settleCurrentAndCreateNewAuction();
							expect(await this.token.balanceOf(this.bidderA.address)).to.equal(0);
							expect(await this.token.balanceOf(this.bidderB.address)).to.equal(1);
					});

					it("sends the auction proceeds to the treasury and team", async function () {
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						const endTime = timestamp + Constants.DURATION;
						await setNextBlockTimestamp(endTime);

						const ownerPrevBalance = await ethers.provider.getBalance(await this.auctionHouse.owner());
						const reservePrevBalance = await ethers.provider.getBalance(await this.auctionHouse.reserve());

						await this.auctionHouse.connect(this.bidderA).settleCurrentAndCreateNewAuction();

						const treasuryProceeds = Math.floor(Constants.RESERVE_PRICE * Constants.TREASURY_SPLIT / 100);
						console.log(treasuryProceeds)
						const reserveProceeds = Constants.RESERVE_PRICE - treasuryProceeds;

						const actualOwnerBalance = await ethers.provider.getBalance(await this.auctionHouse.owner());
						const actualReserveBalance = await ethers.provider.getBalance(await this.auctionHouse.reserve());

						expect(ownerPrevBalance.add(treasuryProceeds)).to.equal(actualOwnerBalance);
						expect(reservePrevBalance.add(reserveProceeds)).to.equal(actualReserveBalance);
					});

					it("emits an AuctionSettled event", async function () {
						const endTime = timestamp + Constants.DURATION;
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						await setNextBlockTimestamp(endTime);
						const tx = await this.auctionHouse.settleCurrentAndCreateNewAuction();
						expect(tx)
							.to.emit(this.auctionHouse, Constants.EVENT_AUCTION_SETTLED)
							.withArgs(0, this.bidderA.address, Constants.RESERVE_PRICE)
					});

					it("correctly updates auction state to that of a fresh new auction", async function () {
						const endTime = timestamp + Constants.DURATION;
						await this.auctionHouse.connect(this.bidderA).createBid(0, {value: Constants.RESERVE_PRICE});
						await setNextBlockTimestamp(endTime);
						await this.auctionHouse.settleCurrentAndCreateNewAuction();
						
						expect((await this.auctionHouse.auction()).tokenId).to.equal(1);
						expect((await this.auctionHouse.auction()).amount).to.equal(0);
						expect((await this.auctionHouse.auction()).startTime).to.equal(endTime);
						expect((await this.auctionHouse.auction()).endTime).to.equal(endTime + Constants.DURATION);
						expect((await this.auctionHouse.auction()).bidder).to.equal(constants.AddressZero);
						expect((await this.auctionHouse.auction()).settled).to.equal(false);
					});

				});
					
				});
		});

	});

});
