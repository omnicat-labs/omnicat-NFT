pragma solidity 0.8.19;

import { IOFTV2 } from "@LayerZero-Examples/contracts/token/oft/v2/interfaces/IOFTV2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @dev Interface of the IOFT core standard
 */
interface IOmniCat is IOFTV2, IERC20 {}