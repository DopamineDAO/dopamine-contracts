import { task, types } from "hardhat/config";

task('propose', 'Create a governance proposal')
	.addOptionalParam(
		'address',
		'The Dopamine DAO proxy address',
		'0xd3f50dFeCa7CC48E394C0863a4B8559447573608',
		types.string,
	)
	.setAction(async ({ address }, { ethers }) => {
		const factory = await ethers.getContractFactory('RaritySocietyDAOImpl');
		const dao = await factory.attach(address);

		const [deployer] = await ethers.getSigners();
		const val = ethers.utils.parseEther('1');

		const receipt = await (
			await dao.propose(
				[deployer.address],
				[val],
				[''],
				['0x'],
				'Test proposal',
			)
		).wait();
		console.log(receipt);
	});
