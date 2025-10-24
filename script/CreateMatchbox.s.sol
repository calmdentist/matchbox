// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MatchboxFactory} from "../src/MatchboxFactory.sol";
import {Matchbox} from "../src/Matchbox.sol";

/**
 * @title CreateMatchbox
 * @notice Script to create a new Matchbox vault via the factory
 * @dev Run with: forge script script/CreateMatchbox.s.sol --rpc-url <RPC_URL> --broadcast
 */
contract CreateMatchbox is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);

        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");

        console2.log("Creating Matchbox for user:", user);
        console2.log("Using factory at:", factoryAddress);

        MatchboxFactory factory = MatchboxFactory(factoryAddress);

        vm.startBroadcast(userPrivateKey);

        // Create a new Matchbox with a random salt
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, user));
        address matchbox = factory.createMatchbox(salt);

        console2.log("\n=== Matchbox Created ===");
        console2.log("Matchbox address:", matchbox);
        console2.log("Owner:", Matchbox(matchbox).OWNER());

        // Get user's total matchboxes
        address[] memory userMatchboxes = factory.getMatchboxesForOwner(user);
        console2.log("Total matchboxes for user:", userMatchboxes.length);

        vm.stopBroadcast();

        console2.log("\n=== Next Steps ===");
        console2.log("1. Initialize sequence with rules via Matchbox.initializeSequence()");
        console2.log("2. Execute first step via Matchbox.executeFirstStep()");
        console2.log("3. Set up Chainlink Automation to monitor market resolution");
    }
}

