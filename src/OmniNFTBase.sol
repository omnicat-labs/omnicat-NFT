// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ONFT721 } from "@LayerZero-Examples/contracts/token/onft721/ONFT721.sol";
import { IONFT721 } from "@LayerZero-Examples/contracts/token/onft721/interfaces/IONFT721.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { BaseChainInfo, MessageType, NftInfo } from "./utils/OmniNftStructs.sol";


contract OmniNFTBase is
    ReentrancyGuard,
    Pausable,
    ONFT721
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    // ===================== Constants ===================== //
    uint64 public dstGasReserve = 1e6;
    string public baseURI;
    uint256 public MINT_COST = 250000e18;
    uint256 public MAX_TOKENS_PER_MINT = 10;
    uint256 public MAX_MINTS_PER_ACCOUNT = 50;
    uint256 public COLLECTION_SIZE = 7210;

    // AccessControl roles.

    // External contracts.
    IOmniCat public omnicat;

    // ===================== Storage ===================== //

    // ===================== Constructor ===================== //
    constructor(
        IOmniCat _omnicat,
        NftInfo memory _nftInfo,
        uint _minGasToTransfer,
        address _lzEndpoint
    )
        ONFT721(_nftInfo.name, _nftInfo.symbol, _minGasToTransfer, _lzEndpoint)
    {
        // Grant admin role.
        omnicat = _omnicat;
        baseURI = _nftInfo.baseURI;
        MINT_COST = _nftInfo.MINT_COST;
        MAX_TOKENS_PER_MINT = _nftInfo.MAX_TOKENS_PER_MINT;
        MAX_MINTS_PER_ACCOUNT = _nftInfo.MAX_MINTS_PER_ACCOUNT;
        COLLECTION_SIZE = _nftInfo.COLLECTION_SIZE;
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

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

    function setDstGasReserve(uint64 _dstGasReserve) whenNotPaused onlyOwner() external {
        dstGasReserve = _dstGasReserve;
    }

    function extractNative(uint256 amount) onlyOwner() external {
        if(amount == 0){
            amount = address(this).balance;
        }
        payable(_msgSender()).transfer(amount);
    }

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    function supportsInterface(bytes4 interfaceId) public view virtual override(ONFT721) returns (bool) {
        return interfaceId == type(IONFT721).interfaceId || super.supportsInterface(interfaceId);
    }

    receive() external payable {}

    function _send(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint[] memory _tokenIds,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal override {
        // allow 1 by default
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
}
