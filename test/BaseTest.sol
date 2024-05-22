pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { OmniNFT } from "../src/OmniNFT.sol";
import { OmniNFTA } from "../src/OmniNFTA.sol";
import { LZEndpointMock } from "@LayerZero-Examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import { OmniCatMock } from "../src/mocks/OmniCatMock.sol";
import { BaseChainInfo, MessageType } from "../src/utils/OmniNftStructs.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BaseTest is Test {
    OmniNFTA public omniNFTA;
    OmniNFT public omniNFT;

    LZEndpointMock public layerZeroEndpointMock1;
    OmniCatMock public omnicatMock1;
    LZEndpointMock public layerZeroEndpointMock2;
    OmniCatMock public omnicatMock2;

    uint16 firstChainId = 1;
    uint16 secondChainId = 2;

    address admin = address(0x1);
    uint256 timestamp = 1e7;

    address user1 = address(0x8);
    address user2 = address(0x9);
    address user3 = address(0xa);
    address user4 = address(0xb);

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    function setUp() public {
        vm.startPrank(admin);

        layerZeroEndpointMock1 = new LZEndpointMock(firstChainId);
        layerZeroEndpointMock2 = new LZEndpointMock(secondChainId);

        omnicatMock1 = new OmniCatMock(address(layerZeroEndpointMock1), 100e30, 18);
        omnicatMock2 = new OmniCatMock(address(layerZeroEndpointMock2), 100e30, 18);

        omnicatMock1.setMinDstGas(secondChainId, uint16(0), 1e5);
        omnicatMock1.setTrustedRemoteAddress(secondChainId, abi.encodePacked(address(omnicatMock2)));

        omnicatMock2.setMinDstGas(firstChainId, uint16(0), 1e5);
        omnicatMock2.setTrustedRemoteAddress(firstChainId, abi.encodePacked(address(omnicatMock1)));

        omnicatMock1.transfer(user1, 100e25);
        omnicatMock1.transfer(user2, 100e25);
        omnicatMock1.transfer(user3, 100e25);
        omnicatMock1.transfer(user4, 100e25);

        omnicatMock2.transfer(user1, 100e25);
        omnicatMock2.transfer(user2, 100e25);
        omnicatMock2.transfer(user3, 100e25);
        omnicatMock2.transfer(user4, 100e25);

        omniNFTA = new OmniNFTA(
            BaseChainInfo({
                BASE_CHAIN_ID: uint16(0),
                BASE_CHAIN_ADDRESS: address(0)
            }),
            omnicatMock1,
            "omniNFT",
            "onft",
            1e4,
            address(layerZeroEndpointMock1),
            "http://omni.xyz"
        );
        BaseChainInfo memory baseChainInfo = BaseChainInfo({
            BASE_CHAIN_ID: firstChainId,
            BASE_CHAIN_ADDRESS: address(omniNFTA)
        });
        omniNFT = new OmniNFT(
            baseChainInfo,
            omnicatMock2,
            "omniNFT",
            "onft",
            1e4,
            address(layerZeroEndpointMock2),
            "http://omni.xyz"
        );

        omniNFTA.setTrustedRemoteAddress(secondChainId, abi.encodePacked(address(omniNFT)));
        omniNFTA.setMinDstGas(secondChainId, omniNFTA.FUNCTION_TYPE_SEND(), 1e5);
        omniNFT.setTrustedRemoteAddress(firstChainId, abi.encodePacked(address(omniNFTA)));
        omniNFT.setMinDstGas(firstChainId, omniNFT.FUNCTION_TYPE_SEND(), 1e5);

        vm.deal(address(omniNFTA), 1e20);
        vm.deal(address(omniNFT), 1e20);

        layerZeroEndpointMock1.setDestLzEndpoint(address(omnicatMock2), address(layerZeroEndpointMock2));
        layerZeroEndpointMock2.setDestLzEndpoint(address(omnicatMock1), address(layerZeroEndpointMock1));

        layerZeroEndpointMock1.setDestLzEndpoint(address(omniNFT), address(layerZeroEndpointMock2));
        layerZeroEndpointMock2.setDestLzEndpoint(address(omniNFTA), address(layerZeroEndpointMock1));

        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(address(user1), 1e20);
        omnicatMock1.approve(address(omniNFTA), 100e25);
        omnicatMock2.approve(address(omniNFT), 100e25);
        vm.stopPrank();
        vm.startPrank(user2);
        vm.deal(address(user2), 1e20);
        omnicatMock1.approve(address(omniNFTA), 100e25);
        omnicatMock2.approve(address(omniNFT), 100e25);
        vm.stopPrank();
        vm.startPrank(user3);
        vm.deal(address(user3), 1e20);
        omnicatMock1.approve(address(omniNFTA), 100e25);
        omnicatMock2.approve(address(omniNFT), 100e25);
        vm.stopPrank();
        vm.startPrank(user4);
        vm.deal(address(user4), 1e20);
        omnicatMock1.approve(address(omniNFTA), 100e25);
        omnicatMock2.approve(address(omniNFT), 100e25);
        vm.stopPrank();
    }
}