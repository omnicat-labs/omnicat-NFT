// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import { OmniNFT } from "../src/OmniNFT.sol";
import { IOmniCat } from "../src/interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType, NftInfo } from "../src/utils/OmniNftStructs.sol";
import { ParamSetChains } from "./ParamSetChains.sol";

contract ConfigureOmniNFT is ParamSetChains {

    constructor() ParamSetChains() {}

    function run() external {
        uint16 CURRENT_CHAIN_ID = uint16(vm.envUint("CURRENT_CHAIN_ID"));
        OmniNFT omniNFT = OmniNFT(payable(chainIdToContract[CURRENT_CHAIN_ID]));

        uint omniBridgeFee = vm.envUint("OMNI_BRIDGE_FEE");
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        for(uint16 i=0; i<chainIds.length;i++){
            if(chainIds[i] == CURRENT_CHAIN_ID){
                continue;
            }
            omniNFT.setTrustedRemoteAddress(chainIds[i], abi.encodePacked(address(chainIdToContract[chainIds[i]])) );
            omniNFT.setMinDstGas(chainIds[i], omniNFT.FUNCTION_TYPE_SEND(), 1e5);
            omniNFT.setDstChainIdToBatchLimit(chainIds[i], 10);
            omniNFT.setOmniBridgeFee(omniBridgeFee);
        }

        vm.stopBroadcast();
    }
}
