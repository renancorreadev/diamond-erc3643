// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

struct ComplianceStorage {
    /// tokenId → compliance module address
    mapping(uint256 => address) tokenModule;
    /// registered module addresses
    mapping(address => bool) registeredModules;
}

/// @title LibComplianceStorage
/// @notice Namespaced compliance routing storage for the Diamond.
///         slot = keccak256("diamond.rwa.compliance.storage") - 1
library LibComplianceStorage {
    bytes32 internal constant POSITION =
        0x6b502ce75824dd1c89ed4f44589fce210e1cbc92ddffac6021b7a14f73382a47;

    function layout() internal pure returns (ComplianceStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
