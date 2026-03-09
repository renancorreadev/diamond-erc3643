// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {ClaimTopicsFacet} from "../../src/facets/identity/ClaimTopicsFacet.sol";
import {AccessControlFacet} from "../../src/facets/security/AccessControlFacet.sol";

contract ClaimTopicsFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    address internal issuer = makeAddr("issuer");
    address internal stranger = makeAddr("stranger");

    ClaimTopicsFacet internal ct;
    AccessControlFacet internal ac;

    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    uint256[] internal topics1;
    uint256[] internal topics2;

    function setUp() public {
        d = deployDiamond(owner);
        ct = ClaimTopicsFacet(address(d.diamond));
        ac = AccessControlFacet(address(d.diamond));

        topics1 = new uint256[](2);
        topics1[0] = 1;
        topics1[1] = 2;

        topics2 = new uint256[](1);
        topics2[0] = 3;

        vm.prank(owner);
        ac.grantRole(CLAIM_ISSUER_ROLE, issuer);
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE PROFILE
    //////////////////////////////////////////////////////////////*/

    function test_CreateProfile_Owner() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);
        assertEq(id, 1);
    }

    function test_CreateProfile_Issuer() public {
        vm.prank(issuer);
        uint32 id = ct.createProfile(topics1);
        assertEq(id, 1);
    }

    function test_CreateProfile_AutoIncrements() public {
        vm.prank(owner);
        uint32 id1 = ct.createProfile(topics1);
        vm.prank(owner);
        uint32 id2 = ct.createProfile(topics2);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    function test_CreateProfile_SetsInitialVersion() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);
        assertEq(ct.getProfileVersion(id), 1);
    }

    function test_CreateProfile_StoresClaimTopics() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);
        uint256[] memory stored = ct.getProfileClaimTopics(id);
        assertEq(stored.length, topics1.length);
        assertEq(stored[0], topics1[0]);
        assertEq(stored[1], topics1[1]);
    }

    function test_RevertWhen_CreateProfile_EmptyTopics() public {
        uint256[] memory empty;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__EmptyClaimTopics()"));
        ct.createProfile(empty);
    }

    function test_RevertWhen_CreateProfile_Unauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__Unauthorized()"));
        ct.createProfile(topics1);
    }

    /*//////////////////////////////////////////////////////////////
                        SET PROFILE CLAIM TOPICS
    //////////////////////////////////////////////////////////////*/

    function test_SetProfileClaimTopics_BumpsVersion() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);
        uint64 vBefore = ct.getProfileVersion(id);

        vm.prank(owner);
        ct.setProfileClaimTopics(id, topics2);
        assertEq(ct.getProfileVersion(id), vBefore + 1);
    }

    function test_SetProfileClaimTopics_UpdatesTopics() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);

        vm.prank(issuer);
        ct.setProfileClaimTopics(id, topics2);
        uint256[] memory stored = ct.getProfileClaimTopics(id);
        assertEq(stored.length, 1);
        assertEq(stored[0], topics2[0]);
    }

    function test_RevertWhen_SetProfileClaimTopics_ProfileNotFound() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__ProfileNotFound(uint32)", 99));
        ct.setProfileClaimTopics(99, topics1);
    }

    function test_RevertWhen_SetProfileClaimTopics_EmptyTopics() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);

        uint256[] memory empty;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__EmptyClaimTopics()"));
        ct.setProfileClaimTopics(id, empty);
    }

    function test_RevertWhen_SetProfileClaimTopics_Unauthorized() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__Unauthorized()"));
        ct.setProfileClaimTopics(id, topics2);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_ProfileExists_True() public {
        vm.prank(owner);
        uint32 id = ct.createProfile(topics1);
        assertTrue(ct.profileExists(id));
    }

    function test_ProfileExists_False_Zero() public view {
        assertFalse(ct.profileExists(0));
    }

    function test_ProfileExists_False_OutOfRange() public view {
        assertFalse(ct.profileExists(999));
    }

    function test_RevertWhen_GetProfileClaimTopics_ProfileNotFound() public {
        vm.expectRevert(abi.encodeWithSignature("ClaimTopicsFacet__ProfileNotFound(uint32)", 0));
        ct.getProfileClaimTopics(0);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CreateProfile_TopicsStoredCorrectly(uint8 count) public {
        vm.assume(count > 0 && count <= 20);
        uint256[] memory topics = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            topics[i] = i + 1;
        }

        vm.prank(owner);
        uint32 id = ct.createProfile(topics);
        uint256[] memory stored = ct.getProfileClaimTopics(id);
        assertEq(stored.length, count);
    }
}
