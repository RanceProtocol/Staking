// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.2;

import "./interfaces/IBEP20.sol";
import './utils/SafeBEP20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract MasterRANCEWallet is Ownable {
    using SafeBEP20 for IBEP20;
    // The RANCE TOKEN!
    IBEP20 public RANCE;
    address public MasterRANCE;

    constructor(
        IBEP20 _RANCE
    ) {
        RANCE = _RANCE;
    }

    function setMasterRANCE(address _MasterRANCE) onlyOwner external{
        MasterRANCE = _MasterRANCE;
    }

    // Safe RANCE transfer function, just in case if rounding error causes pool to not have enough RANCEs.
    function safeRANCETransfer(address _to, uint256 _amount) public returns(uint) {
        require(msg.sender == MasterRANCE || msg.sender == owner(), "Wallet: Only MasterRANCE and Owner can transfer");
        uint256 RANCEBal = RANCE.balanceOf(address(this));
        if (_amount > RANCEBal) {
            RANCE.safeTransfer(_to, RANCEBal);
            return RANCEBal;
        } else {
            RANCE.safeTransfer(_to, _amount);
            return _amount;
        }
    }
}