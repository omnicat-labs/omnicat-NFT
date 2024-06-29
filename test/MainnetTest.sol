pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { OmniNFTMainnet } from "../src/OmniNFTMainnet.sol";
import { OmniNFTA } from "../src/OmniNFTA.sol";
import { LZEndpointMock } from "@LayerZero-Examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import { ProxyOFTV2 } from "@LayerZero-Examples/contracts/token/oft/v2/ProxyOFTV2.sol";
import { OmniCatMock } from "../src/mocks/OmniCatMock.sol";
import { BaseChainInfo, MessageType, NftInfo } from "../src/utils/OmniNftStructs.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IBlast } from "../src/interfaces/IBlast.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import { IOmniCat } from "../src/interfaces/IOmniCat.sol";
import { ICommonOFT } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";

contract MainnetTest is Test {
    OmniNFTA public omniNFTA;
    OmniNFTMainnet public omniNFT;

    LZEndpointMock public layerZeroEndpointMock1;
    OmniCatMock public omnicatMock1;
    LZEndpointMock public layerZeroEndpointMock2;
    ProxyOFTV2 public omnicatMock2;
    ERC20Mock public omnicatMockERC20;

    uint16 firstChainId = 1;
    uint16 secondChainId = 2;

    address admin = address(0x01FAA242EE03D7F6A89c9135354461d2e4151193);
    uint256 timestamp = 1e7;

    address user1 = address(0xe7723BB629F31dE081Ee4D2768D5D8E9dc667957);
    address user2 = address(0x2E6cE76692c37560B8EC688199Ee5BC8CE51f7b7);
    address user3 = address(0xA602F1E2f1Db156A5207A300d539E59F687e5109);
    address user4 = address(0xdBC401642f390D89Ee35B2C662C4bF5F1CbE9673);

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    uint256 dstChainIdToTransferGas = 3e5;
    uint256 mindstGasExtra = 1e5;
    uint256 mindstGasLookupOmni = 2e5;

    function setUp() public {
        vm.startPrank(admin);

        layerZeroEndpointMock1 = new LZEndpointMock(firstChainId);
        layerZeroEndpointMock2 = new LZEndpointMock(secondChainId);

        omnicatMock1 = new OmniCatMock(address(layerZeroEndpointMock1), 0, 8);
        omnicatMockERC20 = new ERC20Mock(1e18);
        omnicatMockERC20.initialize("", "", 18);
        omnicatMock2 = new ProxyOFTV2(address(omnicatMockERC20), 8, address(layerZeroEndpointMock2));

        omnicatMock1.setMinDstGas(secondChainId, uint16(0), 1e5);
        omnicatMock1.setMinDstGas(secondChainId, uint16(1), 1e5);
        omnicatMock1.setTrustedRemoteAddress(secondChainId, abi.encodePacked(address(omnicatMock2)));

        omnicatMock2.setMinDstGas(firstChainId, uint16(0), 1e5);
        omnicatMock2.setMinDstGas(firstChainId, uint16(1), 1e5);
        omnicatMock2.setTrustedRemoteAddress(firstChainId, abi.encodePacked(address(omnicatMock1)));

        vm.mockCall(
            address(BLAST),
            abi.encodeWithSelector(IBlast.configureClaimableGas.selector),
            ""
        );
        vm.mockCall(
            address(BLAST),
            abi.encodeWithSelector(IBlast.configureGovernor.selector, admin),
            ""
        );
        omniNFTA = new OmniNFTA(
            omnicatMock1,
            NftInfo({
                baseURI: "http://omni.xyz",
                MINT_COST: 25000e10,
                MAX_MINTS_PER_ACCOUNT: 50,
                COLLECTION_SIZE: 10,
                name: "omniNFT",
                symbol: "onft"
            }),
            1e4,
            address(layerZeroEndpointMock1),
            timestamp
        );
        BaseChainInfo memory baseChainInfo = BaseChainInfo({
            BASE_CHAIN_ID: firstChainId,
            BASE_CHAIN_ADDRESS: address(omniNFTA)
        });
        omniNFT = new OmniNFTMainnet(
            baseChainInfo,
            IOmniCat(address(omnicatMock2)),
            IERC20(address(omnicatMockERC20)),
            NftInfo({
                baseURI: "http://omni.xyz",
                MINT_COST: 25000e10,
                MAX_MINTS_PER_ACCOUNT: 50,
                COLLECTION_SIZE: 10,
                name: "omniNFT",
                symbol: "onft"
            }),
            1e4,
            address(layerZeroEndpointMock2),
            5e16
        );

        omniNFTA.setTrustedRemoteAddress(secondChainId, abi.encodePacked(address(omniNFT)));
        omniNFTA.setMinDstGas(secondChainId, omniNFTA.FUNCTION_TYPE_SEND(), 1e4);
        omniNFTA.setDstChainIdToBatchLimit(secondChainId, 10);
        omniNFTA.setDstChainIdToTransferGas(secondChainId, dstChainIdToTransferGas);
        omniNFTA.setMinDstGasLookupOmnicat(secondChainId, mindstGasLookupOmni);

        omniNFT.setTrustedRemoteAddress(firstChainId, abi.encodePacked(address(omniNFTA)));
        omniNFT.setMinDstGas(firstChainId, omniNFT.FUNCTION_TYPE_SEND(), 1e4);
        omniNFT.setDstChainIdToBatchLimit(firstChainId, 10);
        omniNFT.setDstChainIdToTransferGas(firstChainId, dstChainIdToTransferGas);
        omniNFT.setMinDstGasLookupOmnicat(firstChainId, mindstGasLookupOmni);
        omniNFT.setDstBurnNftGas(dstChainIdToTransferGas);

        vm.deal(address(admin), 1e20);
        (bool sent, bytes memory data) = payable(address(omniNFTA)).call{value: 1e20, gas: 1e5}("");
        vm.deal(address(admin), 1e20);
        (sent, data) = payable(address(omniNFT)).call{value: 1e20, gas: 1e5}("");

        layerZeroEndpointMock1.setDestLzEndpoint(address(omnicatMock2), address(layerZeroEndpointMock2));
        layerZeroEndpointMock2.setDestLzEndpoint(address(omnicatMock1), address(layerZeroEndpointMock1));

        layerZeroEndpointMock1.setDestLzEndpoint(address(omniNFT), address(layerZeroEndpointMock2));
        layerZeroEndpointMock2.setDestLzEndpoint(address(omniNFTA), address(layerZeroEndpointMock1));

        omnicatMockERC20.approve(address(omnicatMock2), 100e30);
        ICommonOFT.LzCallParams memory lzCallParams = ICommonOFT.LzCallParams({
            refundAddress: payable(address(admin)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), mindstGasExtra)
        });
        bytes32 adminBytes = bytes32(uint256(uint160(admin)));
        (uint256 fee,) = omnicatMock2.estimateSendFee(firstChainId, adminBytes, 5e17, false, lzCallParams.adapterParams);
        vm.deal(address(admin), 2*fee+1e20);
        omnicatMock2.sendFrom{value: 2*fee}(admin, firstChainId, adminBytes, 5e17, lzCallParams);

        omnicatMock1.transfer(user1, 1e17);
        omnicatMock1.transfer(user2, 1e17);
        omnicatMock1.transfer(user3, 1e17);
        omnicatMock1.transfer(user4, 1e17);

        omnicatMockERC20.transfer(user1, 1e17);
        omnicatMockERC20.transfer(user2, 1e17);
        omnicatMockERC20.transfer(user3, 1e17);
        omnicatMockERC20.transfer(user4, 1e17);

        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(address(user1), 1e20);
        omnicatMock1.approve(address(omniNFTA), 1e17);
        omnicatMockERC20.approve(address(omniNFT), 1e17);
        vm.stopPrank();
        vm.startPrank(user2);
        vm.deal(address(user2), 1e20);
        omnicatMock1.approve(address(omniNFTA), 1e17);
        omnicatMockERC20.approve(address(omniNFT), 1e17);
        vm.stopPrank();
        vm.startPrank(user3);
        vm.deal(address(user3), 1e20);
        omnicatMock1.approve(address(omniNFTA), 1e17);
        omnicatMockERC20.approve(address(omniNFT), 1e17);
        vm.stopPrank();
        vm.startPrank(user4);
        vm.deal(address(user4), 1e20);
        omnicatMock1.approve(address(omniNFTA), 1e17);
        omnicatMockERC20.approve(address(omniNFT), 1e17);
        vm.stopPrank();
        vm.warp(timestamp);
    }
}