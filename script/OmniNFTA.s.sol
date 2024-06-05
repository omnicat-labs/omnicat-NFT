// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import { OmniNFTA } from "../src/OmniNFTA.sol";
import { ILayerZeroEndpoint } from "@LayerZero/contracts/interfaces/ILayerZeroEndpoint.sol";
import { IOmniCat } from "../src/interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType, NftInfo } from "../src/utils/OmniNftStructs.sol";

contract DeployPredictionPool is Script {

    function run() external {

        string memory BASE_URI = vm.envString("BASE_URI");
        string memory NAME = vm.envString("NAME");
        string memory SYMBOL = vm.envString("SYMBOL");
        uint256 COLLECTION_SIZE = vm.envUint("COLLECTION_SIZE");
        uint256 MAX_TOKENS_PER_MINT = vm.envUint("MAX_TOKENS_PER_MINT");
        uint256 MAX_MINTS_PER_ACCOUNT = vm.envUint("MAX_MINTS_PER_ACCOUNT");
        uint256 MINT_COST = vm.envUint("MINT_COST");
        ILayerZeroEndpoint layerZeroEndpoint = ILayerZeroEndpoint(vm.envAddress("LAYER_ZERO_ENDPOINT"));
        IOmniCat omnicat = IOmniCat(vm.envAddress("OMNICAT_ADDRESS"));


        // uint256 FEE_PERCENTAGE = 10;

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OmniNFTA omniNFTA = new OmniNFTA(
            omnicat,
            NftInfo({
                baseURI: BASE_URI,
                MINT_COST: MINT_COST,
                MAX_TOKENS_PER_MINT: MAX_TOKENS_PER_MINT,
                MAX_MINTS_PER_ACCOUNT: MAX_MINTS_PER_ACCOUNT,
                COLLECTION_SIZE: COLLECTION_SIZE,
                name: NAME,
                symbol: SYMBOL
            }),
            1e4,
            address(layerZeroEndpoint)
        );

        // THIS NEEDS TO BE CALLED EVENTUALLY
        // omniNFTA.setTrustedRemoteAddress(_remoteChainId, _remoteAddress);



        payable(address(omniNFTA)).transfer(0.02 ether);

        vm.stopBroadcast();
    }
}
