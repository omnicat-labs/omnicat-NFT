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
    function testPauseFunctionality() public {
        vm.startPrank(admin);
        omniNFTA.pauseContract();
        vm.assertEq(omniNFTA.paused(), true);
        omniNFTA.unpauseContract();
        vm.assertEq(omniNFTA.paused(), false);
        omniNFT.pauseContract();
        vm.assertEq(omniNFT.paused(), true);
        omniNFT.unpauseContract();
        vm.assertEq(omniNFT.paused(), false);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        omniNFTA.pauseContract();
        vm.expectRevert();
        omniNFTA.unpauseContract();
        vm.expectRevert();
        omniNFT.pauseContract();
        vm.expectRevert();
        omniNFT.unpauseContract();
        vm.stopPrank();
    }

    function extra() public {
        uint256[] memory tokenIds = new uint256[](10);
        for(uint256 i=0;i<10;){
            tokenIds[i] = i;
            unchecked {
                i++;
            }
        }
        bytes memory payload = abi.encode(user1, tokenIds);
        (bytes memory toAddressBytes, ) = abi.decode(payload, (bytes, uint[]));
        vm.assertEq(toAddressBytes, abi.encode(user1));
    }
}