import fs from "fs";
import { Interface } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

// Listed in order of deployment. Wrong order results in error.
enum Contract {
  DopamineHonoraryPass
}

type Args = (string | number)[];
interface VerifyParams {
  args: Args;
  address: string;
	path?: string;
}

task("deploy-h-rinkeby", "Deploy Dopamine contracts to Rinkeby")
  .addParam("verify", "whether to verify on Etherscan", true, types.boolean)
  .setAction(async (args, { run }) => {
    await run("deploy-h", {
      chainid: 4,
			registry: "0x1e525eeaf261ca41b809884cbde9dd9e1619573a",
			royalties: 750,
			reserve: "0x69BABEc995611574eEb683e8801974795F2c4ccd",
      verify: args.verify,
    });
  });

task("deploy-h-goerli", "Deploy Dopamine contracts to Goerli")
  .addParam("verify", "whether to verify on Etherscan", true, types.boolean)
	.setAction(
		async (args, { run }) => {
			await run("deploy-h", {
				chainid: 5,
				registry: "0xf57b2c51ded3a29e6891aba85459d600256cf317",
				royalties: 750,
				reserve: "0xC51dCeF58241d126D8E571D64FcbEDBF79366fBf",
				verify: args.verify,
		});
	});

task(
  "deploy-h-prod",
  "Deploy Dopamine contracts to Ethereum Mainnet"
).setAction(async (args, { run }) => {
  await run("deploy-h", {
    chainid: 1,
    registry: "0xa5409ec958c83c3f309868babaca7c86dcb077c1",
		royalties: 750,
		reserve: "0xC51dCeF58241d126D8E571D64FcbEDBF79366fBf",
		verify: true
  });
});

task("deploy-h", "Deploys Dopamine contracts")
  .addParam("chainid", "expected network chain ID", undefined, types.int)
  .addParam(
    "registry",
    "OpenSea proxy registry address",
    undefined,
    types.string
  )
  .addOptionalParam(
    "verify",
    "whether to verify on Etherscan",
    true,
    types.boolean
  )
  .addOptionalParam(
    "royalties",
    "royalties amount to send to reserve",
    750,
    types.int
  )
  .addOptionalParam(
    "reserve",
    "address to which royalties are directed",
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
      `Deploying Dopamine contracts to chain ${network.chainId}`
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

    const deployContract = async function (
      contract: string,
      args: (string | number)[],
      currNonce: number
    ): Promise<string> {
      console.log(`\nDeploying contract ${contract}:`);

      const contractFactory = await ethers.getContractFactory(contract);

      const gas = await contractFactory.signer.estimateGas(
        contractFactory.getDeployTransaction(...args, { gasPrice })
      );
      const cost = ethers.utils.formatUnits(gas.mul(gasPrice), "ether");
      console.log(`Estimated deployment cost for ${contract}: ${cost}ETH`);

			const deployedContract = await contractFactory.deploy(...args);
			await deployedContract.deployed();

      console.log(`Contract ${contract} deployed to ${deployedContract.address}`);
      return deployedContract.address;
    };

    // Deploy Honorary Dopamine Pass
    const dopamineHonoraryPassArgs: Args = [
      args.registry,
			args.reserve,
			args.royalties,
    ];
    const dopamineHonoraryPass = await deployContract(
      Contract[Contract.DopamineHonoraryPass],
      dopamineHonoraryPassArgs,
			currNonce++
    );

    if (args.verify) {
      const toVerify: Record<string, VerifyParams> = {
        dopamineHonoraryPass: {
          address: dopamineHonoraryPass,
          args: dopamineHonoraryPassArgs,
        },
      };
      for (const contract in toVerify) {
				console.log(`\nVerifying contract ${contract}:`)
				for (let i = 0; i < 3; i++) {
					try {
						if (toVerify[contract].path) {
							await run("verify:verify", {
								address: toVerify[contract].address,
								constructorArguments: toVerify[contract].args,
								contract: toVerify[contract].path,
							});
						} else {
							await run("verify:verify", {
								address: toVerify[contract].address,
								constructorArguments: toVerify[contract].args,
							});
						}
						console.log(`Contract ${contract} succesfully verified!`);
						break
					} catch(e: unknown) {
						let msg: string;
						if (e instanceof Error) {
							msg = e.message
						} else {
							msg = String(e);
						}
						if (msg.includes('Already Verified')) {
							console.log(`Contract ${contract} already verified!`)
							break
						}
						console.log(`Error verifying contract ${contract}: ${msg}`, msg);
					}
				}
      }
    }
    // if (!fs.existsSync('logs')) {
    // 	fs.mkdirSync('logs');
    // }
    // fs.writeFileSync(
    // 	'logs/deploy.json',
    // 	JSON.stringify({
    // 		addresses: {
    // 		},
    // 	}),
    // 	{ flag: 'w' },
    // );
  });
