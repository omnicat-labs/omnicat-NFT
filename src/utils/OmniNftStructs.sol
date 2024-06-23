// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

struct BaseChainInfo {
    uint16 BASE_CHAIN_ID;
    address BASE_CHAIN_ADDRESS;
}

struct NftInfo {
    string baseURI;
    uint256 MINT_COST;
    uint256 MAX_MINTS_PER_ACCOUNT;
    uint256 COLLECTION_SIZE;
    string name;
    string symbol;
}

enum MessageType {
    BURN,
    TRANSFER
}