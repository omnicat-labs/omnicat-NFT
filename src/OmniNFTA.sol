// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { OmniNFTBase } from "./OmniNftBase.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { IOFTReceiverV2 } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/IOFTReceiverV2.sol";
import { BaseChainInfo, MessageType } from "./utils/OmniNftStructs.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OmniNFTA is
    OmniNFTBase,
    IOFTReceiverV2
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    struct NFTRefund {
        address userAddress;
        uint16 chainID;
        uint256[] tokens;
    }

    // ===================== Constants ===================== //
    uint256 public totalTokens = 100;

    // AccessControl roles.

    // External contracts.

    // ===================== Storage ===================== //
    uint256 public nextTokenIdMint = 0;
    mapping (address userAddress => mapping(uint16 chainId => uint256 refundAmount)) public omniUserRefund;
    mapping (bytes32 hashedPayload => NFTRefund userRefund) public NFTUserRefund;

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
    {}

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    // TODO:- This is not an interchain transaction. mints a token for the user.
    function mint(uint256 mintNumber) external override payable nonReentrant() {
        require(mintNumber <= MAX_TOKENS_PER_MINT, "Too many in one transaction");
        require(balanceOf(msg.sender) + mintNumber <= MAX_MINTS_PER_ACCOUNT, "Too many");
        require(nextTokenIdMint + mintNumber <= COLLECTION_SIZE, "collection size exceeded");
        require(msg.value == 0, "do not send funds here");

        omnicat.safeTransferFrom(msg.sender, address(this), mintNumber*MINT_COST);
        for(uint256 i=0;i<mintNumber;){
            _safeMint(msg.sender, ++nextTokenIdMint);
            unchecked {
                i++;
            }
        }
    }

    // TODO:- This is not an interchain transaction. burns a token from the user, and credits omni to the user.
    function burn(uint256 tokenId) external override payable nonReentrant() {
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
        bytes memory payloadWithoutMessage;
        assembly {
            payloadWithoutMessage := add(_payload,1)
        }

        uint8 value = uint8(_payload[0]);
        MessageType messageType = MessageType(value);
        if(messageType == MessageType.TRANSFER){
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
        else if(messageType == MessageType.BURN){
            (address userAddress, uint256 tokenId) = abi.decode(payloadWithoutMessage, (address, uint256));
            if(_ownerOf(tokenId)!=address(this)){
                // TODO:- see if this is ever possible
                return;
            }
            _burn(tokenId);
            ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
                refundAddress: payable(address(this)),
                zroPaymentAddress: address(0),
                adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
            });
            bytes32 userAddressBytes = bytes32(uint256(uint160(userAddress)));
            (uint256 nativeFee, ) = omnicat.estimateSendFee(
                _srcChainId,
                userAddressBytes,
                MINT_COST,
                false,
                lzCallParams.adapterParams
            );
            if(address(this).balance < nativeFee){
                omniUserRefund[userAddress][_srcChainId] += MINT_COST;
                return;
            }
            omnicat.sendFrom{value: nativeFee}(address(this), _srcChainId, userAddressBytes, MINT_COST, lzCallParams);
        }
    }

    // This is called by interchain mints
    function onOFTReceived(uint16 _srcChainId, bytes calldata , uint64 , bytes32 , uint _amount, bytes calldata _payload) external override {
        require(msg.sender == address(omnicat));

        MessageType messageType = MessageType(uint8(_payload[0]));
        if(messageType == MessageType.MINT){
            (address userAddress, uint256 mintNumber) = abi.decode(_payload[1:], (address, uint256));
            if(_amount < mintNumber*MINT_COST){
                // create refund for user
                return;
            }
            uint256[] memory tokens = new uint256[](mintNumber);
            for(uint256 i=0;i<mintNumber;){
                _mint(address(this), ++nextTokenIdMint);
                tokens[i] = nextTokenIdMint;
                unchecked {
                    i++;
                }
            }

            bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(dstGasReserve));
            bytes memory payload = abi.encode(abi.encodePacked(userAddress), tokens);
            payload = abi.encodePacked(MessageType.TRANSFER, payload);

            (uint256 nativeFee, ) = lzEndpoint.estimateFees(_srcChainId, address(this), payload, false, adapterParams);
            if(address(this).balance < nativeFee){
                bytes32 hashedPayload = keccak256(payload);
                NFTUserRefund[hashedPayload] = NFTRefund(userAddress, _srcChainId, tokens);
                return;
            }
            _lzSend(_srcChainId, payload, payable(address(this)), address(0), adapterParams, nativeFee);
            emit SendToChain(_srcChainId, address(this), abi.encode(userAddress), tokens);
        }
    }

    function sendOmniRefund(address userAddress, uint16 chainID) public payable {
        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });
        bytes32 userAddressBytes = bytes32(uint256(uint160(userAddress)));
        uint256 refundAmount = omniUserRefund[userAddress][chainID];
        require(refundAmount > 0, "no funds to send");

        (uint256 nativeFee, ) = omnicat.estimateSendFee(
            chainID,
            userAddressBytes,
            refundAmount,
            false,
            lzCallParams.adapterParams
        );
        require(address(this).balance + msg.value >= nativeFee, "send more funds");

        omniUserRefund[userAddress][chainID] = 0;
        omnicat.sendFrom{value: nativeFee}(address(this), chainID, userAddressBytes, refundAmount, lzCallParams);
    }

    function sendNFTRefund(bytes32 hashedPayload) public payable {
        NFTRefund memory refundObject = NFTUserRefund[hashedPayload];
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(dstGasReserve));
        bytes memory payload = abi.encode(abi.encodePacked(refundObject.userAddress), refundObject.tokens);
        payload = abi.encodePacked(MessageType.TRANSFER, payload);

        (uint256 nativeFee, ) = lzEndpoint.estimateFees(refundObject.chainID, address(this), payload, false, adapterParams);
        require(address(this).balance + msg.value >= nativeFee, "send more funds");

        _lzSend(refundObject.chainID, payload, payable(address(this)), address(0), adapterParams, nativeFee);
        emit SendToChain(refundObject.chainID, address(this), abi.encode(refundObject.userAddress), refundObject.tokens);
    }

    // ===================== interval Functions ===================== //

    function _creditTo(
        uint16,
        address _toAddress,
        uint _tokenId
    ) internal virtual override {
        require(_exists(_tokenId) && _ownerOf(_tokenId) == address(this));
        _transfer(address(this), _toAddress, _tokenId);
    }
}
