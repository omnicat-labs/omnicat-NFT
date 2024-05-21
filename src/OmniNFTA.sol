// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ONFT721A } from "@LayerZero-Examples/contracts/token/onft721/ONFT721A.sol";
import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { OmniNFTBase } from "./OmniNftBase.sol";

import { AccessControlAdminProtection } from "./utils/AccessControlAdminProtection.sol";

contract OmniNFTA is
    OmniNFTBase
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    // ===================== Constants ===================== //
    uint256 public totalTokens = 100;

    // AccessControl roles.

    // External contracts.

    // ===================== Storage ===================== //
    uint256 public nextTokenIdMint = 0;

    // ===================== Constructor ===================== //
    constructor(
        uint16 _chain_id,
        IOmniCat _omnicat,
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint,
        string calldata _baseURI
    )
        OmniNFTBase(_chain_id, _omnicat, _name, _symbol, _minGasToTransfer, _lzEndpoint, _baseURI)
    {}

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    // TODO:- This is not an interchain transaction. mints a token for the user.
    function mint() external override nonReentrant() {
        omnicat.safeTransferFrom(msg.sender, address(this), MINT_COST);
        _safeMint(++nextTokenIdMint, msg.sender);
    }

    // TODO:- This is not an interchain transaction. burns a token from the user, and credits omni to the user.
    function burn(uint156 tokenId) external override nonReentrant() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        omnicat.transfer(msg.sender, MINT_COST);
    }

    // TODO:- override this to accept burns and mints and transactions.
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        // decode and load the toAddress
        uint8 value = uint8(_payload[0]);
        MessageType messageType = MessageType(value);
        if(messageType == MessageType.TRANSFER){
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
        else if(messageType == MessageType.BURN){
            (address userAddress, uint256 tokenId) = abi.decode(_payload[1:], (address, uint256));
            if(_ownerOf(tokenId)!=address(this)){
                // TODO:- see if this is ever possible
                return;
            }
            _burn(tokenId);
            LzCallParams memory lzCallParams = LzCallParams({
                refundAddress: payable(address(this)),
                zroPaymentAddress: address(0),
                adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
            });
            (uint256 nativeFee, ) = omnicat.estimateSendFee(
                BASE_CHAIN_INFO.BASE_CHAIN_ID,
                userAddress,
                MINT_COST,
                false,
                lzCallParams.adapterParams
            );
            if(address(this).balance < nativeFee){
                // TODO:- make it such that we can call a function to send the funds to the right address.
            }
            omnicat.sendFrom{value: nativeFee}(address(this), _srcChainId, userAddress, MINT_COST, lzCallParams);
        }
        else if(messageType == MessageType.MINT){
            (address userAddress) = abi.decode(_payload[1:], (address));
            _safeMint(++nextTokenIdMint, address(this));
            LzCallParams memory lzCallParams = LzCallParams({
                refundAddress: payable(address(this)),
                zroPaymentAddress: address(0),
                adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
            });
            (uint256 nativeFee, ) = estimateSendFee(_srcChainId, userAddress, nextTokenIdMint, false, lzCallParams.adapterParams);
            if(address(this).balance < nativeFee){
                // TODO:- make it such that we can call a function to send the funds to the right address.
            }
            sendFrom{value: nativeFee}(address(this), _srcChainId, userAddress, nextTokenIdMint, address(this), address(0), lzCallParams.adapterParams);
        }
    }


    // ===================== interval Functions ===================== //
}
