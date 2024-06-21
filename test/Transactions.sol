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
    event CollectionMinted();

    function testNormalMintTransactionBurn() public {
        vm.startPrank(user1);
        vm.expectEmit(address(omniNFTA));
        emit CollectionMinted();
        omniNFTA.mint(10);
        vm.assertEq(omniNFTA.balanceOf(user1), 10);
        vm.assertEq(omniNFTA.ownerOf(1), user1);
        vm.assertEq(omniNFTA.ownerOf(2), user1);

        omniNFTA.safeTransferFrom(user1, user2, 1);
        vm.assertEq(omniNFTA.balanceOf(user2), 1);
        vm.assertEq(omniNFTA.balanceOf(user1), 9);
        vm.assertEq(omniNFTA.ownerOf(1), user2);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 prevBalance = omnicatMock1.balanceOf(user2);
        omniNFTA.burn(1);
        vm.assertEq(omniNFTA.balanceOf(user2), 0);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.assertEq(omnicatMock1.balanceOf(user2), prevBalance + omniNFTA.MINT_COST());
        vm.stopPrank();
    }

    function testInterchainTransactionBurn() public {
        vm.startPrank(user1);
        omniNFTA.mint(10);
        vm.assertEq(omniNFTA.balanceOf(user1), 10);
        vm.assertEq(omniNFTA.ownerOf(0), user1);

        uint256[] memory tokens = new uint256[](5);
        for(uint256 i=0;i<5;i++){
            tokens[i] = i+1;
        }
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        (uint256 nativeFee, ) = omniNFTA.estimateSendBatchFee(secondChainId, abi.encodePacked(user2), tokens, false, adapterParams);
        omniNFTA.sendBatchFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user2), tokens, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user2), 5);
        vm.assertEq(omniNFT.ownerOf(1), user2);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 prevBalance = omnicatMock2.balanceOf(user2);
        uint256 burnFee = omniNFT.estimateBurnFees(1);
        omniNFT.burn{value: 2*burnFee}(1);
        vm.assertEq(omniNFT.balanceOf(user2), 4);
        vm.assertEq(omniNFTA.balanceOf(user2), 0);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.assertEq(omnicatMock2.balanceOf(user2), prevBalance + omniNFT.MINT_COST());
        vm.stopPrank();
    }

    function testInterchainMintTransactionBurn() public {
        vm.startPrank(user1);
        uint256 prevBalance = omnicatMock1.balanceOf(address(omniNFTA));
        omniNFTA.mint(10);
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        (uint256 nativeFee, ) = omniNFTA.estimateSendFee(secondChainId, abi.encodePacked(user1), 1, false, adapterParams);
        omniNFTA.sendFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user1), 1, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user1), 1);
        vm.assertEq(omniNFT.ownerOf(1), user1);
        vm.assertEq(omnicatMock1.balanceOf(address(omniNFTA)), prevBalance + 10*omniNFTA.MINT_COST());

        adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        (nativeFee, ) = omniNFT.estimateSendFee(firstChainId, abi.encodePacked(user2), 1, false, adapterParams);
        omniNFT.sendFrom{value: 2*nativeFee}(user1, firstChainId, abi.encodePacked(user2), 1, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFTA.balanceOf(user2), 1);
        vm.assertEq(omniNFTA.ownerOf(1), user2);
        vm.stopPrank();

        vm.startPrank(user2);
        prevBalance = omnicatMock1.balanceOf(user2);
        omniNFTA.burn(1);
        vm.assertEq(omniNFTA.balanceOf(user2), 0);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.assertEq(omnicatMock1.balanceOf(user2), prevBalance + omniNFT.MINT_COST());
        vm.stopPrank();
    }

    function testRefunds() public {
        vm.startPrank(admin);
        omniNFTA.extractNative(0);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 prevBalance = omnicatMock1.balanceOf(address(omniNFTA));
        omniNFTA.mint(5);
        uint256[] memory tokens = new uint256[](5);
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        for(uint256 i=0;i<5;i++){
            tokens[i] = i;
        }
        (uint256 nativeFee, ) = omniNFTA.estimateSendBatchFee(secondChainId, abi.encodePacked(user1), tokens, false, adapterParams);
        omniNFTA.sendBatchFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user1), tokens, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user1), 5);
        vm.assertEq(omnicatMock1.balanceOf(address(omniNFTA)), prevBalance + 5*omniNFTA.MINT_COST());
        uint256 burnFee = omniNFT.estimateBurnFees(1);
        omniNFT.burn{value: 2*burnFee}(1);
        vm.assertEq(omniNFT.balanceOf(user1), 4);
        vm.assertEq(omnicatMock1.balanceOf(address(omniNFTA)), prevBalance + 5*omniNFTA.MINT_COST());
        vm.stopPrank();

        vm.startPrank(admin);
        (bool sent, bytes memory data) = payable(address(omniNFTA)).call{value: 1e20, gas: 1e5}("");

        tokens = new uint256[](1);
        tokens[0] = 1;
        bytes memory payload = abi.encode(abi.encodePacked(user1), tokens);
        payload = abi.encodePacked(MessageType.TRANSFER, payload);
        omniNFTA.sendNFTRefund(keccak256(payload));
        vm.assertEq(omniNFT.balanceOf(user1), 5);
        vm.assertEq(omniNFT.ownerOf(1), user1);
        vm.assertEq(omniNFT.ownerOf(2), user1);
        vm.stopPrank();

        vm.startPrank(admin);
        omniNFTA.extractNative(0);
        vm.stopPrank();

        vm.startPrank(user1);
        omniNFTA.mint(5);
        prevBalance = omnicatMock2.balanceOf(user1);
        burnFee = omniNFT.estimateBurnFees(1);
        omniNFT.burn{value: 2*burnFee}(1);
        vm.assertEq(omniNFT.balanceOf(user1), 4);
        vm.assertEq(omniNFTA.balanceOf(user1), 5);
        vm.expectRevert("ERC721: invalid token ID");
        omniNFTA.ownerOf(1);
        vm.assertEq(omnicatMock2.balanceOf(user1), prevBalance);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.deal(admin, 15e19);
        (sent, data) = payable(address(omniNFTA)).call{value: 1e20, gas: 1e5}("");

        omniNFTA.sendOmniRefund(user1, secondChainId);
        vm.assertEq(omnicatMock2.balanceOf(user1), prevBalance + omniNFT.MINT_COST());
        vm.stopPrank();
    }

    function testMoreRefunds() public {
        // Mint a few nfts and try to burn one
        vm.startPrank(user1);
        uint256 prevBalance = omnicatMock1.balanceOf(address(omniNFTA));

        omniNFTA.mint(5);
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        uint256[] memory tokens = new uint256[](5);
        for(uint256 i=0;i<5;i++){
            tokens[i] = i;
        }
        (uint256 nativeFee, ) = omniNFTA.estimateSendBatchFee(secondChainId, abi.encodePacked(user1), tokens, false, adapterParams);
        omniNFTA.sendBatchFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user1), tokens, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user1), 5);
        vm.assertEq(omnicatMock1.balanceOf(address(omniNFTA)), prevBalance + 5*omniNFTA.MINT_COST());
        uint256 burnFee = omniNFT.estimateBurnFees(1);
        omniNFT.burn{value: 2*burnFee}(1);
        vm.assertEq(omniNFT.balanceOf(user1), 4);
        vm.stopPrank();

        // Since burning is not allowed yet because the full collection is not minted, the admin can give the use their
        // NFT back
        vm.startPrank(admin);
        tokens = new uint256[](1);
        tokens[0] = 1;
        bytes memory payload = abi.encode(abi.encodePacked(user1), tokens);
        payload = abi.encodePacked(MessageType.TRANSFER, payload);
        omniNFTA.sendNFTRefund(keccak256(payload));
        vm.assertEq(omniNFT.balanceOf(user1), 5);
        vm.stopPrank();

        // Try to mint more nfts after mint
        vm.startPrank(user1);
        prevBalance = omnicatMock1.balanceOf(address(omniNFTA));
        omniNFTA.mint(5);
        adapterParams = abi.encodePacked(uint16(1), uint256(omniNFTA.dstGasReserve()));
        tokens = new uint256[](5);
        for(uint256 i=0;i<5;i++){
            tokens[i] = i+5;
        }
        (nativeFee, ) = omniNFTA.estimateSendBatchFee(secondChainId, abi.encodePacked(user1), tokens, false, adapterParams);
        omniNFTA.sendBatchFrom{value: 2*nativeFee}(user1, secondChainId, abi.encodePacked(user1), tokens, payable(user1), address(0), adapterParams);
        vm.assertEq(omniNFT.balanceOf(user1), 10);
        vm.assertEq(omnicatMock1.balanceOf(address(omniNFTA)), 10*omniNFTA.MINT_COST());
        vm.stopPrank();
    }
}