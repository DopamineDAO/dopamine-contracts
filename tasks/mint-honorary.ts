import { task, types } from "hardhat/config";
import * as readline from 'readline';
import { stdin as input, stdout as output } from 'node:process';
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

task("mint-h-staging", "Mint using the staging Honorary Pass Contract")
  .addParam("account", "account address")
  .addParam("id", "nft id")
  .setAction(async (args, { run }) => {
    await run("mint-h", {
			address: "0xDbcB30300cFD11C039aFD6afcF2262ad1a220E22",
      chainid: 4,
			account: args.account,
			id: args.id
    });
  });

task("mint-h-dev", "Mint using the dev Honorary Pass Contract")
  .addParam("account", "account address")
  .addParam("id", "nft id")
  .setAction(async (args, { run }) => {
    await run("mint-h", {
			address: "0xFaceF8302B8D4544C02B3382eb02223aA1B1b294",
      chainid: 4,
			account: args.account,
			id: args.id
    });
  });

task( "mint-h-prod", "Deploy Dopamine contracts to Ethereum Mainnet")
  .addParam("account", "account address")
  .addParam("id", "nft id")
	.setAction(async (args, { run }) => {
  await run("mint-h", {
		address: "0x4fd4217427ce18e04bb266027e895a7000d6d0f7",
    chainid: 1,
		account: args.account,
  });
});

task("mint-h", "Mints a Doapmine honorary")
  .addParam("chainid", "expected network chain ID", undefined, types.int)
  .addParam(
    "id",
    "intended nft id",
    undefined,
    types.string
  )
  .addParam(
    "account",
    "account to mint honorary pass for",
    undefined,
    types.string
  )
  .setAction(async (args, { ethers, run }) => {
    const gasPrice = await ethers.provider.getGasPrice();
    const network = await ethers.provider.getNetwork();
    if (network.chainId != args.chainid) {
      console.log(
        `invalid chain ID, expected: ${args.chainid} got: ${network.chainId}`
      );
      return;
    }

    console.log(
      `Minting pass for ${args.account}`
    );

    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${deployer.address}`);
    console.log(
      `Deployer balance: ${ethers.utils.formatEther(
        await deployer.getBalance()
      )} ETH`
    );
    const nonce = await deployer.getTransactionCount();
    let currNonce = nonce;

		const factory = await ethers.getContractFactory('DopamineHonoraryPass');
		const token = await factory.attach(args.address);
		const gas = await token.estimateGas.mint(args.account);
		const cost = ethers.utils.formatUnits(gas.mul(gasPrice), "ether");
		console.log(`Estimated minting cost to address ${args.address}: ${cost}ETH`);
		const totalSupply = Number(await token.totalSupply());
		if (Number(args.id) !== totalSupply + 1) {
			console.log(`the id ${args.id} does not match totalSupply+1=${totalSupply + 1}`)
			return
		}
		console.log(`YOU ARE ABOUT TO DEPLOY ${args.id}!`)
		console.log(`THE RECIPIENT WILL BE ${args.account}!`)
		console.log('SLEEPING FOR 30 SECONDS BEFORE MINTING!');
		await sleep(5000);
		const receipt = await (await token.mint(args.account)).wait();
	  console.log(receipt);
	});

function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
