// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";

interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role) external;
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;
}

contract AccessControlFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IAccessControl internal ac;

    bytes32 internal constant GOVERNANCE_ROLE  = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant UPGRADER_ROLE    = keccak256("UPGRADER_ROLE");
    bytes32 internal constant PAUSER_ROLE      = keccak256("PAUSER_ROLE");
    bytes32 internal constant ISSUER_ROLE      = keccak256("ISSUER_ROLE");
    bytes32 internal constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");
    bytes32 internal constant TRANSFER_AGENT   = keccak256("TRANSFER_AGENT");
    bytes32 internal constant RECOVERY_AGENT   = keccak256("RECOVERY_AGENT");
    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    function setUp() public {
        d = deployDiamond(owner);
        ac = IAccessControl(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_NoRolesGrantedByDefault() public view {
        assertFalse(ac.hasRole(PAUSER_ROLE, owner));
        assertFalse(ac.hasRole(ISSUER_ROLE, owner));
        assertFalse(ac.hasRole(TRANSFER_AGENT, owner));
    }

    function test_RoleAdminDefaultIsZero() public view {
        assertEq(ac.getRoleAdmin(PAUSER_ROLE), bytes32(0));
        assertEq(ac.getRoleAdmin(ISSUER_ROLE), bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                            GRANT ROLE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanGrantAnyRole() public {
        address account = makeAddr("account");
        bytes32[8] memory roles = [
            GOVERNANCE_ROLE, UPGRADER_ROLE, PAUSER_ROLE, ISSUER_ROLE,
            COMPLIANCE_ADMIN, TRANSFER_AGENT, RECOVERY_AGENT, CLAIM_ISSUER_ROLE
        ];
        for (uint256 i; i < roles.length; ++i) {
            vm.prank(owner);
            ac.grantRole(roles[i], account);
            assertTrue(ac.hasRole(roles[i], account));
        }
    }

    function test_GrantRole_EmitsEvent() public {
        address agent = makeAddr("agent");
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(d.diamond));
        emit RoleGranted(TRANSFER_AGENT, agent, owner);
        ac.grantRole(TRANSFER_AGENT, agent);
    }

    function test_GrantRole_Idempotent() public {
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);
        ac.grantRole(TRANSFER_AGENT, agent);
        vm.stopPrank();
        assertTrue(ac.hasRole(TRANSFER_AGENT, agent));
    }

    function test_RevertWhen_UnauthorizedGrantsRole() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlFacet__RoleAdminOnly(bytes32,address)", PAUSER_ROLE, attacker
            )
        );
        ac.grantRole(PAUSER_ROLE, attacker);
    }

    function test_RevertWhen_GrantRoleToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("AccessControlFacet__ZeroAddress()"));
        ac.grantRole(PAUSER_ROLE, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            REVOKE ROLE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanRevokeRole() public {
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);
        ac.revokeRole(TRANSFER_AGENT, agent);
        vm.stopPrank();
        assertFalse(ac.hasRole(TRANSFER_AGENT, agent));
    }

    function test_RevokeRole_EmitsEvent() public {
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);
        vm.expectEmit(true, true, true, false, address(d.diamond));
        emit RoleRevoked(TRANSFER_AGENT, agent, owner);
        ac.revokeRole(TRANSFER_AGENT, agent);
        vm.stopPrank();
    }

    function test_RevokeRole_Idempotent() public {
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);
        ac.revokeRole(TRANSFER_AGENT, agent);
        ac.revokeRole(TRANSFER_AGENT, agent);
        vm.stopPrank();
        assertFalse(ac.hasRole(TRANSFER_AGENT, agent));
    }

    function test_RevertWhen_UnauthorizedRevokesRole() public {
        address agent = makeAddr("agent");
        address attacker = makeAddr("attacker");
        vm.prank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlFacet__RoleAdminOnly(bytes32,address)", TRANSFER_AGENT, attacker
            )
        );
        ac.revokeRole(TRANSFER_AGENT, agent);
    }

    /*//////////////////////////////////////////////////////////////
                            RENOUNCE ROLE
    //////////////////////////////////////////////////////////////*/

    function test_HolderCanRenounceOwnRole() public {
        address agent = makeAddr("agent");
        vm.prank(owner);
        ac.grantRole(PAUSER_ROLE, agent);

        vm.prank(agent);
        ac.renounceRole(PAUSER_ROLE);
        assertFalse(ac.hasRole(PAUSER_ROLE, agent));
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE ADMIN DELEGATION
    //////////////////////////////////////////////////////////////*/

    function test_SetRoleAdmin_AllowsDelegatedAdminToGrant() public {
        address admin = makeAddr("admin");
        address newPauser = makeAddr("newPauser");

        vm.startPrank(owner);
        ac.grantRole(GOVERNANCE_ROLE, admin);
        ac.setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        vm.stopPrank();

        vm.prank(admin);
        ac.grantRole(PAUSER_ROLE, newPauser);
        assertTrue(ac.hasRole(PAUSER_ROLE, newPauser));
    }

    function test_SetRoleAdmin_EmitsRoleAdminChanged() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(d.diamond));
        emit RoleAdminChanged(PAUSER_ROLE, bytes32(0), GOVERNANCE_ROLE);
        ac.setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
    }

    function test_RevertWhen_NonOwnerSetsRoleAdmin() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        ac.setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_GrantAndRevokeRole(address account) public {
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);

        vm.startPrank(owner);
        ac.grantRole(ISSUER_ROLE, account);
        assertTrue(ac.hasRole(ISSUER_ROLE, account));
        ac.revokeRole(ISSUER_ROLE, account);
        assertFalse(ac.hasRole(ISSUER_ROLE, account));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdmin, bytes32 indexed newAdmin);
}
