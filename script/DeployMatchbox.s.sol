// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MatchboxFactory} from "../src/MatchboxFactory.sol";
import {MatchboxRouter} from "../src/MatchboxRouter.sol";

/**
 * @title DeployMatchbox
 * @notice Deployment script for Matchbox protocol contracts
 * @dev Run with: forge script script/DeployMatchbox.s.sol --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployMatchbox is Script {
    // Polygon addresses (for Polymarket)
    address constant POLYGON_USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant POLYGON_CTF = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;
    address constant POLYGON_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E; // CLOB

    // Testnet addresses (Mumbai or custom)
    address constant TESTNET_USDC = address(0); // Replace with testnet USDC
    address constant TESTNET_CTF = address(0); // Replace with testnet CTF
    address constant TESTNET_EXCHANGE = address(0); // Replace with testnet exchange

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying Matchbox protocol...");
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance);

        // Determine which network we're on
        bool isPolygon = block.chainid == 137;
        bool isTestnet = block.chainid == 80001 || block.chainid == 31337; // Mumbai or local

        address usdc;
        address ctf;
        address exchangeAddr;

        if (isPolygon) {
            console2.log("Deploying to Polygon mainnet");
            usdc = POLYGON_USDC;
            ctf = POLYGON_CTF;
            exchangeAddr = POLYGON_EXCHANGE;
        } else if (isTestnet) {
            console2.log("Deploying to testnet");
            usdc = TESTNET_USDC;
            ctf = TESTNET_CTF;
            exchangeAddr = TESTNET_EXCHANGE;
        } else {
            revert("Unsupported network");
        }

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MatchboxRouter
        console2.log("\n1. Deploying MatchboxRouter...");
        MatchboxRouter router = new MatchboxRouter(
            ctf,
            exchangeAddr,
            usdc,
            address(0) // Factory address to be set
        );
        console2.log("MatchboxRouter deployed at:", address(router));

        // 2. Deploy MatchboxFactory
        console2.log("\n2. Deploying MatchboxFactory...");
        MatchboxFactory factory = new MatchboxFactory(address(router), ctf, usdc);
        console2.log("MatchboxFactory deployed at:", address(factory));

        console2.log("\n=== Deployment Summary ===");
        console2.log("MatchboxRouter:  ", address(router));
        console2.log("MatchboxFactory: ", address(factory));
        console2.log("Implementation:  ", factory.getImplementation());
        console2.log("\nNetwork: ", block.chainid);
        console2.log("USDC:    ", usdc);
        console2.log("CTF:     ", ctf);
        console2.log("Exchange:", exchangeAddr);

        vm.stopBroadcast();

        console2.log("\n=== Next Steps ===");
        console2.log("1. Verify contracts on block explorer");
        console2.log("2. Update frontend config with deployed addresses");
        console2.log("3. Test creating a Matchbox via factory");
    }
}

