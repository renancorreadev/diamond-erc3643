// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibAccessStorage, AccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error AccessControlFacet__ZeroAddress();
error AccessControlFacet__RoleAdminOnly(bytes32 role, address account);

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title AccessControlFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Role-based access control for the Diamond.
///         Roles defined here are reused by all other facets.
///         The Diamond owner is the implicit super-admin.
/// @custom:security-contact renan.correa@hubweb3.com
contract AccessControlFacet {
    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Can propose diamondCut — must be a multisig + timelock in production.
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    /// @notice Can propose facet upgrades.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Can pause/unpause globally and per-asset.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Can mint/burn/forcedTransfer for a given asset.
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    /// @notice Can register and change compliance modules.
    bytes32 public constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");
    /// @notice Can execute forced transfers.
    bytes32 public constant TRANSFER_AGENT = keccak256("TRANSFER_AGENT");
    /// @notice Can execute wallet recovery and reissue.
    bytes32 public constant RECOVERY_AGENT = keccak256("RECOVERY_AGENT");
    /// @notice Can add/remove trusted claim issuers from identity profiles.
    bytes32 public constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdmin, bytes32 indexed newAdmin);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants `role` to `account`. Caller must hold the role's admin role
    ///         or be the Diamond owner.
    function grantRole(bytes32 role, address account) external {
        _enforceRoleAdmin(role);
        if (account == address(0)) revert AccessControlFacet__ZeroAddress();
        _grantRole(role, account);
    }

    /// @notice Revokes `role` from `account`. Caller must hold the role's admin role
    ///         or be the Diamond owner.
    function revokeRole(bytes32 role, address account) external {
        _enforceRoleAdmin(role);
        _revokeRole(role, account);
    }

    /// @notice Renounces `role` from the caller's own account.
    function renounceRole(bytes32 role) external {
        _revokeRole(role, msg.sender);
    }

    /// @notice Changes which role administers `role`. Only Diamond owner can call.
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external {
        LibDiamond.enforceIsContractOwner();
        AccessStorage storage s = LibAccessStorage.layout();
        bytes32 previous = s.roleAdmin[role];
        s.roleAdmin[role] = adminRole;
        emit RoleAdminChanged(role, previous, adminRole);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if `account` holds `role`.
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return LibAccessStorage.layout().roles[role][account];
    }

    /// @notice Returns the admin role that controls `role`.
    function getRoleAdmin(bytes32 role) external view returns (bytes32) {
        return LibAccessStorage.layout().roleAdmin[role];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _grantRole(bytes32 role, address account) internal {
        AccessStorage storage s = LibAccessStorage.layout();
        if (!s.roles[role][account]) {
            s.roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        AccessStorage storage s = LibAccessStorage.layout();
        if (s.roles[role][account]) {
            s.roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function _enforceRoleAdmin(bytes32 role) internal view {
        AccessStorage storage s = LibAccessStorage.layout();
        bytes32 adminRole = s.roleAdmin[role];
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool hasAdminRole = s.roles[adminRole][msg.sender];
        if (!isOwner && !hasAdminRole) {
            revert AccessControlFacet__RoleAdminOnly(role, msg.sender);
        }
    }
}
