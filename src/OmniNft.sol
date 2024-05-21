// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ONFT721 } from "@LayerZero-Examples/contracts/token/onft721/ONFT721.sol";
import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { BaseChainInfo, MessageType } from "./utils/OmniNftStructs.sol";
import { OmniNFTBase } from "./OmniNftBase.sol";

import { AccessControlAdminProtection } from "./utils/AccessControlAdminProtection.sol";

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
        BaseChainInfo _baseChainInfo,
        IOmniCat _omnicat,
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint,
        string calldata _baseURI
    )
        OmniNFTBase(_chain_id, _omnicat, _name, _symbol, _minGasToTransfer, _lzEndpoint, _baseURI)
    {
        setTrustedRemoteAddress(_baseChainInfo.BASE_CHAIN_ID, _baseChainInfo.BASE_CHAIN_ADDRESS);
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    // TODO:- this is only an interchain function, that will call mint on OmniNFTA
    function mint() external payable nonReentrant() {
        bytes memory payload = abi.encode(msg.sender);
        payload = abi.encodePacked(MessageType.MINT, payload);

        LzCallParams memory lzCallParams = LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });

        (uint256 nativeFee, ) = omnicat.estimateSendAndCallFee(
            BASE_CHAIN_INFO.BASE_CHAIN_ID,
            BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS,
            MINT_COST,
            payload,
            dstGasReserve,
            false,
            lzCallParams.adapterParams
        );
        require(msg.value >= nativeFee, "not enough fees");
        omnicat.sendAndCall{value: nativeFee}(msg.sender, BASE_CHAIN_INFO.BASE_CHAIN_ID, BASE_CHAIN_INFO.BASE_CHAIN_ADDRESS, MINT_COST, payload, dstGasReserve, lzCallParams);
    }

    // TODO:- This is only an interchain transaction. burns a token from the user, and credits omni to the user.
    function burn(uint256 tokenId) external payable nonReentrant() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        bytes memory payload = abi.encode(msg.sender, tokenId);
        payload = abi.encodePacked(MessageType.BURN, payload);

        LzCallParams memory lzCallParams = LzCallParams({
            refundAddress: payable(msg.sender),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });

        (uint256 omniSendFee, ) = omnicat.estimateSendFee(BASE_CHAIN_INFO.BASE_CHAIN_ID, msg.sender, MINT_COST, false, adapterParams);
        (uint256 nativeFee, ) = lzEndpoint.estimateFees(BASE_CHAIN_INFO.BASE_CHAIN_ID, address(this), payload, false, lzCallParams.adapterParams);

        require(msg.value >= omniSendFee + nativeFee, "not enough to cover fees");
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
        // decode and load the toAddress
        uint8 value = uint8(_payload[0]);
        MessageType messageType = MessageType(value);
        if(messageType != MessageType.TRANSFER){
            // TODO:- see if you should revert this or just return?
            return;
        }

        (bytes memory toAddressBytes, uint[] memory tokenIds) = abi.decode(_payload[1:], (bytes, uint[]));

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
