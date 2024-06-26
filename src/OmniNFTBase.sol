// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ONFT721 } from "@LayerZero-Examples/contracts/token/onft721/ONFT721.sol";
import { IONFT721 } from "@LayerZero-Examples/contracts/token/onft721/interfaces/IONFT721.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { ExcessivelySafeCall } from "@LayerZero-Examples/contracts/libraries/ExcessivelySafeCall.sol";
import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { BaseChainInfo, MessageType, NftInfo } from "./utils/OmniNftStructs.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";


contract OmniNFTBase is
    ReentrancyGuard,
    ONFT721,
    Pausable
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;
    using ExcessivelySafeCall for address;
    using Strings for uint256;

    // ===================== Constants ===================== //
    uint64 public extraGas = 3e4;
    string public baseURI;
    uint256 public immutable MINT_COST;
    uint256 public immutable MAX_MINTS_PER_ACCOUNT;
    uint256 public immutable COLLECTION_SIZE;

    // External contracts.
    IOmniCat public omnicat;

    // ===================== Storage ===================== //
    uint256 public interchainTransactionFees = 0;

    // ===================== Constructor ===================== //
    constructor(
        IOmniCat _omnicat,
        NftInfo memory _nftInfo,
        uint _minGasToTransfer,
        address _lzEndpoint
    )
        ONFT721(_nftInfo.name, _nftInfo.symbol, _minGasToTransfer, _lzEndpoint)
    {
        omnicat = _omnicat;
        baseURI = _nftInfo.baseURI;
        MINT_COST = _nftInfo.MINT_COST;
        MAX_MINTS_PER_ACCOUNT = _nftInfo.MAX_MINTS_PER_ACCOUNT;
        COLLECTION_SIZE = _nftInfo.COLLECTION_SIZE;
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //
    function setBaseUri(string calldata _newBaseURI) onlyOwner() external {
        baseURI = _newBaseURI;
    }

    // ===================== Admin-Only External Functions (Hot) ===================== //

    function extractNative(uint256 amount) onlyOwner() external {
        if(amount == 0){
            amount = interchainTransactionFees;
        }
        require(amount <= interchainTransactionFees);
        interchainTransactionFees -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent);
    }


    function pauseContract()
        external
        nonReentrant
        onlyOwner()
    {
        _pause();
    }

    function unpauseContract()
        external
        nonReentrant
        onlyOwner()
    {
        _unpause();
    }

    // ===================== Public Functions ===================== //

    receive() external payable {
        interchainTransactionFees+=msg.value;
    }

    function _send(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint[] memory _tokenIds,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal override whenNotPaused() {
        require(_tokenIds.length > 0, "tokenIds[] is empty");
        require(_tokenIds.length == 1 || _tokenIds.length <= dstChainIdToBatchLimit[_dstChainId], "batch size exceeds dst batch limit");

        for (uint i = 0; i < _tokenIds.length; i++) {
            _debitFrom(_from, _dstChainId, _toAddress, _tokenIds[i]);
        }

        bytes memory payload = abi.encode(_toAddress, _tokenIds);
        payload = abi.encodePacked(MessageType.TRANSFER, payload);

        _checkGasLimit(_dstChainId, FUNCTION_TYPE_SEND, _adapterParams, dstChainIdToTransferGas[_dstChainId] * _tokenIds.length);
        _lzSend(_dstChainId, payload, _refundAddress, _zroPaymentAddress, _adapterParams, msg.value);
        emit SendToChain(_dstChainId, _from, _toAddress, _tokenIds);
    }

    // ===================== interval Functions ===================== //
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _blockingLzReceive(
      uint16 _srcChainId,
      bytes memory _srcAddress,
      uint64 _nonce,
      bytes memory _payload
    ) internal virtual override {
        require(gasleft() >= extraGas);
        uint256 gasToStoreFailedPayload = gasleft() - extraGas;
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(
            gasToStoreFailedPayload,
            150,
            abi.encodeWithSelector(this.nonblockingLzReceive.selector, _srcChainId, _srcAddress, _nonce, _payload)
        );
        if (!success) {
          _storeFailedMessage(_srcChainId, _srcAddress, _nonce, _payload, reason);
        }
    }
}
