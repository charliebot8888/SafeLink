// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISafeEscrow — Task escrow with proof-gated release
interface ISafeEscrow {
    // ── Enums ─────────────────────────────────────────────────────────────────

    enum Status {
        Active,
        Released,
        Refunded
    }

    // ── Structs ───────────────────────────────────────────────────────────────

    struct EscrowRecord {
        address hirer;
        address agent;
        uint256 amount;            // USDC atomic units
        bytes32 taskHash;          // keccak256(taskDescription)
        bytes32 proofCommitment;   // keccak256(sessionId, agentAddress) — committed at deposit
        Status status;
        uint256 createdAt;
        uint256 expiresAt;
    }

    // ── Events ────────────────────────────────────────────────────────────────

    event EscrowDeposited(
        bytes32 indexed escrowId,
        address indexed hirer,
        address indexed agent,
        uint256 amount,
        bytes32 taskHash,
        uint256 expiresAt
    );

    event EscrowReleased(
        bytes32 indexed escrowId,
        address indexed agent,
        uint256 amount,
        bytes32 proofHash
    );

    event EscrowRefunded(
        bytes32 indexed escrowId,
        address indexed hirer,
        uint256 amount
    );

    // ── Functions ─────────────────────────────────────────────────────────────

    /// @notice Deposit USDC into escrow for a task.
    /// @param agent             Target agent address.
    /// @param taskHash          keccak256 of the task description.
    /// @param proofCommitment   keccak256(abi.encodePacked(sessionId, agentAddress))
    ///                          computed by the hirer before task delivery.
    /// @param amount            USDC amount in 6-decimal atomic units.
    /// @param durationSeconds   How long before hirer can refund (task timeout).
    /// @return escrowId         Unique identifier for this escrow record.
    function deposit(
        address agent,
        bytes32 taskHash,
        bytes32 proofCommitment,
        uint256 amount,
        uint256 durationSeconds
    ) external returns (bytes32 escrowId);

    /// @notice Release escrowed funds to agent after verifying proof.
    /// @param escrowId  The escrow to release.
    /// @param proofHash keccak256(sessionId + agentAddress) provided by the agent.
    function release(bytes32 escrowId, bytes32 proofHash) external;

    /// @notice Refund escrowed funds to hirer (callable after expiry or by hirer on failure).
    function refund(bytes32 escrowId) external;

    /// @notice Get the full escrow record.
    function getEscrow(bytes32 escrowId) external view returns (EscrowRecord memory);
}
