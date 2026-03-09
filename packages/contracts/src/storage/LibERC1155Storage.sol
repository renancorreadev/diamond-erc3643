// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

/// @dev Sub-balance partitions per holder per tokenId.
///      Replaces binary freeze with four semantic partitions aligned
///      with RWA settlement and custody workflows.
struct PartitionBalance {
    uint256 free;              // freely transferable
    uint256 locked;            // frozen / restricted by compliance
    uint256 custody;           // held by an authorised custodian
    uint256 pendingSettlement; // DVP: awaiting settlement confirmation
}

struct ERC1155Storage {
    /// tokenId => holder => partition balances
    mapping(uint256 => mapping(address => PartitionBalance)) partitions;
    /// owner => operator => approved
    mapping(address => mapping(address => bool)) operatorApprovals;
}

/// @title LibERC1155Storage
/// @notice Namespaced ERC-1155 storage for the Diamond.
///         slot = keccak256("diamond.rwa.erc1155.storage") - 1
library LibERC1155Storage {
    bytes32 internal constant POSITION =
        0xfa7964d34d14df8c2bc86a420d87e49e27dbfab86f789b31f9dd2373beee6837;

    function layout() internal pure returns (ERC1155Storage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
