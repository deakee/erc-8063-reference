// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../src/IERC8063.sol";

/// @title GroupGate — restrict function access to members of an ERC-8063 group
/// @notice The simplest possible application of ERC-8063: gate a function
///         so only addresses with ≥ threshold balance can call it.
/// @dev Drop-in inheritance pattern, like OpenZeppelin's `Ownable` but
///      backed by token balance instead of a single address.
///
/// Example usage:
///
///   contract MyPremiumFeature is GroupGate {
///       constructor(address groupToken, uint256 threshold)
///           GroupGate(groupToken, threshold) {}
///
///       function premiumAction() external onlyMember {
///           // Only callable by accounts holding ≥ threshold of the group token
///       }
///   }
///
abstract contract GroupGate {
    IERC8063 public immutable groupToken;
    uint256 public immutable membershipThreshold;

    error NotAMember(address account, uint256 required);

    modifier onlyMember() {
        if (!groupToken.isMember(msg.sender, membershipThreshold)) {
            revert NotAMember(msg.sender, membershipThreshold);
        }
        _;
    }

    constructor(address token, uint256 threshold) {
        require(token != address(0), "GroupGate: zero token");
        groupToken = IERC8063(token);
        membershipThreshold = threshold;
    }
}
