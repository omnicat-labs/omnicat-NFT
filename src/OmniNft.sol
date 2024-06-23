// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType, NftInfo } from "./utils/OmniNftStructs.sol";
import { OmniNFTBase } from "./OmniNftBase.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OmniNFT is
    OmniNFTBase
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    // ===================== Constants ===================== //
    BaseChainInfo public BASE_CHAIN_INFO;

    // AccessControl roles.

    // External contracts.

    // ===================== Storage ===================== //
    uint256 omniBridgeFee;

    // ===================== Constructor ===================== //
    constructor(
        BaseChainInfo memory _baseChainInfo,
        IOmniCat _omnicat,
        NftInfo memory _nftInfo,
        uint _minGasToTransfer,
        address _lzEndpoint,
        uint _omniBridgeFee
    )
        OmniNFTBase(_omnicat, _nftInfo, _minGasToTransfer, _lzEndpoint)
    {
        BASE_CHAIN_INFO = _baseChainInfo;
        omniBridgeFee = _omniBridgeFee;
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //

    function setOmniBridgeFee(uint256 _omniBridgeFee) public onlyOwner() {
        omniBridgeFee = _omniBridgeFee;
    }


    // ===================== Public Functions ===================== //

    function estimateBurnFees(uint256 tokenId) external view returns (uint256) {
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });

        (uint256 nftBridgeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);

        return omniBridgeFee + nftBridgeFee;
    }

    function burn(uint256 tokenId) external payable nonReentrant() whenNotPaused() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });

        (uint256 nftBridgeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);
        interchainTransactionFees += omniBridgeFee;

        require(msg.value >= (omniBridgeFee + nftBridgeFee), "not enough to cover fees");

        uint256 remainder = msg.value - (nftBridgeFee + omniBridgeFee);
        if(remainder > 0){
            (bool success, ) = payable(msg.sender).call{value:remainder}("");
            require(success, "failed to refund");
        }

        _lzSend(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            payload,
            payable(msg.sender),
            address(0),
            lzCallParams.adapterParams,
            nftBridgeFee
        );
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal virtual override {
        bytes memory payloadWithoutMessage;
        assembly {
            payloadWithoutMessage := add(_payload,1)
        }
        // decode and load the toAddress
        uint8 value = uint8(_payload[0]);
        MessageType messageType = MessageType(value);
        if(messageType != MessageType.TRANSFER){
            return;
        }

        (bytes memory toAddressBytes, uint[] memory tokenIds) = abi.decode(payloadWithoutMessage, (bytes, uint[]));

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        uint nextIndex = _creditTill(_srcChainId, toAddress, 0, tokenIds);
        if (nextIndex < tokenIds.length) {
            // not enough gas to complete transfers, store to be cleared in another tx
            bytes32 hashedPayload = keccak256(_payload);
            storedCredits[hashedPayload] = StoredCredit(_srcChainId, toAddress, nextIndex, true);
            emit CreditStored(hashedPayload, _payload);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, tokenIds);
    }




    // ===================== interval Functions ===================== //
}
