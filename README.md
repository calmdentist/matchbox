# Matchbox Protocol

> Non-custodial, decentralized automation layer for conditional prediction market wagering

Matchbox enables users to create and execute complex, conditional wagers (e.g., parlays, if-then bets) on prediction markets like Polymarket. Rather than creating new illiquid markets, Matchbox routes funds to existing liquid markets while enforcing user-defined constraints and automating conditional execution.

## Overview

Matchbox is built on three core principles:

- **Non-Custodial**: Users maintain full control of their funds at all times
- **Automated**: Conditional trades execute automatically when market conditions are met
- **Capital Efficient**: Leverages existing liquid markets instead of fragmenting liquidity

### Key Features

- Create multi-step conditional wagers (eg. parlays)
- Set price constraints for automatic execution
- Withdraw funds at any time
- Gas-efficient EIP-1167 minimal proxy pattern
- Integration with Chainlink Automation for decentralized triggers

## Architecture

The protocol consists of three layers:

1. **Design Layer (dApp)**: User-facing interface for creating conditional wager sequences
2. **Logic Layer (Smart Contracts)**: On-chain execution and fund management
3. **Execution Layer (Automation)**: Decentralized monitoring and triggering

For detailed architecture documentation, see [architecture.md](./architecture.md).

## Smart Contracts

### Core Contracts

- **`MatchboxFactory.sol`**: Deploys new user-owned Matchbox vaults via EIP-1167 minimal proxy pattern
- **`Matchbox.sol`**: User-owned vault that holds funds, stores rules, and executes conditional trades
- **`MatchboxRouter.sol`**: Stateless adapter that interacts with Polymarket's AMM and enforces price constraints

### EIP-1167 Minimal Proxy Pattern

Matchbox uses the minimal proxy pattern for gas-efficient deployments:

- **Implementation Contract**: A single master Matchbox contract deployed once by the Factory
- **Proxy Contracts**: Lightweight (~45 bytes) contracts that delegate all calls to the Implementation
- **Gas Savings**: ~90% reduction in deployment costs compared to deploying full contract code

When a user creates a Matchbox, they receive a proxy that:
- Delegates all logic to the shared Implementation
- Maintains their own isolated storage
- Acts as their personal non-custodial vault

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```shell
# Clone the repository
git clone <repository-url>
cd matchbox_contracts

# Install dependencies
forge install
```

## Development

### Build

Compile the smart contracts:

```shell
forge build
```

### Test

Run the test suite:

```shell
forge test
```

Run tests with gas reporting:

```shell
forge test --gas-report
```

Run tests with verbosity:

```shell
forge test -vvv
```

### Format

Format all Solidity files:

```shell
forge fmt
```

### Gas Snapshots

Generate gas snapshots:

```shell
forge snapshot
```

## Deployment

### Local Development (Polygon Fork)

The easiest way to get started is with the provided deployment script that forks Polygon mainnet:

```shell
./deploy.sh
```

This script will:
1. Start an Anvil node forking Polygon mainnet (with all Polymarket contracts)
2. Deploy MatchboxRouter and MatchboxFactory
3. Display deployed contract addresses
4. Keep the node running for testing

**Configuration Options:**

```shell
# Use a custom Polygon RPC (recommended for faster sync)
POLYGON_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY" ./deploy.sh

# Use a custom port
ANVIL_PORT=9545 ./deploy.sh

# Use a custom private key
PRIVATE_KEY="0x..." ./deploy.sh
```

**Default Configuration:**
- RPC URL: `http://localhost:8545`
- Chain ID: `137` (Polygon Mainnet)
- Test Account: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Test Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

The node will continue running until you press `Ctrl+C`.

### Manual Deployment

Deploy contracts to a network manually:

```shell
forge script script/DeployMatchbox.s.sol \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast \
  --verify
```

Deploy to an already-running local node:

```shell
forge script script/DeployMatchbox.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key <anvil_private_key> \
  --broadcast
```

## Project Structure

```
matchbox_contracts/
├── src/                    # Smart contract source files
│   ├── MatchboxFactory.sol
│   ├── Matchbox.sol
│   └── MatchboxRouter.sol
├── test/                   # Test files
├── script/                 # Deployment scripts
├── lib/                    # Dependencies
├── architecture.md         # Detailed architecture documentation
└── matchbox.pdf           # Technical whitepaper
```

## Security

- All core contracts are designed to be auditable and minimal
- User funds are non-custodial and withdrawable at any time
- Price constraints are enforced atomically on-chain
- EIP-1167 minimal proxy pattern for gas efficiency

## Documentation

- [Architecture Documentation](./architecture.md) - Detailed system architecture
- [Foundry Book](https://book.getfoundry.sh/) - Foundry documentation
- [Technical Whitepaper](./matchbox.pdf) - In-depth protocol specification

## License

MIT

## Contributing

PRs are welcome <3

## Support

For questions and support, please [open an issue](../../issues) or contact the team.
