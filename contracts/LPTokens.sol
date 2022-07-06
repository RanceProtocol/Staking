// SPDX-License-Identifier: Unlicensed
//Just for tests
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken1 is ERC20("BUSDCRP","BUSDCRP"){
    constructor(){
        _mint(msg.sender, 10000000);
    }
}

contract LPToken2 is ERC20("BNBCRP","BNBCRP"){
    constructor(){
        _mint(msg.sender, 10000000);
    }
}