// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {Diamond} from "../../src/Diamond.sol";
import {DiamondCutFacet} from "../../src/facets/core/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/facets/core/DiamondLoupeFacet.sol";
import {IDiamond, IDiamondCut, IDiamondLoupe} from "../../src/interfaces/core/IDiamond.sol";

contract DiamondTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");

    function setUp() public {
        d = deployDiamond(owner);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_DeployRegistersOwner() public view {
        address actual = IDiamondLoupe(address(d.diamond)).facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(actual, address(d.cutFacet));
    }

    function test_DiamondCutFacetRegisteredOnDeploy() public view {
        bytes4[] memory selectors =
            IDiamondLoupe(address(d.diamond)).facetFunctionSelectors(address(d.cutFacet));
        assertEq(selectors.length, 1);
        assertEq(selectors[0], IDiamondCut.diamondCut.selector);
    }

    function test_LoupeFacetRegistered() public view {
        bytes4[] memory selectors =
            IDiamondLoupe(address(d.diamond)).facetFunctionSelectors(address(d.loupeFacet));
        assertEq(selectors.length, 5);
    }

    function test_FacetAddressesReturnsThreeFacets() public view {
        address[] memory addrs = IDiamondLoupe(address(d.diamond)).facetAddresses();
        assertEq(addrs.length, 11); // cut + loupe + ownership + accessControl + pause + emergency + freeze + assetManager + claimTopics + trustedIssuer + identityRegistry
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_UnregisteredSelector() public {
        bytes4 unknownSig = bytes4(keccak256("nonExistentFunction()"));
        vm.expectRevert(abi.encodeWithSignature("Diamond__FunctionNotFound(bytes4)", unknownSig));
        (bool success,) = address(d.diamond).call(abi.encodeWithSelector(unknownSig));
        // suppress unused variable warning — revert is asserted via expectRevert
        success;
    }

    function test_ReceivesEth() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(d.diamond).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(d.diamond).balance, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            DIAMOND CUT
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_NonOwnerCuts() public {
        address attacker = makeAddr("attacker");
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](0);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        IDiamondCut(address(d.diamond)).diamondCut(cuts, address(0), "");
    }

    function test_AddAndRemoveFacetSelector() public {
        // Deploy a fresh facet with a dummy selector
        DiamondCutFacet newFacet = new DiamondCutFacet();
        bytes4 dummySel = bytes4(keccak256("dummy()"));

        IDiamond.FacetCut[] memory addCut = new IDiamond.FacetCut[](1);
        addCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _selectors(dummySel)
        });

        vm.prank(owner);
        IDiamondCut(address(d.diamond)).diamondCut(addCut, address(0), "");

        assertEq(IDiamondLoupe(address(d.diamond)).facetAddress(dummySel), address(newFacet));

        // Remove it
        IDiamond.FacetCut[] memory removeCut = new IDiamond.FacetCut[](1);
        removeCut[0] = IDiamond.FacetCut({
            facetAddress: address(0),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: _selectors(dummySel)
        });

        vm.prank(owner);
        IDiamondCut(address(d.diamond)).diamondCut(removeCut, address(0), "");

        assertEq(IDiamondLoupe(address(d.diamond)).facetAddress(dummySel), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _selectors(bytes4 sel) internal pure returns (bytes4[] memory arr) {
        arr = new bytes4[](1);
        arr[0] = sel;
    }
}
