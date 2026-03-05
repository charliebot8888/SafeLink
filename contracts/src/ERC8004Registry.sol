// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IERC8004.sol";

/// @title ERC8004Registry — On-chain agent identity and capability registry
/// @notice Agents register here to be discoverable and hire-able.
///         Reputation is updated by the SafeEscrow contract after task completion.
contract ERC8004Registry is IERC8004 {
    // ── State ─────────────────────────────────────────────────────────────────

    mapping(address => AgentRecord) private _agents;
    mapping(address => bool) private _registered;

    /// @notice Address of the SafeEscrow contract allowed to update reputation.
    address public escrowContract;

    /// @notice Owner of this registry (can set escrow contract).
    address public immutable owner;

    // ── Modifiers ─────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "ERC8004Registry: not owner");
        _;
    }

    modifier onlyEscrow() {
        require(
            msg.sender == escrowContract,
            "ERC8004Registry: only escrow contract can update reputation"
        );
        _;
    }

    modifier onlyRegistered() {
        require(_registered[msg.sender], "ERC8004Registry: agent not registered");
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ── Admin ─────────────────────────────────────────────────────────────────

    /// @notice Set the escrow contract address (called after SafeEscrow is deployed).
    function setEscrowContract(address _escrow) external onlyOwner {
        require(_escrow != address(0), "ERC8004Registry: zero address");
        escrowContract = _escrow;
    }

    // ── IERC8004 implementation ───────────────────────────────────────────────

    function register(
        string[] calldata capabilities,
        uint256 minRate,
        bytes calldata policy
    ) external returns (address agentId) {
        require(capabilities.length > 0, "ERC8004Registry: no capabilities");
        require(capabilities.length <= 20, "ERC8004Registry: too many capabilities");
        require(minRate > 0, "ERC8004Registry: minRate must be > 0");

        uint256 initialReputation = _registered[msg.sender]
            ? _agents[msg.sender].reputation  // preserve rep on re-register
            : 50;                             // new agents start at 50/100

        _agents[msg.sender] = AgentRecord({
            owner: msg.sender,
            capabilities: capabilities,
            minRate: minRate,
            policy: policy,
            reputation: initialReputation,
            registeredAt: block.timestamp,
            active: true
        });

        _registered[msg.sender] = true;

        emit AgentRegistered(msg.sender, msg.sender, capabilities, minRate);
        return msg.sender;
    }

    function getAgent(address agentId)
        external
        view
        returns (AgentRecord memory)
    {
        require(_registered[agentId], "ERC8004Registry: agent not found");
        return _agents[agentId];
    }

    function updateCapabilities(string[] calldata capabilities)
        external
        onlyRegistered
    {
        require(capabilities.length > 0, "ERC8004Registry: no capabilities");
        require(capabilities.length <= 20, "ERC8004Registry: too many capabilities");
        _agents[msg.sender].capabilities = capabilities;
        emit CapabilitiesUpdated(msg.sender, capabilities);
    }

    function deactivate() external onlyRegistered {
        _agents[msg.sender].active = false;
        emit AgentDeactivated(msg.sender);
    }

    function updateReputation(address agentId, uint256 newScore)
        external
        onlyEscrow
    {
        require(_registered[agentId], "ERC8004Registry: agent not found");
        require(newScore <= 100, "ERC8004Registry: score out of range");
        uint256 oldScore = _agents[agentId].reputation;
        _agents[agentId].reputation = newScore;
        emit ReputationUpdated(agentId, oldScore, newScore, msg.sender);
    }

    function isActive(address agentId) external view returns (bool) {
        return _registered[agentId] && _agents[agentId].active;
    }
}
