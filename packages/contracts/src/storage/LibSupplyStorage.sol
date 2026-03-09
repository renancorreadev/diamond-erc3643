// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

struct SupplyStorage {
    /// tokenId → total minted supply
    mapping(uint256 => uint256) totalSupply;
    /// tokenId → unique holder count
    mapping(uint256 => uint256) holderCount;
    /// tokenId → holder → has non-zero balance (for holderCount tracking)
    mapping(uint256 => mapping(address => bool)) isHolder;
}

/// @title LibSupplyStorage
/// @notice Namespaced supply tracking storage for the Diamond.
///         slot = keccak256("diamond.rwa.supply.storage") - 1
library LibSupplyStorage {
    bytes32 internal constant POSITION =
        0x46830504cc643be957af372bc50edfbfbf33b72cb2c5f2919048fc26e5d225bb;

    function layout() internal pure returns (SupplyStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
