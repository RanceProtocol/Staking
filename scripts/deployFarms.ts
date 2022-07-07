import { ethers, upgrades } from "hardhat";
const { WALLET, RANCE, MUSD } = process.env;
import { MasterRANCEWallet } from "../src/types/MasterRANCEWallet";
import {MasterMUSD} from "../src/types/MasterMUSD";

async function main() {
  // We get the contract to deploy
  const RANCEPerBlock = 10000000000;
  const MUSDPerBlock = 10000000000;

  const wallet: MasterRANCEWallet = (await ethers.getContractAt("MasterRANCEWallet", WALLET!)) as MasterRANCEWallet;
  const Farm1 = await ethers.getContractFactory("MasterRANCE");
  const Farm2 = await ethers.getContractFactory("MasterMUSD");
  const farm1 = await upgrades.deployProxy(Farm1, [RANCE, RANCEPerBlock, 0, wallet.address], {kind: "uups"});
  const farm2 = await upgrades.deployProxy(Farm2, [MUSD, MUSDPerBlock, 0, wallet.address], {kind: "uups"}) as MasterMUSD;
  await wallet.addMasterRANCE(farm1.address);
  await wallet.addMasterRANCE(farm2.address);

  // add RANCE pool to farm2
  await farm2.set(0, 0, false);
  await farm2.add(200, RANCE || "", false);

  console.log(`Farm deployed to:${farm1.address}, wallet deployed to:${wallet.address}`,
  `implementation deployed to:${await ethers.provider.getStorageAt(
    farm1.address,
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    )}`);

  console.log(`Farm deployed to:${farm2.address}, wallet deployed to:${wallet.address}`,
  `implementation deployed to:${await ethers.provider.getStorageAt(
    farm2.address,
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    )}`);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
