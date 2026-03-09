// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {ClaimTopicsFacet} from "../../src/facets/identity/ClaimTopicsFacet.sol";
import {TrustedIssuerFacet} from "../../src/facets/identity/TrustedIssuerFacet.sol";
import {AccessControlFacet} from "../../src/facets/security/AccessControlFacet.sol";

contract TrustedIssuerFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    address internal claimAdmin = makeAddr("claimAdmin");
    address internal stranger = makeAddr("stranger");
    address internal issuerAddr = makeAddr("issuerAddr");

    ClaimTopicsFacet internal ct;
    TrustedIssuerFacet internal ti;
    AccessControlFacet internal ac;

    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    uint32 internal profileId;

    function setUp() public {
        d = deployDiamond(owner);
        ct = ClaimTopicsFacet(address(d.diamond));
        ti = TrustedIssuerFacet(address(d.diamond));
        ac = AccessControlFacet(address(d.diamond));

        vm.prank(owner);
        ac.grantRole(CLAIM_ISSUER_ROLE, claimAdmin);

        uint256[] memory topics = new uint256[](1);
        topics[0] = 1;
        vm.prank(owner);
        profileId = ct.createProfile(topics);
    }

    /*//////////////////////////////////////////////////////////////
                            ADD TRUSTED ISSUER
    //////////////////////////////////////////////////////////////*/

    function test_AddTrustedIssuer_Owner() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);
        assertTrue(ti.isTrustedIssuer(profileId, issuerAddr));
    }

    function test_AddTrustedIssuer_ClaimAdmin() public {
        vm.prank(claimAdmin);
        ti.addTrustedIssuer(profileId, issuerAddr);
        assertTrue(ti.isTrustedIssuer(profileId, issuerAddr));
    }

    function test_AddTrustedIssuer_BumpsProfileVersion() public {
        uint64 vBefore = ct.getProfileVersion(profileId);
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);
        assertEq(ct.getProfileVersion(profileId), vBefore + 1);
    }

    function test_RevertWhen_AddTrustedIssuer_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("TrustedIssuerFacet__ZeroAddress()"));
        ti.addTrustedIssuer(profileId, address(0));
    }

    function test_RevertWhen_AddTrustedIssuer_AlreadyTrusted() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("TrustedIssuerFacet__AlreadyTrusted(uint32,address)", profileId, issuerAddr)
        );
        ti.addTrustedIssuer(profileId, issuerAddr);
    }

    function test_RevertWhen_AddTrustedIssuer_ProfileNotFound() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("TrustedIssuerFacet__ProfileNotFound(uint32)", 99));
        ti.addTrustedIssuer(99, issuerAddr);
    }

    function test_RevertWhen_AddTrustedIssuer_Unauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("TrustedIssuerFacet__Unauthorized()"));
        ti.addTrustedIssuer(profileId, issuerAddr);
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVE TRUSTED ISSUER
    //////////////////////////////////////////////////////////////*/

    function test_RemoveTrustedIssuer() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);

        vm.prank(owner);
        ti.removeTrustedIssuer(profileId, issuerAddr);
        assertFalse(ti.isTrustedIssuer(profileId, issuerAddr));
    }

    function test_RemoveTrustedIssuer_BumpsProfileVersion() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);
        uint64 vBefore = ct.getProfileVersion(profileId);

        vm.prank(owner);
        ti.removeTrustedIssuer(profileId, issuerAddr);
        assertEq(ct.getProfileVersion(profileId), vBefore + 1);
    }

    function test_RevertWhen_RemoveTrustedIssuer_NotTrusted() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("TrustedIssuerFacet__NotTrusted(uint32,address)", profileId, issuerAddr)
        );
        ti.removeTrustedIssuer(profileId, issuerAddr);
    }

    function test_RevertWhen_RemoveTrustedIssuer_ProfileNotFound() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("TrustedIssuerFacet__ProfileNotFound(uint32)", 99));
        ti.removeTrustedIssuer(99, issuerAddr);
    }

    function test_RevertWhen_RemoveTrustedIssuer_Unauthorized() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("TrustedIssuerFacet__Unauthorized()"));
        ti.removeTrustedIssuer(profileId, issuerAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_IsTrustedIssuer_False_Unknown() public view {
        assertFalse(ti.isTrustedIssuer(profileId, issuerAddr));
    }

    function test_IsTrustedIssuer_False_WrongProfile() public {
        vm.prank(owner);
        ti.addTrustedIssuer(profileId, issuerAddr);

        uint256[] memory topics = new uint256[](1);
        topics[0] = 2;
        vm.prank(owner);
        uint32 profileId2 = ct.createProfile(topics);

        assertFalse(ti.isTrustedIssuer(profileId2, issuerAddr));
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_AddRemoveTrustedIssuer(address addr) public {
        vm.assume(addr != address(0));

        vm.prank(owner);
        ti.addTrustedIssuer(profileId, addr);
        assertTrue(ti.isTrustedIssuer(profileId, addr));

        vm.prank(owner);
        ti.removeTrustedIssuer(profileId, addr);
        assertFalse(ti.isTrustedIssuer(profileId, addr));
    }
}
