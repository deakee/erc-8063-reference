// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC8063.sol";
import "../src/IERC8063.sol";

/// @title ERC8063 reference implementation tests
/// @dev Run with: forge test -vv
contract ERC8063Test is Test {
    ERC8063 internal token;

    address internal owner   = address(0xA11CE);
    address internal alice   = address(0xA1);
    address internal bob     = address(0xB2);
    address internal stranger = address(0xC3);

    uint256 internal constant INITIAL = 1_000_000 ether; // 1M with 18 decimals

    function setUp() public {
        vm.prank(owner);
        token = new ERC8063("Deakee Group", "DKG", 18, INITIAL);
    }

    // ── ERC-20 sanity ────────────────────────────────────────────────────

    function test_name_symbol_decimals_supply() public {
        assertEq(token.name(), "Deakee Group");
        assertEq(token.symbol(), "DKG");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL);
        assertEq(token.balanceOf(owner), INITIAL);
    }

    function test_transfer_moves_balance() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertEq(token.balanceOf(owner), INITIAL - 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function test_approve_and_transferFrom() public {
        vm.prank(owner);
        token.approve(bob, 50 ether);
        assertEq(token.allowance(owner, bob), 50 ether);

        vm.prank(bob);
        token.transferFrom(owner, alice, 30 ether);
        assertEq(token.balanceOf(alice), 30 ether);
        assertEq(token.allowance(owner, bob), 20 ether);
    }

    function test_transfer_to_zero_reverts() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Transfer to zero"));
        token.transfer(address(0), 1 ether);
    }

    function test_transfer_insufficient_balance_reverts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Insufficient balance"));
        token.transfer(bob, 1 ether);
    }

    // ── IERC8063 — the canonical method ──────────────────────────────────

    function test_isMember_returns_false_for_zero_balance() public {
        assertFalse(token.isMember(stranger, 1));
    }

    function test_isMember_returns_true_at_threshold() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertTrue(token.isMember(alice, 100 ether));
        assertTrue(token.isMember(alice, 1 ether));
        assertFalse(token.isMember(alice, 101 ether));
    }

    function test_isMember_at_exact_boundary() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        // Exactly at threshold — true (>= comparison per spec)
        assertTrue(token.isMember(alice, 100 ether));
        // 1 wei above — false
        assertFalse(token.isMember(alice, 100 ether + 1));
    }

    function test_isMember_zero_threshold_always_true() public {
        // Per spec: threshold of 0 = anyone is a "member"
        // (which is the same as saying there's no gate at all)
        assertTrue(token.isMember(alice, 0));
        assertTrue(token.isMember(stranger, 0));
    }

    function test_isMember_updates_after_transfer() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertTrue(token.isMember(alice, 100 ether));

        vm.prank(alice);
        token.transfer(bob, 50 ether);
        assertFalse(token.isMember(alice, 100 ether));
        assertTrue(token.isMember(alice, 50 ether));
        assertTrue(token.isMember(bob, 50 ether));
    }

    // ── ERC-165 interface detection ──────────────────────────────────────

    function test_supportsInterface_erc8063() public {
        bytes4 id = type(IERC8063).interfaceId;
        assertTrue(token.supportsInterface(id));
    }

    function test_supportsInterface_erc165() public {
        // ERC-165 itself
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    function test_supportsInterface_garbage_returns_false() public {
        assertFalse(token.supportsInterface(0xdeadbeef));
    }

    // ── Mint / burn ──────────────────────────────────────────────────────

    function test_mint_only_owner() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Not owner"));
        token.mint(stranger, 1 ether);
    }

    function test_mint_increases_supply_and_balance() public {
        vm.prank(owner);
        token.mint(alice, 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.totalSupply(), INITIAL + 500 ether);
    }

    function test_burn_self_allowed() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);

        vm.prank(alice);
        token.burn(alice, 30 ether);
        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(token.totalSupply(), INITIAL - 30 ether);
    }

    function test_burn_stranger_blocked() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);

        vm.prank(stranger);
        vm.expectRevert(bytes("Not authorized"));
        token.burn(alice, 30 ether);
    }

    function test_burn_owner_can_burn_any_account() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);

        vm.prank(owner);
        token.burn(alice, 30 ether);
        assertEq(token.balanceOf(alice), 70 ether);
    }

    // ── Ownership transfer ───────────────────────────────────────────────

    function test_transferOwnership_only_owner() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Not owner"));
        token.transferOwnership(stranger);
    }

    function test_transferOwnership_moves_role() public {
        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);

        // Old owner can't mint anymore
        vm.prank(owner);
        vm.expectRevert(bytes("Not owner"));
        token.mint(owner, 1 ether);

        // New owner can
        vm.prank(alice);
        token.mint(alice, 1 ether);
    }

    // ── Fuzz ─────────────────────────────────────────────────────────────

    function testFuzz_isMember_matches_balance(uint256 mintAmount, uint256 threshold) public {
        vm.assume(mintAmount < type(uint128).max);
        vm.prank(owner);
        token.mint(alice, mintAmount);
        assertEq(token.isMember(alice, threshold), mintAmount >= threshold);
    }
}
