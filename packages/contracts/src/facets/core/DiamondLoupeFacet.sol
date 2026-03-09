// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondLoupe} from "../../interfaces/core/IDiamond.sol";
import {LibDiamond, DiamondStorage} from "../../libraries/LibDiamond.sol";
// solhint-disable-next-line import-path-check
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title DiamondLoupeFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice EIP-2535 introspection facet — required by the Diamond standard.
///         Exposes all registered facets and their function selectors.
/// @custom:security-contact renan.correa@hubweb3.com
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    /// @inheritdoc IDiamondLoupe
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; ++i) {
            address facetAddr = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddr;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddr].functionSelectors;
        }
    }

    /// @inheritdoc IDiamondLoupe
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory)
    {
        return LibDiamond.diamondStorage().facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddresses() external view override returns (address[] memory) {
        return LibDiamond.diamondStorage().facetAddresses;
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddress(bytes4 _functionSelector) external view override returns (address) {
        return LibDiamond.diamondStorage().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return LibDiamond.diamondStorage().supportedInterfaces[_interfaceId];
    }
}
