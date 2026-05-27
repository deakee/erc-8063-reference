// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../src/IERC8063.sol";

/// @title CrossGroupBundle — require membership in MULTIPLE groups simultaneously
/// @notice The interesting composition: a service gated by holding tokens in
///         several groups at once. Demonstrates that ERC-8063 composes
///         trivially (just AND/OR balance checks), unlike soulbound or
///         allowlist-based access systems.
///
/// Use case: a partnership reward only available to customers who have
/// shopped at BOTH Brand A and Brand B in the Deakee network. Both groups
/// must satisfy their threshold for the bundle to unlock.
contract CrossGroupBundle {
    struct GroupRequirement {
        IERC8063 group;
        uint256 threshold;
    }

    GroupRequirement[] public required;

    constructor(GroupRequirement[] memory groups) {
        require(groups.length > 0, "No groups");
        for (uint256 i = 0; i < groups.length; i++) {
            require(address(groups[i].group) != address(0), "Zero group");
            required.push(groups[i]);
        }
    }

    /// @notice True iff account meets ALL group thresholds
    function isQualified(address account) public view returns (bool) {
        for (uint256 i = 0; i < required.length; i++) {
            if (!required[i].group.isMember(account, required[i].threshold)) {
                return false;
            }
        }
        return true;
    }

    /// @notice True iff account meets at least ONE group threshold (OR semantics)
    function isQualifiedAny(address account) external view returns (bool) {
        for (uint256 i = 0; i < required.length; i++) {
            if (required[i].group.isMember(account, required[i].threshold)) {
                return true;
            }
        }
        return false;
    }

    function requirementCount() external view returns (uint256) {
        return required.length;
    }
}
