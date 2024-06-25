// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { OmniNFTBase } from "./OmniNftBase.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { BaseChainInfo, MessageType, NftInfo } from "./utils/OmniNftStructs.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBlast } from "./interfaces/IBlast.sol";
import { IOFTReceiverV2 } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/IOFTReceiverV2.sol";

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

    event SetUserOmniRefund (
        address userAddress,
        uint16 chainId,
        uint256 refundAmount
    );

    event SetUserMintRefund (
        bytes32 hashedPayload,
        address userAddress,
        uint16 chainId,
        uint256[] tokens,
        bool done
    );

    event CollectionMinted();

    // ===================== Constants ===================== //
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    uint256 public immutable mintStartTimestamp;

    // AccessControl roles.

    // External contracts.

    // ===================== Storage ===================== //
    uint256 public nextTokenIdMint = 0;
    mapping (address userAddress => mapping(uint16 chainId => uint256 refundAmount)) public omniUserRefund;
    mapping (bytes32 hashedPayload => NFTRefund userRefund) public NFTUserRefund;
    mapping (address userAddress => uint256 mintedNumber) public UserMintedNumber;

    // ===================== Constructor ===================== //
    constructor(
        IOmniCat _omnicat,
        NftInfo memory _nftInfo,
        uint _minGasToTransfer,
        address _lzEndpoint,
        uint _mintStartTimestamp
    )
        OmniNFTBase(_omnicat, _nftInfo, _minGasToTransfer, _lzEndpoint)

    {
        BLAST.configureClaimableGas();
        BLAST.configureGovernor(msg.sender);
        mintStartTimestamp = _mintStartTimestamp;
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

    // ===================== Admin-Only External Functions (Hot) ===================== //

    // ===================== Public Functions ===================== //

    function mint(uint256 mintNumber) external nonReentrant() whenNotPaused() {
        require(UserMintedNumber[msg.sender] + mintNumber <= MAX_MINTS_PER_ACCOUNT, "Too many");
        require(nextTokenIdMint + mintNumber <= COLLECTION_SIZE, "collection size exceeded");
        require(mintStartTimestamp <= block.timestamp, "minting period not started");

        omnicat.safeTransferFrom(msg.sender, address(this), mintNumber*MINT_COST);
        UserMintedNumber[msg.sender] += mintNumber;
        for(uint256 i=0;i<mintNumber;){
            _safeMint(msg.sender, nextTokenIdMint);
            unchecked {
                nextTokenIdMint++;
                i++;
            }
        }
        if(nextTokenIdMint == COLLECTION_SIZE){
            emit CollectionMinted();
        }
    }

    function burn(uint256 tokenId) external nonReentrant() whenNotPaused() {
        require(_ownerOf(tokenId) == msg.sender, "not owner");
        require(nextTokenIdMint >= COLLECTION_SIZE, "mint not completed yet");
        _burn(tokenId);
        omnicat.transfer(msg.sender, MINT_COST);
    }

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
                return;
            }
            if(nextTokenIdMint < COLLECTION_SIZE){
                // If minting not allowed, store a NFT refund for the user.
                bytes memory payload = abi.encode(abi.encodePacked(userAddress), _toSingletonArray(tokenId));
                payload = abi.encodePacked(MessageType.TRANSFER, payload);
                bytes32 hashedPayload = keccak256(payload);
                NFTUserRefund[hashedPayload] = NFTRefund(userAddress, _srcChainId, _toSingletonArray(tokenId));
                emit SetUserMintRefund(hashedPayload, userAddress, _srcChainId, _toSingletonArray(tokenId), false);
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
            if(interchainTransactionFees < nativeFee){
                omniUserRefund[userAddress][_srcChainId] += MINT_COST;
                emit SetUserOmniRefund(userAddress, _srcChainId, omniUserRefund[userAddress][_srcChainId]);
                return;
            }
            interchainTransactionFees -= nativeFee;
            omnicat.sendFrom{value: nativeFee}(address(this), _srcChainId, userAddressBytes, MINT_COST, lzCallParams);
        }
    }

    // This is called by interchain mints
    function onOFTReceived(uint16 _srcChainId, bytes calldata , uint64 , bytes32 _from, uint _amount, bytes calldata _payload) external override {
        require(msg.sender == address(omnicat));

        address rootCaller = address(uint160(uint256(_from)));
        address trustedRemoteLookupAddress = retrieveTrustedRemote(_srcChainId);
        require(rootCaller == trustedRemoteLookupAddress);

        MessageType messageType = MessageType(uint8(_payload[0]));
        if(messageType == MessageType.MINT){
            (address userAddress, uint256 mintNumber) = abi.decode(_payload[1:], (address, uint256));
            if((_amount < mintNumber*MINT_COST) || (mintStartTimestamp > block.timestamp) || (nextTokenIdMint + mintNumber > COLLECTION_SIZE) || (UserMintedNumber[msg.sender] + mintNumber > MAX_MINTS_PER_ACCOUNT)){
                // create refund for user
                omniUserRefund[userAddress][_srcChainId] += _amount;
                emit SetUserOmniRefund(userAddress, _srcChainId, omniUserRefund[userAddress][_srcChainId]);
                return;
            }
            uint256[] memory tokens = new uint256[](mintNumber);
            for(uint256 i=0;i<mintNumber;){
                _mint(userAddress, ++nextTokenIdMint);
                tokens[i] = nextTokenIdMint;
                unchecked {
                    i++;
                }
            }
        }
    }

    function sendOmniRefund(
        address userAddress,
        uint16 chainID
    ) public payable {
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
        require(interchainTransactionFees + msg.value >= nativeFee, "send more funds");
        interchainTransactionFees += msg.value;
        interchainTransactionFees -= nativeFee;
        omniUserRefund[userAddress][chainID] = 0;

        omnicat.sendFrom{value: nativeFee}(address(this), chainID, userAddressBytes, refundAmount, lzCallParams);
        emit SetUserOmniRefund(userAddress, chainID, omniUserRefund[userAddress][chainID]);
    }

    function sendNFTRefund(bytes32 hashedPayload) public payable {
        NFTRefund memory refundObject = NFTUserRefund[hashedPayload];
        require(refundObject.userAddress != address(0), "not a valid refund object");

        bytes memory adapterParams = abi.encodePacked(uint16(1), refundObject.tokens.length*uint256(dstGasReserve));
        bytes memory payload = abi.encode(abi.encodePacked(refundObject.userAddress), refundObject.tokens);
        payload = abi.encodePacked(MessageType.TRANSFER, payload);

        (uint256 nativeFee, ) = lzEndpoint.estimateFees(refundObject.chainID, address(this), payload, false, adapterParams);
        require(interchainTransactionFees + msg.value >= nativeFee, "send more funds");
        interchainTransactionFees += msg.value;
        interchainTransactionFees -= nativeFee;
        uint256[] memory emptyArray = new uint[](0);
        NFTUserRefund[hashedPayload] = NFTRefund(address(0), uint16(0), emptyArray);

        _lzSend(refundObject.chainID, payload, payable(address(this)), address(0), adapterParams, nativeFee);
        emit SendToChain(refundObject.chainID, address(this), abi.encode(refundObject.userAddress), refundObject.tokens);
        emit SetUserMintRefund(hashedPayload, refundObject.userAddress, refundObject.chainID, refundObject.tokens, true);
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

    function retrieveTrustedRemote(uint16 _srcChainId) internal view returns (address) {
        bytes memory path = trustedRemoteLookup[_srcChainId];

        require(path.length != 0, "LzApp: no trusted path record");

        address trustedRemote;
        assembly {
            trustedRemote := mload(add(path,20))
        }

        return trustedRemote;
    }
}
