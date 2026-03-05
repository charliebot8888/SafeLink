// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC8004 — On-chain Agent Identity and Capability Registry
/// @notice Interface for registering AI agents with capabilities, rates, and reputation.
/// @dev ERC-8004 is a working draft spec. This interface is SafeChainAgent's canonical
///      implementation until a finalized EIP exists.
interface IERC8004 {
    // ── Structs ──────────────────────────────────────────────────────────────

    struct AgentRecord {
        address owner;
        string[] capabilities;
        uint256 minRate;         // USDC in 6-decimal atomic units
        bytes policy;            // ABI-encoded policy object
        uint256 reputation;      // 0–100 score (updated by escrow on task completion)
        uint256 registeredAt;    // block.timestamp
        bool active;
    }

    // ── Events ────────────────────────────────────────────────────────────────

    event AgentRegistered(
        address indexed agentId,
        address indexed owner,
        string[] capabilities,
        uint256 minRate
    );

    event AgentDeactivated(address indexed agentId);

    event CapabilitiesUpdated(address indexed agentId, string[] capabilities);

    event ReputationUpdated(
        address indexed agentId,
        uint256 oldScore,
        uint256 newScore,
        address updatedBy
    );

    // ── Functions ─────────────────────────────────────────────────────────────

    /// @notice Register this caller as an agent with capabilities and rate.
    /// @param capabilities  Array of capability strings.
    /// @param minRate       Minimum USDC (6-decimal) per operation.
    /// @param policy        ABI-encoded policy object.
    /// @return agentId      The caller's address, used as the unique agent identifier.
    function register(
        string[] calldata capabilities,
        uint256 minRate,
        bytes calldata policy
    ) external returns (address agentId);

    /// @notice Get the full record for a registered agent.
    function getAgent(address agentId) external view returns (AgentRecord memory);

    /// @notice Update capabilities for the caller's registered agent.
    function updateCapabilities(string[] calldata capabilities) external;

    /// @notice Deactivate the caller's agent (can be reactivated by re-registering).
    function deactivate() external;

    /// @notice Update reputation score. Only callable by the escrow contract.
    function updateReputation(address agentId, uint256 newScore) external;

    /// @notice Check if an address is a registered, active agent.
    function isActive(address agentId) external view returns (bool);
}
