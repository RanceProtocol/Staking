import { expect } from "chai";
import { ethers } from "hardhat"
import { Signer, Contract, BigNumber as _BigNumber, ContractFactory } from "ethers";
import { MasterCRPWallet } from "../src/types/MasterCRPWallet";

let Wallet: ContractFactory, wallet: MasterCRPWallet, PrederB: Signer, crp: Contract, CRP: ContractFactory;

describe("MasterCRP Wallet Tests", () => {
  beforeEach( async () => {
    CRP = await ethers.getContractFactory("CROPredict");
    crp = await CRP.deploy();
    Wallet = await ethers.getContractFactory("MasterCRPWallet");
    wallet = (await Wallet.deploy(crp.address)) as MasterCRPWallet;
    crp.transfer(wallet.address, 1000000);

    const signers = await ethers.getSigners();
    [, PrederB] = signers;
  })

  it("should allow Owner send Pred", async () => {
    await expect(async () => wallet.safeCRPTransfer(await PrederB.getAddress(), 10000))
      .to.changeTokenBalances(
        crp, [wallet, PrederB], [-10000, 10000]
    )
  })

  it("should allow onlyOwner send Pred", async () => {
    await expect(wallet.safeCRPTransfer(
      await PrederB.getAddress(), 10000, {from: PrederB.getAddress()}
    )).to.be.reverted;
  })

  it("should allow Owner set MasterPred", async () => {
    await wallet.setMasterCRP(await PrederB.getAddress())
    const master = await wallet.MasterCRP()
    expect(master).to.equal(await PrederB.getAddress())
  })

  it("should allow only Owner set MasterPred", async () => {
    await expect(wallet.setMasterCRP(
      await PrederB.getAddress(), {from: PrederB.getAddress()}
    )).to.be.reverted
  })
})
