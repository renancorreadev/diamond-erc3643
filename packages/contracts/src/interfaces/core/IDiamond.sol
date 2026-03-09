// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IDiamond
/// @notice EIP-2535 Diamond Cut interface
interface IDiamond {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

/// @title IDiamondCut
/// @notice Allows adding/replacing/removing facets on the Diamond
interface IDiamondCut is IDiamond {
    /// @notice Add/replace/remove any number of functions and optionally
    ///         execute a function with delegatecall.
    /// @param _diamondCut Array of FacetCut structs
    /// @param _init Address of contract or facet to execute _calldata
    /// @param _calldata Function call data (or empty)
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata)
        external;
}

/// @title IDiamondLoupe
/// @notice EIP-2535 introspection interface (required by standard)
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function facets() external view returns (Facet[] memory);

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory);

    function facetAddresses() external view returns (address[] memory);

    function facetAddress(bytes4 _functionSelector) external view returns (address);
}
