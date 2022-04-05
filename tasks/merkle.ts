import MerkleTree from 'merkletreejs';
import keccak256 from 'keccak256';
import { task, types } from "hardhat/config";
import { utils } from "ethers";

task('merkle', 'Create a merkle distribution')
	.addVariadicPositionalParam(
		'inputs',
		'List of address:tokenId pairings',
		[]
	)
	.setAction(async ({ inputs }, { ethers }) => {
		const merkleTree = new MerkleTree(
			inputs.map(
				(input: string) => merkleHash(
					input.split(':')[0],
					input.split(':')[1]
				)
			),
			keccak256,
			{ sortPairs: true }
		);
		const merkleRoot = merkleTree.getHexRoot();
		process.stdout.write(merkleRoot);
	});

task('merkleproof', 'Get merkle proof')
	.addOptionalVariadicPositionalParam(
		'inputs',
		'List of address:tokenId pairings',
		[]
	)
	.addOptionalParam(
		'input',
		'String in the format {address}:{id}',
		'',
		types.string
	)
	.setAction(async ({ inputs, input }, { ethers }) => {
		const merkleTree = new MerkleTree(
			inputs.map(
				(input: string) => merkleHash(
					input.split(':')[0],
					input.split(':')[1]
				)
			),
			keccak256,
			{ sortPairs: true }
		);
		const merkleRoot = merkleTree.getHexRoot();
		const address = input.split(':')[0];
		const id = input.split(':')[1];
		const proof = merkleTree.getHexProof(
			merkleHash(address, id)
		)

		console.log(proof);
		const encodedProof = utils.defaultAbiCoder.encode(["bytes32[]"], [proof]);
		process.stdout.write(encodedProof);
	});

function merkleHash(address: string, id: string): Buffer {
	return Buffer.from(
		utils.solidityKeccak256(["address", "uint256"], [address, id]).slice('0x'.length), 'hex'
	);
}
