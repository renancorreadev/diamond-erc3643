// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IComplianceModule} from "../../src/interfaces/compliance/IComplianceModule.sol";

/// @dev Mock compliance module for testing ComplianceRouterFacet.
///      Returns configurable (ok, reason) values and tracks hook calls.
contract MockComplianceModule is IComplianceModule {
    bool public returnOk = true;
    bytes32 public returnReason;

    uint256 public transferredCount;
    uint256 public mintedCount;
    uint256 public burnedCount;

    function setResult(bool ok_, bytes32 reason_) external {
        returnOk = ok_;
        returnReason = reason_;
    }

    function canTransfer(uint256, address, address, uint256, bytes calldata)
        external
        view
        returns (bool ok, bytes32 reason)
    {
        ok = returnOk;
        reason = returnReason;
    }

    function transferred(uint256, address, address, uint256) external {
        ++transferredCount;
    }

    function minted(uint256, address, uint256) external {
        ++mintedCount;
    }

    function burned(uint256, address, uint256) external {
        ++burnedCount;
    }
}
