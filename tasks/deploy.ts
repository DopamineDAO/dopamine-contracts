import { task, types } from "hardhat/config";

// Listed in order of deployment. Wrong order results in error.
enum Contract {
  RaritySocietyToken,
  Timelock,
  RaritySocietyDAOImpl,
  RaritySocietyDAOProxy,
}

task('deploy-local', 'Deploy Rarity Society contracts locally')
  .setAction(async (args, { run }) => {
		await run('deploy', {
			chainid: 31337,
			registry: '0xa5409ec958c83c3f309868babaca7c86dcb077c1',
		});
	});

task('deploy-testing', 'Deploy Rarity Society contracts to Ropsten')
  .setAction(async (args, { run }) => {
		await run('deploy', {
			chainid: 3,
			registry: '0xf57b2c51ded3a29e6891aba85459d600256cf317',
		});
	});

task('deploy-prod', 'Deploy Rarity Society contracts to Ethereum Mainnet')
  .setAction(async (args, { run }) => {
		await run('deploy', {
			chainid: 1,
			registry: '0xa5409ec958c83c3f309868babaca7c86dcb077c1',
		});
	});

task("deploy", "Deploys Rarity Society contracts")
  .addParam("chainid", "expected network chain ID", undefined, types.int)
  .addParam(
    "registry",
    "OpenSea proxy registry address",
    undefined,
    types.string
  )
	.addOptionalParam(
		"minter",
		"Rarity Society token minter",
		undefined,
		types.string
	)
	.addOptionalParam(
		"vetoer",
		"Rarity Society DAO veto address",
		undefined,
		types.string
	)
  .addOptionalParam(
    "timelockDelay",
    "timelock delay (seconds)",
    60 * 60 * 24 * 2,
    types.int
  )
  .addOptionalParam(
    "votingPeriod",
    "proposal voting period (# of blocks)",
    32000,
    types.int
  )
  .addOptionalParam(
    "votingDelay",
    "proposal voting delay (# of blocks)",
    13000,
    types.int
  )
  .addOptionalParam(
    "proposalThreshold",
    "proposal threshold (# of NFTs)",
    1,
    types.int
  )
  .addOptionalParam(
    "quorumVotesBPS",
    "proposal quorum votes (basis points)",
    1000,
    types.int
  )
  .setAction(async (args, { ethers }) => {
    const gasPrice = await ethers.provider.getGasPrice();

    const network = await ethers.provider.getNetwork();
    if (network.chainId != args.chainid) {
      console.log(
        `invalid chain ID, expected: ${args.chainid} got: ${network.chainId}`
      );
      return;
    }

    console.log(
      `Deploying Rarity Society contracts to chain ${network.chainId}`
    );

    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${deployer.address}`);
    console.log(
      `Deployer balance: ${ethers.utils.formatEther(
        await deployer.getBalance()
      )} ETH`
    );
    const nonce = await deployer.getTransactionCount();

    const deployContract = async function (
      contract: string,
      args: (string | number)[]
    ): Promise<string> {
      console.log(`\nDeploying contract ${contract}:`);

      const expectedNonce = nonce + Contract[contract as keyof typeof Contract];
      const gotNonce = await deployer.getTransactionCount();
      if ((await deployer.getTransactionCount()) != expectedNonce) {
        throw new Error(
          `Unexpected transaction nonce, got: ${gotNonce} expected: ${expectedNonce}`
        );
      }
      const contractFactory = await ethers.getContractFactory(contract);

      const gas = await contractFactory.signer.estimateGas(
        contractFactory.getDeployTransaction(...args, { gasPrice })
      );
      const cost = ethers.utils.formatUnits(gas.mul(gasPrice), "ether");
      console.log(`Estimated deployment cost for ${contract}: ${cost}ETH`);

      const address = (await contractFactory.deploy(...args)).address;
      console.log(`Contract ${contract} deployed to ${address}`);
      return address;
    };

    const expectedRaritySocietyDAOProxyAddress =
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.RaritySocietyDAOProxy,
      });

    // 1. Deploy RaritySocietyToken:
    const raritySocietyToken = await deployContract(
      Contract[Contract.RaritySocietyToken],
      [args.minter || deployer.address, args.registry]
    );

    // 2. Deploy Timelock
    const timelock = await deployContract(Contract[Contract.Timelock], [
      ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + Contract.RaritySocietyDAOProxy,
      }),
      args.timelockDelay,
    ]);

    // 3. Deploy Rarity Society DAO Impl
    const raritySocietyDAOImpl = await deployContract(
      Contract[Contract.RaritySocietyDAOImpl],
      []
    );

    // 4. Deploy Rarity Society DAO Proxy
		const raritySocietyDAOProxy = await deployContract(
			Contract[Contract.RaritySocietyDAOProxy],
			[
				timelock,
				raritySocietyToken,
				args.vetoer || deployer.address,
				timelock,
				raritySocietyDAOImpl,
				args.votingPeriod,
				args.votingDelay,
				args.proposalThreshold,
				args.quorumVotesBPS
			]
		)
  });
