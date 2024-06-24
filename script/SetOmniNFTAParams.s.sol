// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import { OmniNFTA } from "../src/OmniNFTA.sol";
import { IOmniCat } from "../src/interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType, NftInfo } from "../src/utils/OmniNftStructs.sol";
import { ParamSetChains } from "./ParamSetChains.sol";

contract ConfigureOmniNFTA is ParamSetChains {

    constructor() ParamSetChains() {}

    function run() external {
        uint16 CURRENT_CHAIN_ID = uint16(vm.envUint("CURRENT_CHAIN_ID"));
        OmniNFTA omniNFTA = OmniNFTA(payable(chainIdToContract[CURRENT_CHAIN_ID]));

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        for(uint16 i=0; i<chainIds.length;i++){
            if(chainIds[i] == CURRENT_CHAIN_ID || chainIdToContract[chainIds[i]] == address(0)){
                continue;
            }
            omniNFTA.setTrustedRemoteAddress(chainIds[i], abi.encodePacked(address(chainIdToContract[chainIds[i]])) );
            omniNFTA.setMinDstGas(chainIds[i], omniNFTA.FUNCTION_TYPE_SEND(), 1e5);
            omniNFTA.setDstChainIdToBatchLimit(chainIds[i], 10);
        }

        vm.stopBroadcast();
    }
}
