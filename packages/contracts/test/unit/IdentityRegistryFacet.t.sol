// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {ClaimTopicsFacet} from "../../src/facets/identity/ClaimTopicsFacet.sol";
import {IdentityRegistryFacet} from "../../src/facets/identity/IdentityRegistryFacet.sol";
import {AccessControlFacet} from "../../src/facets/security/AccessControlFacet.sol";

contract IdentityRegistryFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    address internal agent = makeAddr("agent");
    address internal stranger = makeAddr("stranger");

    address internal wallet = makeAddr("wallet");
    address internal identity = makeAddr("identity");

    ClaimTopicsFacet internal ct;
    IdentityRegistryFacet internal ir;
    AccessControlFacet internal ac;

    bytes32 internal constant TRANSFER_AGENT = keccak256("TRANSFER_AGENT");
    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    uint32 internal profileId;

    function setUp() public {
        d = deployDiamond(owner);
        ct = ClaimTopicsFacet(address(d.diamond));
        ir = IdentityRegistryFacet(address(d.diamond));
        ac = AccessControlFacet(address(d.diamond));

        vm.prank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);

        uint256[] memory topics = new uint256[](1);
        topics[0] = 1;
        vm.prank(owner);
        profileId = ct.createProfile(topics);
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTER IDENTITY
    //////////////////////////////////////////////////////////////*/

    function test_RegisterIdentity_Owner() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);
        assertEq(ir.getIdentity(wallet), identity);
        assertEq(ir.getCountry(wallet), 840);
    }

    function test_RegisterIdentity_Agent() public {
        vm.prank(agent);
        ir.registerIdentity(wallet, identity, 76);
        assertEq(ir.getIdentity(wallet), identity);
    }

    function test_RegisterIdentity_Contains() public {
        assertFalse(ir.contains(wallet));
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);
        assertTrue(ir.contains(wallet));
    }

    function test_RevertWhen_RegisterIdentity_ZeroWallet() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__ZeroAddress()"));
        ir.registerIdentity(address(0), identity, 840);
    }

    function test_RevertWhen_RegisterIdentity_ZeroIdentity() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__ZeroAddress()"));
        ir.registerIdentity(wallet, address(0), 840);
    }

    function test_RevertWhen_RegisterIdentity_AlreadyRegistered() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__AlreadyRegistered(address)", wallet));
        ir.registerIdentity(wallet, identity, 840);
    }

    function test_RevertWhen_RegisterIdentity_Unauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__Unauthorized()"));
        ir.registerIdentity(wallet, identity, 840);
    }

    /*//////////////////////////////////////////////////////////////
                        DELETE IDENTITY
    //////////////////////////////////////////////////////////////*/

    function test_DeleteIdentity() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        vm.prank(owner);
        ir.deleteIdentity(wallet);
        assertEq(ir.getIdentity(wallet), address(0));
        assertFalse(ir.contains(wallet));
    }

    function test_RevertWhen_DeleteIdentity_NotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__NotRegistered(address)", wallet));
        ir.deleteIdentity(wallet);
    }

    function test_RevertWhen_DeleteIdentity_Unauthorized() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__Unauthorized()"));
        ir.deleteIdentity(wallet);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE IDENTITY
    //////////////////////////////////////////////////////////////*/

    function test_UpdateIdentity() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        address newIdentity = makeAddr("newIdentity");
        vm.prank(owner);
        ir.updateIdentity(wallet, newIdentity);
        assertEq(ir.getIdentity(wallet), newIdentity);
    }

    function test_RevertWhen_UpdateIdentity_ZeroIdentity() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__ZeroAddress()"));
        ir.updateIdentity(wallet, address(0));
    }

    function test_RevertWhen_UpdateIdentity_NotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__NotRegistered(address)", wallet));
        ir.updateIdentity(wallet, identity);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE COUNTRY
    //////////////////////////////////////////////////////////////*/

    function test_UpdateCountry() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        vm.prank(owner);
        ir.updateCountry(wallet, 76);
        assertEq(ir.getCountry(wallet), 76);
    }

    function test_RevertWhen_UpdateCountry_NotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__NotRegistered(address)", wallet));
        ir.updateCountry(wallet, 76);
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH REGISTER IDENTITY
    //////////////////////////////////////////////////////////////*/

    function test_BatchRegisterIdentity() public {
        address w1 = makeAddr("w1");
        address w2 = makeAddr("w2");
        address id1 = makeAddr("id1");
        address id2 = makeAddr("id2");

        address[] memory wallets = new address[](2);
        wallets[0] = w1;
        wallets[1] = w2;

        address[] memory ids = new address[](2);
        ids[0] = id1;
        ids[1] = id2;

        uint16[] memory countries = new uint16[](2);
        countries[0] = 840;
        countries[1] = 76;

        vm.prank(owner);
        ir.batchRegisterIdentity(wallets, ids, countries);

        assertEq(ir.getIdentity(w1), id1);
        assertEq(ir.getIdentity(w2), id2);
        assertEq(ir.getCountry(w1), 840);
        assertEq(ir.getCountry(w2), 76);
    }

    function test_RevertWhen_BatchRegisterIdentity_ArrayLengthMismatch() public {
        address[] memory wallets = new address[](2);
        address[] memory ids = new address[](1);
        uint16[] memory countries = new uint16[](2);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("IdentityRegistryFacet__ArrayLengthMismatch()"));
        ir.batchRegisterIdentity(wallets, ids, countries);
    }

    /*//////////////////////////////////////////////////////////////
                        IS VERIFIED (CACHE)
    //////////////////////////////////////////////////////////////*/

    function test_IsVerified_False_NotRegistered() public {
        bool v = ir.isVerified(wallet, profileId);
        assertFalse(v);
    }

    function test_IsVerified_False_InvalidProfile() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);
        assertFalse(ir.isVerified(wallet, 0));
        assertFalse(ir.isVerified(wallet, 999));
    }

    function test_IsVerified_True_RegisteredWithValidProfile() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);
        assertTrue(ir.isVerified(wallet, profileId));
    }

    function test_IsVerified_CacheHit_ReturnsSameResult() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        bool first = ir.isVerified(wallet, profileId);
        bool second = ir.isVerified(wallet, profileId);
        assertEq(first, second);
    }

    function test_IsVerified_CacheInvalidated_AfterDeleteIdentity() public {
        vm.prank(owner);
        ir.registerIdentity(wallet, identity, 840);

        assertTrue(ir.isVerified(wallet, profileId));

        vm.prank(owner);
        ir.deleteIdentity(wallet);

        assertFalse(ir.isVerified(wallet, profileId));
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RegisterAndContains(address w, address id, uint16 country) public {
        vm.assume(w != address(0) && id != address(0));

        vm.prank(owner);
        ir.registerIdentity(w, id, country);
        assertTrue(ir.contains(w));
        assertEq(ir.getIdentity(w), id);
        assertEq(ir.getCountry(w), country);
    }
}
