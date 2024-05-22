pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { OmniNFT } from "../src/OmniNFT.sol";
import { OmniNFTA } from "../src/OmniNFTA.sol";
import { LZEndpointMock } from "@LayerZero-Examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import { OmniCatMock } from "../src/mocks/OmniCatMock.sol";
import { BaseChainInfo, MessageType } from "../src/utils/OmniNftStructs.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { BaseTest } from "./BaseTest.sol";

contract testTransactions is BaseTest {
    function testNormalMintTransactionBurn() public {
        vm.startPrank(user1);
        omniNFTA.mint();
        vm.assertEq(omniNFTA.balanceOf(user1), 1);
        vm.assertEq(omniNFTA.ownerOf(1), user1);

        omniNFTA.safeTransferFrom(user1, user2, 1);
        vm.assertEq(omniNFTA.balanceOf(user2), 1);
        vm.assertEq(omniNFTA.ownerOf(1), user2);
        vm.stopPrank();

        vm.startPrank(user2);
        omniNFTA.burn(1);
        vm.assertEq(omniNFTA.balanceOf(user2), 0);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.stopPrank();
    }

    function testInterchainTransactionBurn() public {
        vm.startPrank(user1);
        omniNFTA.mint();
        vm.assertEq(omniNFTA.balanceOf(user1), 1);
        vm.assertEq(omniNFTA.ownerOf(1), user1);

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        (uint256 nativeFee, ) = omniNFTA.estimateSendFee(secondChainId, abi.encodePacked(user2), 1, false, adapterParams);
        omniNFTA.sendFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user2), 1, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user2), 1);
        vm.assertEq(omniNFT.ownerOf(1), user2);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 burnFee = omniNFT.estimateBurnFees(1);
        omniNFT.burn{value: 2*burnFee}(1);
        vm.assertEq(omniNFTA.balanceOf(user2), 0);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.stopPrank();
    }
}