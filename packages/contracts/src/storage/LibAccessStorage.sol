// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

struct AccessStorage {
    /// role → account → has role
    mapping(bytes32 => mapping(address => bool)) roles;
    /// role → admin role (controls who can grant/revoke)
    mapping(bytes32 => bytes32) roleAdmin;
}

/// @title LibAccessStorage
/// @notice Namespaced role-based access control storage for the Diamond.
///         slot = keccak256("diamond.rwa.access.storage") - 1
library LibAccessStorage {
    bytes32 internal constant POSITION =
        0xd243a54eb63068fbcd3b75bed7e8048bd76bf590c2627f5dd4b1909b9ae4cb5a;

    function layout() internal pure returns (AccessStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
