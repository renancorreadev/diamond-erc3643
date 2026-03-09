// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond, DiamondStorage} from "../libraries/LibDiamond.sol";
import {IDiamondCut, IDiamondLoupe} from "../interfaces/core/IDiamond.sol";
// solhint-disable-next-line import-path-check
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title DiamondInit
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Called via delegatecall during the first diamondCut to initialize
///         Diamond storage that cannot be set in the constructor.
/// @dev Must be called with _init = address(this) and _calldata = abi.encodeCall(DiamondInit.init, ())
///      during the diamondCut that registers DiamondLoupeFacet.
///      Add new initialization logic here as facets are added — never re-deploy
///      existing initializers, always add new ones to avoid re-initialization.
contract DiamondInit {
    /// @notice Registers ERC-165 interface support for the core Diamond facets.
    ///         Runs in the Diamond's storage context via delegatecall.
    function init() external {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    }
}
