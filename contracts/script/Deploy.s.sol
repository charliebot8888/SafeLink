// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ERC8004Registry.sol";
import "../src/SafeEscrow.sol";

/// @notice Deploy ERC8004Registry and SafeEscrow to Base Sepolia.
/// Run with:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $BASE_RPC_URL \
///     --broadcast \
///     --verify \
///     -vvvv
contract Deploy is Script {
    // USDC on Base Sepolia
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerKey);

        // 1. Deploy Registry
        ERC8004Registry registry = new ERC8004Registry();
        console.log("ERC8004Registry deployed at:", address(registry));

        // 2. Deploy Escrow (pass registry address)
        SafeEscrow escrow = new SafeEscrow(USDC_BASE_SEPOLIA, address(registry));
        console.log("SafeEscrow deployed at:", address(escrow));

        // 3. Wire: tell registry which escrow contract can update reputation
        registry.setEscrowContract(address(escrow));
        console.log("Registry wired to escrow.");

        vm.stopBroadcast();

        console.log("\n=== Add these to your .env ===");
        console.log("ERC8004_REGISTRY_ADDRESS=", address(registry));
        console.log("SAFE_ESCROW_ADDRESS=", address(escrow));
    }
}
