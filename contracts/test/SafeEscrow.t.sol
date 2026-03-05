// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ERC8004Registry.sol";
import "../src/SafeEscrow.sol";

/// @notice Mock ERC-20 USDC for testing (no real USDC needed).
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient");
        require(allowance[from][msg.sender] >= amount, "allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract SafeEscrowTest is Test {
    ERC8004Registry registry;
    SafeEscrow escrow;
    MockUSDC usdc;

    address hirer = address(0x1);
    address agent = address(0x2);

    // Simulated proof: keccak256(abi.encodePacked(sessionId, agentAddress))
    bytes32 constant PROOF = keccak256(abi.encodePacked("session-abc", address(0x2)));

    function setUp() public {
        usdc = new MockUSDC();
        registry = new ERC8004Registry();
        escrow = new SafeEscrow(address(usdc), address(registry));
        registry.setEscrowContract(address(escrow));

        // Register agent
        vm.prank(agent);
        string[] memory caps = new string[](1);
        caps[0] = "test-capability";
        registry.register(caps, 1_000_000, "");

        // Fund hirer
        usdc.mint(hirer, 100_000_000); // 100 USDC
    }

    function test_deposit_basic() public {
        uint256 amount = 5_000_000; // 5 USDC
        bytes32 taskHash = keccak256("do something");

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, taskHash, PROOF, amount, 300);
        vm.stopPrank();

        ISafeEscrow.EscrowRecord memory record = escrow.getEscrow(escrowId);
        assertEq(record.hirer, hirer);
        assertEq(record.agent, agent);
        assertEq(record.amount, amount);
        assertEq(record.proofCommitment, PROOF);
        assertEq(uint8(record.status), uint8(ISafeEscrow.Status.Active));
    }

    function test_release_transfers_to_agent() public {
        uint256 amount = 5_000_000;
        bytes32 taskHash = keccak256("do something");

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, taskHash, PROOF, amount, 300);
        escrow.release(escrowId, PROOF); // must match commitment
        vm.stopPrank();

        assertEq(usdc.balanceOf(agent), amount);
        assertEq(usdc.balanceOf(hirer), 100_000_000 - amount);

        ISafeEscrow.EscrowRecord memory record = escrow.getEscrow(escrowId);
        assertEq(uint8(record.status), uint8(ISafeEscrow.Status.Released));
    }

    function test_release_rejects_wrong_proof() public {
        uint256 amount = 5_000_000;
        bytes32 wrongProof = keccak256("wrong-proof");

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, keccak256("task"), PROOF, amount, 300);
        vm.expectRevert("SafeEscrow: proof does not match commitment");
        escrow.release(escrowId, wrongProof);
        vm.stopPrank();
    }

    function test_release_rejects_zero_proof() public {
        uint256 amount = 5_000_000;

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, keccak256("task"), PROOF, amount, 300);
        vm.expectRevert("SafeEscrow: zero proof hash");
        escrow.release(escrowId, bytes32(0));
        vm.stopPrank();
    }

    function test_deposit_rejects_zero_commitment() public {
        vm.startPrank(hirer);
        usdc.approve(address(escrow), 5_000_000);
        vm.expectRevert("SafeEscrow: zero proof commitment");
        escrow.deposit(agent, keccak256("task"), bytes32(0), 5_000_000, 300);
        vm.stopPrank();
    }

    function test_refund_on_expiry() public {
        uint256 amount = 5_000_000;
        bytes32 taskHash = keccak256("do something");

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, taskHash, PROOF, amount, 60);
        vm.stopPrank();

        // Advance time past expiry
        vm.warp(block.timestamp + 61);

        // Anyone can trigger refund after expiry
        escrow.refund(escrowId);

        assertEq(usdc.balanceOf(hirer), 100_000_000); // Full refund
        assertEq(usdc.balanceOf(agent), 0);
    }

    function test_reputation_increases_on_release() public {
        uint256 amount = 5_000_000;
        bytes32 taskHash = keccak256("do something");

        // Initial reputation = 50
        IERC8004.AgentRecord memory before_ = registry.getAgent(agent);
        assertEq(before_.reputation, 50);

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, taskHash, PROOF, amount, 300);
        escrow.release(escrowId, PROOF);
        vm.stopPrank();

        // Reputation should increase to 55
        IERC8004.AgentRecord memory after_ = registry.getAgent(agent);
        assertEq(after_.reputation, 55);
    }

    function test_reputation_decreases_on_refund() public {
        uint256 amount = 5_000_000;
        bytes32 taskHash = keccak256("do something");

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, taskHash, PROOF, amount, 60);
        vm.stopPrank();

        vm.warp(block.timestamp + 61);
        escrow.refund(escrowId);

        // Reputation should decrease to 45
        IERC8004.AgentRecord memory after_ = registry.getAgent(agent);
        assertEq(after_.reputation, 45);
    }

    function test_cannot_hire_yourself() public {
        vm.startPrank(hirer);
        vm.expectRevert("SafeEscrow: cannot hire yourself");
        escrow.deposit(hirer, keccak256("task"), PROOF, 1_000_000, 60);
        vm.stopPrank();
    }

    function test_cannot_release_expired_escrow() public {
        uint256 amount = 5_000_000;

        vm.startPrank(hirer);
        usdc.approve(address(escrow), amount);
        bytes32 escrowId = escrow.deposit(agent, keccak256("task"), PROOF, amount, 60);
        vm.warp(block.timestamp + 61);
        vm.expectRevert("SafeEscrow: escrow expired \xe2\x80\x94 use refund()");
        escrow.release(escrowId, PROOF);
        vm.stopPrank();
    }
}
