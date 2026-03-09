// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

struct FreezeStorage {
    /// wallet → frozen across ALL assets
    mapping(address => bool) globalFreeze;
    /// tokenId → wallet → frozen for THIS asset only
    mapping(uint256 => mapping(address => bool)) assetFreeze;
    /// tokenId → wallet → amount frozen within the free partition
    mapping(uint256 => mapping(address => uint256)) frozenAmount;
    /// tokenId → wallet → lockup expiry unix timestamp (0 = no lockup)
    mapping(uint256 => mapping(address => uint64)) lockupExpiry;
}

/// @title LibFreezeStorage
/// @notice Namespaced freeze and lockup storage for the Diamond.
///         slot = keccak256("diamond.rwa.freeze.storage") - 1
library LibFreezeStorage {
    bytes32 internal constant POSITION =
        0x816ddc8ce7b7a63b00e3aba2be8d7cda4caf59ac1130e1bde05d22df1dd742a4;

    function layout() internal pure returns (FreezeStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
