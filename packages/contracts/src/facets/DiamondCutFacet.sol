// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondCut} from "../interfaces/IDiamond.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/// @title DiamondCutFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Implements EIP-2535 diamondCut — only callable by the Diamond owner.
/// @custom:security-contact renan.correa@hubweb3.com
contract DiamondCutFacet is IDiamondCut {
    /// @inheritdoc IDiamondCut
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
