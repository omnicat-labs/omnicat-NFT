// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ONFT721 } from "@LayerZero-Examples/contracts/token/onft721/ONFT721.sol";
import { IONFT721 } from "@LayerZero-Examples/contracts/token/onft721/interfaces/IONFT721.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import { IOmniCat } from "./interfaces/IOmniCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { IAccessControlEnumerable } from "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { BaseChainInfo, MessageType } from "./utils/OmniNftStructs.sol";

import { AccessControlAdminProtection } from "./utils/AccessControlAdminProtection.sol";

contract OmniNFTBase is
    ReentrancyGuard,
    Pausable,
    AccessControlAdminProtection,
    ONFT721
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    // ===================== Constants ===================== //
    uint64 public dstGasReserve = 1e6;
    BaseChainInfo public BASE_CHAIN_INFO;
    string public baseURI;
    uint256 public MINT_COST = 250000e18;

    // AccessControl roles.

    // External contracts.
    IOmniCat public omnicat;

    // ===================== Storage ===================== //

    // ===================== Constructor ===================== //
    constructor(
        BaseChainInfo memory _baseChainInfo,
        IOmniCat _omnicat,
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint,
        string memory _baseURIstring
    )
        ONFT721(_name, _symbol, _minGasToTransfer, _lzEndpoint)
    {
        // Grant admin role.
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        BASE_CHAIN_INFO = _baseChainInfo;
        omnicat = _omnicat;
        baseURI = _baseURIstring;
    }

    // ===================== Admin-Only External Functions (Cold) ===================== //

    function pauseContract()
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
    }

    function unpauseContract()
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();
    }

    function setDstGasReserve(uint64 _dstGasReserve) whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) external {
        dstGasReserve = _dstGasReserve;
    }

    // TODO:- remove this function?
    function extractNative(uint256 amount) onlyRole(DEFAULT_ADMIN_ROLE) external {
        if(amount == 0){
            amount = address(this).balance;
        }
        payable(_msgSender()).transfer(amount);
    }

    // ===================== Admin-Only External Functions (Hot) ===================== //


    // ===================== Public Functions ===================== //

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, ONFT721) returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || interfaceId == type(IONFT721).interfaceId || super.supportsInterface(interfaceId);
    }

    // TODO:- remove this maybe?
    receive() external payable {}

    function mint() external payable virtual {}

    function burn(uint256 tokenId) external payable virtual {}

    // TODO:- make this send have the payload with MessageType.TRANSFER
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

    /**
     * @dev Private function to handle token transfers using IOFTV2 interface.
     * @param from Address sending the tokens.
     * @param to Address receiving the tokens.
     * @param amount Amount of tokens to transfer.
     */
    function _transferTokens(address from, address to, uint256 amount, uint16 _dstChainId) private {
        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(from),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(dstGasReserve))
        });

        (uint256 fee, )  = omnicat.estimateSendFee(
            _dstChainId,
            bytes32(abi.encode(to)),
            amount,
            false,
            abi.encodePacked(uint16(1), uint256(dstGasReserve))
        );

        omnicat.sendFrom{value: fee}(
            from,
            _dstChainId,
            bytes32(abi.encode(to)),
            amount,
            lzCallParams
        );
    }
}
