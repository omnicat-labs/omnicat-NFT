// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

struct BaseChainInfo {
    uint16 BASE_CHAIN_ID;
    address BASE_CHAIN_ADDRESS;
}

enum MessageType {
    MINT,
    BURN,
    TRANSFER
}