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

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        omniNFT.setDstBurnNftGas(DST_CHAIN_ID_TO_TRANSFER_GAS);
        for(uint16 i=0; i<chainIds.length;i++){
            if(chainIds[i] == CURRENT_CHAIN_ID || chainIdToContract[chainIds[i]] == address(0)){
                continue;
            }
            omniNFT.setTrustedRemoteAddress(chainIds[i], abi.encodePacked(address(chainIdToContract[chainIds[i]])) );
            omniNFT.setMinDstGas(chainIds[i], uint16(0), 150000);
            omniNFT.setMinDstGas(chainIds[i], uint16(1), 150000);
            omniNFT.setDstChainIdToBatchLimit(chainIds[i], 10);
            omniNFT.setDstChainIdToTransferGas(chainIds[i], DST_CHAIN_ID_TO_TRANSFER_GAS);
            uint256 minDstGasLookupOmnicat;
            if(chainIds[i] == ARBITRUM_CHAIN_ID){
                minDstGasLookupOmnicat = ARBITRUM_OMNI_MIN_DST_GAS;
            }
            else{
                minDstGasLookupOmnicat = DEFAULT_OMNI_MIN_DST_GAS;
            }
            omniNFT.setMinDstGasLookupOmnicat(chainIds[i], minDstGasLookupOmnicat);
        }

        vm.stopBroadcast();
    }
}
