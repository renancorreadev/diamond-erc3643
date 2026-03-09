// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamond.sol";

interface IOwnership {
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}

contract OwnershipFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IOwnership internal ownership;

    function setUp() public {
        d = deployDiamond(owner);
        ownership = IOwnership(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                                OWNER
    //////////////////////////////////////////////////////////////*/

    function test_OwnerSetOnDeploy() public view {
        assertEq(ownership.owner(), owner);
    }

    function test_PendingOwnerInitiallyZero() public view {
        assertEq(ownership.pendingOwner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER OWNERSHIP (2-STEP)
    //////////////////////////////////////////////////////////////*/

    function test_TransferOwnership_SetsPendingOwner() public {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        ownership.transferOwnership(nominee);
        assertEq(ownership.pendingOwner(), nominee);
        assertEq(ownership.owner(), owner); // still old owner
    }

    function test_TransferOwnership_EmitsEvent() public {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(d.diamond));
        emit OwnershipTransferStarted(owner, nominee);
        ownership.transferOwnership(nominee);
    }

    function test_RevertWhen_NonOwnerTransfers() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        ownership.transferOwnership(attacker);
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnershipFacet__ZeroAddress()"));
        ownership.transferOwnership(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        ACCEPT OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function test_AcceptOwnership_TransfersOwner() public {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        ownership.transferOwnership(nominee);

        vm.prank(nominee);
        ownership.acceptOwnership();

        assertEq(ownership.owner(), nominee);
        assertEq(ownership.pendingOwner(), address(0));
    }

    function test_AcceptOwnership_EmitsEvent() public {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        ownership.transferOwnership(nominee);

        vm.prank(nominee);
        vm.expectEmit(true, true, false, false, address(d.diamond));
        emit OwnershipTransferred(owner, nominee);
        ownership.acceptOwnership();
    }

    function test_RevertWhen_NonPendingOwnerAccepts() public {
        address nominee = makeAddr("nominee");
        address attacker = makeAddr("attacker");

        vm.prank(owner);
        ownership.transferOwnership(nominee);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("OwnershipFacet__NotPendingOwner()"));
        ownership.acceptOwnership();
    }

    function test_RevertWhen_AcceptWithoutPendingNomination() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("OwnershipFacet__NotPendingOwner()"));
        ownership.acceptOwnership();
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TransferAndAccept(address nominee) public {
        vm.assume(nominee != address(0));
        vm.assume(nominee != owner);
        vm.assume(nominee.code.length == 0);

        vm.prank(owner);
        ownership.transferOwnership(nominee);
        assertEq(ownership.pendingOwner(), nominee);

        vm.prank(nominee);
        ownership.acceptOwnership();
        assertEq(ownership.owner(), nominee);
        assertEq(ownership.pendingOwner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
