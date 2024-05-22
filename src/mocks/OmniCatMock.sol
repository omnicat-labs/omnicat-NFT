// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { OFTV2 } from "@LayerZero-Examples/contracts/token/oft/v2/OFTV2.sol";
import { IOmniCat } from "../interfaces/IOmniCat.sol";

// @dev mock OFTV2 demonstrating how to inherit OFTV2
contract OmniCatMock is OFTV2, IOmniCat {
    constructor(address _layerZeroEndpoint, uint _initialSupply, uint8 _sharedDecimals) OFTV2("ExampleOFT", "OFT", _sharedDecimals, _layerZeroEndpoint) {
        _mint(_msgSender(), _initialSupply);
    }
}
