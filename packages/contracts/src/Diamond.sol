// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamond, IDiamondCut} from "./interfaces/core/IDiamond.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error Diamond__FunctionNotFound(bytes4 selector);

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title Diamond
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice EIP-2535 Diamond Proxy — routes all calls to registered facets.
///         Implements ERC-3643 security token semantics with ERC-1155
///         multi-token support for Real World Assets (RWA).
/// @dev Storage is handled via LibAppStorage (AppStorage) and LibDiamond
///      (DiamondStorage), both at deterministic slots to avoid collisions.
/// @custom:security-contact renan.correa@hubweb3.com
contract Diamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        // Register the DiamondCut facet so the owner can add other facets
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;

        cut[0] = IDiamond.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        LibDiamond.diamondCut(cut, address(0), "");
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice Accept plain ETH transfers
    receive() external payable {}

    /// @dev Delegates all calls to the appropriate facet. Reverts if no
    ///      facet is registered for the given selector.
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        address facet =
            LibDiamond.diamondStorage().selectorToFacetAndPosition[msg.sig].facetAddress;
        if (facet == address(0)) revert Diamond__FunctionNotFound(msg.sig);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
