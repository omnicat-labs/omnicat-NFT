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
    uint256 public MAX_NFTS_IN_MINT = 10;

    // ===================== Storage ===================== //
    uint256 public omniBridgeFee;

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

    // ===================== Admin-Only External Functions (Hot) ===================== //

    function setOmniBridgeFee(uint256 _omniBridgeFee) public onlyOwner() {
        omniBridgeFee = _omniBridgeFee;
    }

    // ===================== Public Functions ===================== //

    function estimateMintFees(
        uint256 mintNumber,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(msg.sender, 1);
        payload = abi.encodePacked(MessageType.MINT, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: _refundAddress,
            zroPaymentAddress: _zroPaymentAddress,
            adapterParams: _adapterParams
        });
        bytes32 baseChainAddressBytes = bytes32(uint256(uint160(BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS)));

        (uint256 bridgeFee, ) = omnicat.estimateSendAndCallFee(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            baseChainAddressBytes,
            mintNumber*MINT_COST,
            payload,
            uint64(dstChainIdToTransferGas[BASE_CHAIN_INFO.BASE_CHAIN_ID] * mintNumber),
            false,
            lzCallParams.adapterParams
        );
        return bridgeFee;
    }

    function mint(
        uint256 mintNumber,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external payable nonReentrant() whenNotPaused() {
        require(mintNumber <= MAX_NFTS_IN_MINT, "Too many in one transaction");

        bytes memory payload = abi.encode(msg.sender, mintNumber);
        payload = abi.encodePacked(MessageType.MINT, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: _refundAddress,
            zroPaymentAddress: _zroPaymentAddress,
            adapterParams: _adapterParams
        });

        bytes32 baseChainAddressBytes = bytes32(uint256(uint160(BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS)));

        _checkGasLimit(BASE_CHAIN_INFO.BASE_CHAIN_ID, FUNCTION_TYPE_SEND, _adapterParams, dstChainIdToTransferGas[BASE_CHAIN_INFO.BASE_CHAIN_ID] * mintNumber);

        (uint256 bridgeFee, ) = omnicat.estimateSendAndCallFee(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            baseChainAddressBytes,
            mintNumber*MINT_COST,
            payload,
            uint64(dstChainIdToTransferGas[BASE_CHAIN_INFO.BASE_CHAIN_ID] * mintNumber),
            false,
            lzCallParams.adapterParams
        );

        require(msg.value >= (bridgeFee), "not enough fees");

        uint256 remainder = msg.value - (bridgeFee);
        if(remainder > 0){
            bool success = payable(msg.sender).send(remainder);
            require(success, "failed to refund");
        }

        omnicat.sendAndCall{value: bridgeFee}(msg.sender, BASE_CHAIN_INFO.BASE_CHAIN_ID, baseChainAddressBytes, mintNumber*MINT_COST, payload, uint64(dstChainIdToTransferGas[BASE_CHAIN_INFO.BASE_CHAIN_ID] * mintNumber), lzCallParams);
    }

    function estimateBurnFees(
        uint256 tokenId,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: _refundAddress,
            zroPaymentAddress: _zroPaymentAddress,
            adapterParams: _adapterParams
        });

        (uint256 nftBridgeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);

        return omniBridgeFee + nftBridgeFee;
    }

    function burn(
        uint256 tokenId,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external payable nonReentrant() whenNotPaused() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: _refundAddress,
            zroPaymentAddress: _zroPaymentAddress,
            adapterParams: _adapterParams
        });

        _checkGasLimit(BASE_CHAIN_INFO.BASE_CHAIN_ID, FUNCTION_TYPE_SEND, _adapterParams, dstChainIdToTransferGas[BASE_CHAIN_INFO.BASE_CHAIN_ID]);

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
            bytes32 hashedPayload = keccak256(payloadWithoutMessage);
            storedCredits[hashedPayload] = StoredCredit(_srcChainId, toAddress, nextIndex, true);
            emit CreditStored(hashedPayload, payloadWithoutMessage);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, tokenIds);
    }
}
