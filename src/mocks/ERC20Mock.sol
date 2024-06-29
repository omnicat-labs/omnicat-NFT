// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

// @dev mock OFTV2 demonstrating how to inherit OFTV2
contract ERC20Mock is MockERC20 {
    constructor(uint256 _initialSupply) {
        _mint(msg.sender, _initialSupply);
    }
}
