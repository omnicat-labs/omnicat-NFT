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

import { AccessControlAdminProtection } from "./utils/AccessControlAdminProtection.sol";

contract OmniNFTA is
    ReentrancyGuard,
    Pausable,
    AccessControlAdminProtection,
    ONFT721A
{
    using SafeERC20 for IOmniCat;
    using SafeCast for uint256;

    // ===================== Constants ===================== //
    uint256 public dstGasReserve = 1e5;
    uint16 public immutable CHAIN_ID;
    string public immutable baseURI;
    uint256 public MINT_COST = 250e18;

    // AccessControl roles.

    // External contracts.
    IOmniCat public omnicat;

    // ===================== Storage ===================== //

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
        ONFT721(_name, _symbol, _minGasToTransfer, _lzEndpoint)
    {
        // Grant admin role.
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        CHAIN_ID = _chain_id;
        omnicat = _omnicat;
        baseURI = _baseURI;
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

    function setDstGasReserve(uint256 _dstGasReserve) whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) external {
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
    // TODO:- remove this maybe?
    receive() external payable {}

    // TODO:- This is not an interchain transaction. mints a token for the user.
    function mint() external {
        revert("not implemented");
    }

    // TODO:- This is not an interchain transaction. burns a token from the user, and credits omni to the user.
    function burn() external {
        revert("not implemented");
    }

    // TODO:- override this to accept burns and mints.
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal virtual override {
        // decode and load the toAddress
        (bytes memory toAddressBytes, uint[] memory tokenIds) = abi.decode(_payload, (bytes, uint[]));

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
