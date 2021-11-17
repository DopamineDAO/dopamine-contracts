import { task, types } from "hardhat/config";

task('mint', 'Mint a Rarity Society NFT')
	.addOptionalParam(
		'address',
		'RaritySocietyToken address',
		'0xE70aDf9B0fbAA03Cee6f61daF6A3ebff46331c9e',
		types.string,
	)
	.setAction(async ({ address }, { ethers}) => {
		const factory = await ethers.getContractFactory('RaritySocietyToken');
		const token = await factory.attach(address);
		const receipt = await (await token.mint()).wait();
		console.log(receipt);

	});
