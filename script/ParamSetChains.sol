// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import { OmniNFTA } from "../src/OmniNFTA.sol";
import { IOmniCat } from "../src/interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType, NftInfo } from "../src/utils/OmniNftStructs.sol";

contract ParamSetChains is Script {

    uint16 public constant ETHEREUM_CHAIN_ID = uint16(101);
    uint16 public constant POLYGON_CHAIN_ID = uint16(109);
    uint16 public constant BNB_CHAIN_ID = uint16(102);
    uint16 public constant ARBITRUM_CHAIN_ID = uint16(110);
    uint16 public constant BASE_CHAIN_ID = uint16(184);
    uint16 public constant CANTO_CHAIN_ID = uint16(159);
    uint16 public constant BLAST_CHAIN_ID = uint16(243);

    uint16[] public chainIds = [
        ETHEREUM_CHAIN_ID,
        POLYGON_CHAIN_ID,
        BNB_CHAIN_ID,
        ARBITRUM_CHAIN_ID,
        BASE_CHAIN_ID,
        CANTO_CHAIN_ID,
        BLAST_CHAIN_ID
    ];

    mapping (uint16 chainId => address contractAddress) public chainIdToContract;

    constructor(){
        address ETHEREUM_ADDRESS = vm.envAddress("ETHEREUM_ADDRESS");
        address POLYGON_ADDRESS = vm.envAddress("POLYGON_ADDRESS");
        address BNB_ADDRESS = vm.envAddress("BNB_ADDRESS");
        address ARBITRUM_ADDRESS = vm.envAddress("ARBITRUM_ADDRESS");
        address BASE_ADDRESS = vm.envAddress("BASE_ADDRESS");
        address CANTO_ADDRESS = vm.envAddress("CANTO_ADDRESS");
        address BLAST_ADDRESS = vm.envAddress("BLAST_ADDRESS");

        chainIdToContract[ETHEREUM_CHAIN_ID] = ETHEREUM_ADDRESS;
        chainIdToContract[POLYGON_CHAIN_ID] = POLYGON_ADDRESS;
        chainIdToContract[BNB_CHAIN_ID] = BNB_ADDRESS;
        chainIdToContract[ARBITRUM_CHAIN_ID] = ARBITRUM_ADDRESS;
        chainIdToContract[BASE_CHAIN_ID] = BASE_ADDRESS;
        chainIdToContract[CANTO_CHAIN_ID] = CANTO_ADDRESS;
        chainIdToContract[BLAST_CHAIN_ID] = BLAST_ADDRESS;
    }
}
