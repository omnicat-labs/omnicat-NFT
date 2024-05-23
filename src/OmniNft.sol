// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { BaseChainInfo, MessageType } from "./utils/OmniNftStructs.sol";
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

    // AccessControl roles.

    // External contracts.

    // ===================== Storage ===================== //

    // ===================== Constructor ===================== //
    constructor(
        BaseChainInfo memory _baseChainInfo,
        IOmniCat _omnicat,
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint,
        string memory _baseURI
    )
        OmniNFTBase(_baseChainInfo, _omnicat, _name, _symbol, _minGasToTransfer, _lzEndpoint, _baseURI)
    {
        // setTrustedRemoteAddress(_baseChainInfo.BASE_CHAIN_ID, abi.encodePacked(_baseChainInfo.BASE_CHAIN_ADDRESS));
        // setMinDstGas(_baseChainInfo.BASE_CHAIN_ID, FUNCTION_TYPE_SEND, _minGasToTransfer);
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    function estimateMintFees() external view returns (uint256) {
        bytes memory payload = abi.encode(msg.sender);
        payload = abi.encodePacked(MessageType.MINT, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(2*dstGasReserve))
        });
        bytes32 baseChainAddressBytes = bytes32(uint256(uint160(BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS)));

        (uint256 nativeFee, ) = estimateSendFee(BASE_CHAIN_INFO.BASE_CHAIN_ID, abi.encodePacked(msg.sender), 1, false, lzCallParams.adapterParams);
        (uint256 omniFee, ) = omnicat.estimateSendAndCallFee(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            baseChainAddressBytes,
            MINT_COST,
            payload,
            dstGasReserve,
            false,
            lzCallParams.adapterParams
        );
        return nativeFee + omniFee;
    }

    // TODO:- this is only an interchain function, that will call mint on OmniNFTA
    function mint(uint256 ) external payable override nonReentrant() {
        bytes memory payload = abi.encode(msg.sender);
        payload = abi.encodePacked(MessageType.MINT, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(2*dstGasReserve))
        });
        bytes32 baseChainAddressBytes = bytes32(uint256(uint160(BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS)));

        (uint256 nativeFee, ) = estimateSendFee(BASE_CHAIN_INFO.BASE_CHAIN_ID, abi.encodePacked(msg.sender), 1, false, lzCallParams.adapterParams);
        (uint256 omniFee, ) = omnicat.estimateSendAndCallFee(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            baseChainAddressBytes,
            MINT_COST,
            payload,
            dstGasReserve,
            false,
            lzCallParams.adapterParams
        );
        require(msg.value >= (nativeFee + omniFee), "not enough fees");
        omnicat.sendAndCall{value: omniFee}(msg.sender, BASE_CHAIN_INFO.BASE_CHAIN_ID, baseChainAddressBytes, MINT_COST, payload, dstGasReserve, lzCallParams);
    }

    function estimateBurnFees(uint256 tokenId) external view returns (uint256) {
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });
        bytes32 senderBytes = bytes32(uint256(uint160(msg.sender)));

        (uint256 omniSendFee, ) = omnicat.estimateSendFee(BASE_CHAIN_INFO.BASE_CHAIN_ID, senderBytes, MINT_COST, false, lzCallParams.adapterParams);
        (uint256 nativeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);

        return omniSendFee + nativeFee;
    }

    function burn(uint256 tokenId) external payable override nonReentrant() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });
        bytes32 senderBytes = bytes32(uint256(uint160(msg.sender)));

        (uint256 omniSendFee, ) = omnicat.estimateSendFee(BASE_CHAIN_INFO.BASE_CHAIN_ID, senderBytes, MINT_COST, false, lzCallParams.adapterParams);
        (uint256 nativeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);

        require(msg.value >= (omniSendFee + nativeFee), "not enough to cover fees");
        _lzSend(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            payload,
            payable(msg.sender),
            address(0),
            lzCallParams.adapterParams,
            nativeFee
        );
    }

    // TODO:- override this to accept only transactions.
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
            // TODO:- see if you should revert this or just return?
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
