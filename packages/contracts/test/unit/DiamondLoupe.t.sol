// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {IDiamond, IDiamondCut, IDiamondLoupe} from "../../src/interfaces/core/IDiamond.sol";
// solhint-disable-next-line import-path-check
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract DiamondLoupeTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IDiamondLoupe internal loupe;

    function setUp() public {
        d = deployDiamond(owner);
        loupe = IDiamondLoupe(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                            FACET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    function test_FacetAddressesLength() public view {
        address[] memory addrs = loupe.facetAddresses();
        assertEq(addrs.length, 7); // cut + loupe + ownership + accessControl + pause + emergency + freeze
    }

    function test_FacetAddressesContainsCutFacet() public view {
        address[] memory addrs = loupe.facetAddresses();
        bool found;
        for (uint256 i; i < addrs.length; ++i) {
            if (addrs[i] == address(d.cutFacet)) found = true;
        }
        assertTrue(found);
    }

    function test_FacetAddressesContainsLoupeFacet() public view {
        address[] memory addrs = loupe.facetAddresses();
        bool found;
        for (uint256 i; i < addrs.length; ++i) {
            if (addrs[i] == address(d.loupeFacet)) found = true;
        }
        assertTrue(found);
    }

    function test_FacetAddressesContainsOwnershipFacet() public view {
        address[] memory addrs = loupe.facetAddresses();
        bool found;
        for (uint256 i; i < addrs.length; ++i) {
            if (addrs[i] == address(d.ownershipFacet)) found = true;
        }
        assertTrue(found);
    }

    /*//////////////////////////////////////////////////////////////
                        FACET FUNCTION SELECTORS
    //////////////////////////////////////////////////////////////*/

    function test_CutFacetHasOneSelector() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(d.cutFacet));
        assertEq(sels.length, 1);
        assertEq(sels[0], IDiamondCut.diamondCut.selector);
    }

    function test_LoupeFacetHasFiveSelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(d.loupeFacet));
        assertEq(sels.length, 5);
    }

    function test_OwnershipFacetHasFourSelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(d.ownershipFacet));
        assertEq(sels.length, 4);
    }

    function test_UnregisteredFacetReturnsEmptySelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(0xdead));
        assertEq(sels.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FACET ADDRESS
    //////////////////////////////////////////////////////////////*/

    function test_FacetAddressForDiamondCutSelector() public view {
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(d.cutFacet));
    }

    function test_FacetAddressForUnknownSelectorIsZero() public view {
        assertEq(loupe.facetAddress(bytes4(keccak256("nonExistent()"))), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                                FACETS
    //////////////////////////////////////////////////////////////*/

    function test_FacetsReturnsCorrectLength() public view {
        IDiamondLoupe.Facet[] memory fs = loupe.facets();
        assertEq(fs.length, 7);
    }

    function test_FacetsSelectorsNonEmpty() public view {
        IDiamondLoupe.Facet[] memory fs = loupe.facets();
        for (uint256 i; i < fs.length; ++i) {
            assertGt(fs[i].functionSelectors.length, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SUPPORTS INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_SupportsIDiamondCut() public view {
        assertTrue(IERC165(address(d.diamond)).supportsInterface(type(IDiamondCut).interfaceId));
    }

    function test_SupportsIDiamondLoupe() public view {
        assertTrue(IERC165(address(d.diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    function test_SupportsERC165() public view {
        assertTrue(IERC165(address(d.diamond)).supportsInterface(type(IERC165).interfaceId));
    }

    function test_DoesNotSupportRandomInterface() public view {
        assertFalse(IERC165(address(d.diamond)).supportsInterface(bytes4(keccak256("randomInterface()"))));
    }
}
