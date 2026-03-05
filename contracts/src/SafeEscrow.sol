// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ISafeEscrow.sol";
import "./interfaces/IERC8004.sol";

/// @title SafeEscrow — Task escrow with proof-gated release and reputation updates
/// @notice USDC is held in escrow until the hired agent provides the exact proof hash
///         that was committed at deposit time (keccak256(sessionId, agentAddress)).
///         On release, updates the agent's reputation in ERC8004Registry (+5 pts, max 100).
///         On refund (timeout or failure), updates reputation (-5 pts, min 0).
contract SafeEscrow is ISafeEscrow {
    // ── Constants ─────────────────────────────────────────────────────────────

    /// @notice Minimum escrow duration: 60 seconds.
    uint256 public constant MIN_DURATION = 60;

    /// @notice Maximum escrow duration: 24 hours.
    uint256 public constant MAX_DURATION = 86_400;

    // ── State ─────────────────────────────────────────────────────────────────

    mapping(bytes32 => EscrowRecord) private _escrows;

    /// @notice USDC token contract (6 decimals).
    address public immutable usdc;

    /// @notice ERC8004Registry for reputation updates.
    address public immutable registry;

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor(address _usdc, address _registry) {
        require(_usdc != address(0), "SafeEscrow: zero usdc address");
        require(_registry != address(0), "SafeEscrow: zero registry address");
        usdc = _usdc;
        registry = _registry;
    }

    // ── ISafeEscrow implementation ────────────────────────────────────────────

    function deposit(
        address agent,
        bytes32 taskHash,
        bytes32 proofCommitment,
        uint256 amount,
        uint256 durationSeconds
    ) external returns (bytes32 escrowId) {
        require(agent != address(0), "SafeEscrow: zero agent address");
        require(agent != msg.sender, "SafeEscrow: cannot hire yourself");
        require(amount > 0, "SafeEscrow: amount must be > 0");
        require(proofCommitment != bytes32(0), "SafeEscrow: zero proof commitment");
        require(
            durationSeconds >= MIN_DURATION && durationSeconds <= MAX_DURATION,
            "SafeEscrow: invalid duration"
        );

        // Verify agent is registered and active
        require(
            IERC8004(registry).isActive(agent),
            "SafeEscrow: agent not registered or inactive"
        );

        // Pull USDC from hirer (requires prior approval)
        _transferFrom(msg.sender, address(this), amount);

        // Generate deterministic escrow ID (proofCommitment included to prevent collisions)
        escrowId = keccak256(
            abi.encode(msg.sender, agent, taskHash, proofCommitment, block.timestamp, amount)
        );

        require(
            _escrows[escrowId].hirer == address(0),
            "SafeEscrow: escrow ID collision"
        );

        uint256 expiresAt = block.timestamp + durationSeconds;

        _escrows[escrowId] = EscrowRecord({
            hirer: msg.sender,
            agent: agent,
            amount: amount,
            taskHash: taskHash,
            proofCommitment: proofCommitment,
            status: Status.Active,
            createdAt: block.timestamp,
            expiresAt: expiresAt
        });

        emit EscrowDeposited(escrowId, msg.sender, agent, amount, taskHash, expiresAt);
    }

    function release(bytes32 escrowId, bytes32 proofHash) external {
        EscrowRecord storage escrow = _escrows[escrowId];

        require(escrow.hirer != address(0), "SafeEscrow: escrow not found");
        require(escrow.status == Status.Active, "SafeEscrow: escrow not active");
        require(
            msg.sender == escrow.hirer,
            "SafeEscrow: only hirer can release"
        );
        require(
            block.timestamp <= escrow.expiresAt,
            "SafeEscrow: escrow expired \xe2\x80\x94 use refund()"
        );
        require(proofHash != bytes32(0), "SafeEscrow: zero proof hash");
        // CRITICAL: proof must match the commitment made at deposit time
        require(
            proofHash == escrow.proofCommitment,
            "SafeEscrow: proof does not match commitment"
        );

        escrow.status = Status.Released;

        // Transfer USDC to agent
        _transfer(escrow.agent, escrow.amount);

        // Update reputation: +5 points (capped at 100)
        _updateReputation(escrow.agent, true);

        emit EscrowReleased(escrowId, escrow.agent, escrow.amount, proofHash);
    }

    function refund(bytes32 escrowId) external {
        EscrowRecord storage escrow = _escrows[escrowId];

        require(escrow.hirer != address(0), "SafeEscrow: escrow not found");
        require(escrow.status == Status.Active, "SafeEscrow: escrow not active");
        require(
            msg.sender == escrow.hirer || block.timestamp > escrow.expiresAt,
            "SafeEscrow: not expired and not hirer"
        );

        escrow.status = Status.Refunded;

        // Return USDC to hirer
        _transfer(escrow.hirer, escrow.amount);

        // Update reputation: -5 points (floored at 0)
        _updateReputation(escrow.agent, false);

        emit EscrowRefunded(escrowId, escrow.hirer, escrow.amount);
    }

    function getEscrow(bytes32 escrowId)
        external
        view
        returns (EscrowRecord memory)
    {
        require(_escrows[escrowId].hirer != address(0), "SafeEscrow: not found");
        return _escrows[escrowId];
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /// @dev Minimal ERC-20 transferFrom without importing full interface.
    function _transferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = usdc.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                amount
            )
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeEscrow: USDC transferFrom failed"
        );
    }

    /// @dev Minimal ERC-20 transfer.
    function _transfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = usdc.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeEscrow: USDC transfer failed"
        );
    }

    /// @dev Update agent reputation in registry.
    function _updateReputation(address agent, bool success_) internal {
        try IERC8004(registry).getAgent(agent) returns (IERC8004.AgentRecord memory record) {
            uint256 current = record.reputation;
            uint256 newScore = success_
                ? (current + 5 > 100 ? 100 : current + 5)
                : (current < 5 ? 0 : current - 5);

            // Best-effort — don't revert main flow on registry failure
            try IERC8004(registry).updateReputation(agent, newScore) {} catch {}
        } catch {}
    }
}
