import MerkleTree from 'merkletreejs';
import keccak256 from 'keccak256';
import { task, types } from "hardhat/config";
import { utils } from "ethers";

task('merkle', 'Create a merkle distribution')
	.addOptionalVariadicPositionalParam(
		'addresses',
		'List of addresses',
		[]
	)
	.setAction(async ({ addresses }, { ethers }) => {
		const merkleTree = new MerkleTree(
			addresses.map((address: string) => merkleHash(address)),
			keccak256,
			{ sortPairs: true }
		);
		const merkleRoot = merkleTree.getHexRoot();
		console.log(merkleRoot);
	});

task('merkleproof', 'Get merkle proof')
	.addOptionalVariadicPositionalParam(
		'addresses',
		'List of addresses',
		[]
	)
	.addOptionalParam(
		'address',
		'Address to retrieve proof',
		'',
		types.string
	)
	.setAction(async ({ addresses, address }, { ethers }) => {
		const merkleTree = new MerkleTree(
			addresses.map((address: string) => merkleHash(address)),
			keccak256,
			{ sortPairs: true }
		);
		const merkleRoot = merkleTree.getHexRoot();
		console.log(merkleTree.getHexProof(
			merkleHash(address)
		));
	});

function merkleHash(address: string): Buffer {
	return Buffer.from(
		utils.solidityKeccak256(["address"], [address]).slice('0x'.length), 'hex'
	);
}
