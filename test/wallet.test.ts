import { expect } from "chai";
import { ethers } from "hardhat"
import { Signer, Contract, BigNumber as _BigNumber, ContractFactory } from "ethers";
import { MasterRANCEWallet } from "../src/types/MasterRANCEWallet";

let Wallet: ContractFactory, wallet: MasterRANCEWallet, PrederB: Signer, rance: Contract, RANCE: ContractFactory;

describe("MasterCRP Wallet Tests", () => {
  beforeEach( async () => {
    RANCE = await ethers.getContractFactory("RANCE");
    rance = await RANCE.deploy();
    Wallet = await ethers.getContractFactory("MasterRANCEWallet");
    wallet = (await Wallet.deploy(rance.address)) as MasterRANCEWallet;
    rance.transfer(wallet.address, 1000000);

    const signers = await ethers.getSigners();
    [, PrederB] = signers;
  })

  it("should allow Owner send RANCE", async () => {
    await expect(async () => wallet.safeTokenTransfer(await PrederB.getAddress(), 10000, rance.address))
      .to.changeTokenBalances(
        rance, [wallet, PrederB], [-10000, 10000]
    )
  })

  it("should allow onlyOwner send RANCE", async () => {
    await expect(wallet.safeRANCETransfer(
      await PrederB.getAddress(), 10000, {from: PrederB.getAddress()}
    )).to.be.reverted;
  })

  it("should allow Owner send token", async () => {
    await expect(async () => wallet.safeTokenTransfer(await PrederB.getAddress(), 10000, rance.address))
      .to.changeTokenBalances(
        rance, [wallet, PrederB], [-10000, 10000]
    )
  })

  it("should allow onlyOwner send token", async () => {
    await expect(wallet.safeRANCETransfer(
      await PrederB.getAddress(), 10000, {from: PrederB.getAddress()}
    )).to.be.reverted;
  })

  it("should allow Owner set MasterPred", async () => {
    await wallet.addMasterRANCE(await PrederB.getAddress())
    const isMaster = await wallet.masters(await PrederB.getAddress());
    expect(isMaster).to.equal(true);
  })

  it("should allow only Owner set MasterPred", async () => {
    await expect(wallet.addMasterRANCE(
      await PrederB.getAddress(), {from: PrederB.getAddress()}
    )).to.be.reverted
  })
})
