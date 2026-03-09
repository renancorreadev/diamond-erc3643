// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
}

interface IFreeze {
    function setWalletFrozen(address wallet, bool frozen) external;
    function setAssetWalletFrozen(uint256 tokenId, address wallet, bool frozen) external;
    function setFrozenAmount(uint256 tokenId, address wallet, uint256 amount) external;
    function setLockupExpiry(uint256 tokenId, address wallet, uint64 expiry) external;
    function isWalletFrozen(address wallet) external view returns (bool);
    function isAssetWalletFrozen(uint256 tokenId, address wallet) external view returns (bool);
    function getFrozenAmount(uint256 tokenId, address wallet) external view returns (uint256);
    function getLockupExpiry(uint256 tokenId, address wallet) external view returns (uint64);
}

contract FreezeFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IFreeze internal freeze;
    IAccessControl internal ac;

    bytes32 internal constant TRANSFER_AGENT = keccak256("TRANSFER_AGENT");

    address internal wallet = makeAddr("wallet");
    uint256 internal tokenId = 1;

    function setUp() public {
        d = deployDiamond(owner);
        freeze = IFreeze(address(d.diamond));
        ac = IAccessControl(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_WalletNotFrozenByDefault() public view {
        assertFalse(freeze.isWalletFrozen(wallet));
    }

    function test_AssetWalletNotFrozenByDefault() public view {
        assertFalse(freeze.isAssetWalletFrozen(tokenId, wallet));
    }

    function test_FrozenAmountZeroByDefault() public view {
        assertEq(freeze.getFrozenAmount(tokenId, wallet), 0);
    }

    function test_LockupExpiryZeroByDefault() public view {
        assertEq(freeze.getLockupExpiry(tokenId, wallet), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        GLOBAL WALLET FREEZE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanFreezeWallet() public {
        vm.prank(owner);
        freeze.setWalletFrozen(wallet, true);
        assertTrue(freeze.isWalletFrozen(wallet));
    }

    function test_OwnerCanUnfreezeWallet() public {
        vm.startPrank(owner);
        freeze.setWalletFrozen(wallet, true);
        freeze.setWalletFrozen(wallet, false);
        vm.stopPrank();
        assertFalse(freeze.isWalletFrozen(wallet));
    }

    function test_WalletFrozen_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(d.diamond));
        emit WalletFrozen(wallet, true);
        freeze.setWalletFrozen(wallet, true);
    }

    function test_TransferAgentCanFreezeWallet() public {
        address agent = makeAddr("agent");
        vm.prank(owner);
        ac.grantRole(TRANSFER_AGENT, agent);

        vm.prank(agent);
        freeze.setWalletFrozen(wallet, true);
        assertTrue(freeze.isWalletFrozen(wallet));
    }

    function test_RevertWhen_UnauthorizedFreezesWallet() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("FreezeFacet__Unauthorized()"));
        freeze.setWalletFrozen(wallet, true);
    }

    function test_RevertWhen_FreezeZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("FreezeFacet__ZeroAddress()"));
        freeze.setWalletFrozen(address(0), true);
    }

    /*//////////////////////////////////////////////////////////////
                    ASSET-LEVEL WALLET FREEZE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanFreezeAssetWallet() public {
        vm.prank(owner);
        freeze.setAssetWalletFrozen(tokenId, wallet, true);
        assertTrue(freeze.isAssetWalletFrozen(tokenId, wallet));
    }

    function test_AssetFrozen_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(d.diamond));
        emit AssetFrozen(tokenId, wallet, true);
        freeze.setAssetWalletFrozen(tokenId, wallet, true);
    }

    function test_AssetFreezeIsPerTokenId() public {
        uint256 tokenId2 = 2;
        vm.prank(owner);
        freeze.setAssetWalletFrozen(tokenId, wallet, true);
        assertFalse(freeze.isAssetWalletFrozen(tokenId2, wallet));
    }

    function test_RevertWhen_UnauthorizedFreezesAsset() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("FreezeFacet__Unauthorized()"));
        freeze.setAssetWalletFrozen(tokenId, wallet, true);
    }

    /*//////////////////////////////////////////////////////////////
                        PARTIAL FREEZE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetFrozenAmount() public {
        vm.prank(owner);
        freeze.setFrozenAmount(tokenId, wallet, 500);
        assertEq(freeze.getFrozenAmount(tokenId, wallet), 500);
    }

    function test_PartialFreeze_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(d.diamond));
        emit PartialFreeze(tokenId, wallet, 500);
        freeze.setFrozenAmount(tokenId, wallet, 500);
    }

    function test_SetFrozenAmount_OverwritesPrevious() public {
        vm.startPrank(owner);
        freeze.setFrozenAmount(tokenId, wallet, 500);
        freeze.setFrozenAmount(tokenId, wallet, 200);
        vm.stopPrank();
        assertEq(freeze.getFrozenAmount(tokenId, wallet), 200);
    }

    /*//////////////////////////////////////////////////////////////
                            LOCKUP
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetLockupExpiry() public {
        uint64 expiry = uint64(block.timestamp + 30 days);
        vm.prank(owner);
        freeze.setLockupExpiry(tokenId, wallet, expiry);
        assertEq(freeze.getLockupExpiry(tokenId, wallet), expiry);
    }

    function test_LockupSet_EmitsEvent() public {
        uint64 expiry = uint64(block.timestamp + 30 days);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(d.diamond));
        emit LockupSet(tokenId, wallet, expiry);
        freeze.setLockupExpiry(tokenId, wallet, expiry);
    }

    function test_RemoveLockup_SetExpiryToZero() public {
        uint64 expiry = uint64(block.timestamp + 30 days);
        vm.startPrank(owner);
        freeze.setLockupExpiry(tokenId, wallet, expiry);
        freeze.setLockupExpiry(tokenId, wallet, 0);
        vm.stopPrank();
        assertEq(freeze.getLockupExpiry(tokenId, wallet), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_FreezeAndUnfreezeWallet(address target) public {
        vm.assume(target != address(0));
        vm.assume(target.code.length == 0);

        vm.startPrank(owner);
        freeze.setWalletFrozen(target, true);
        assertTrue(freeze.isWalletFrozen(target));
        freeze.setWalletFrozen(target, false);
        assertFalse(freeze.isWalletFrozen(target));
        vm.stopPrank();
    }

    function testFuzz_SetFrozenAmount(uint256 amount) public {
        vm.prank(owner);
        freeze.setFrozenAmount(tokenId, wallet, amount);
        assertEq(freeze.getFrozenAmount(tokenId, wallet), amount);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event WalletFrozen(address indexed wallet, bool frozen);
    event AssetFrozen(uint256 indexed tokenId, address indexed wallet, bool frozen);
    event PartialFreeze(uint256 indexed tokenId, address indexed wallet, uint256 amount);
    event LockupSet(uint256 indexed tokenId, address indexed wallet, uint64 expiry);
}
