import { task, types } from "hardhat/config";

task("mint-rinkeby", "Deploy Rarity Society contracts to Rinkeby")
  .addParam("account", "account address")
  .setAction(async (args, { run }) => {
    await run("mint-h", {
			address: "0x4fd4217427ce18e04bb266027e895a7000d6d0f7",
      chainid: 4,
			account: args.account,
    });
  });

task( "mint-prod", "Deploy Dopamine contracts to Ethereum Mainnet")
  .addParam("account", "account address")
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
    "account",
    "account to mint honorary pass for",
    undefined,
    types.string
  )
	.addOptionalParam(
    "testrun",
    "whether to test first",
    false,
    types.boolean
	)
  .setAction(async (args, { ethers, run }) => {
		console.log(args.address);
		console.log(args.testrun);

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
		if (!args.testrun) {
			const receipt = await (await token.mint(args.account)).wait();
			console.log(receipt);
		}
	});

