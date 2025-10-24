# Matchbox Setup Guide

Complete guide to setting up and deploying the Matchbox protocol.

## Prerequisites

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone and Setup**
   ```bash
   cd matchbox_contracts
   forge install
   forge build
   ```

3. **Create Environment File**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your values:
   ```bash
   # Your private key (DO NOT COMMIT THIS)
   PRIVATE_KEY=your_private_key_without_0x_prefix
   
   # RPC URL for Polygon
   POLYGON_RPC_URL=https://polygon-rpc.com
   
   # For contract verification
   ETHERSCAN_API_KEY=your_polygonscan_api_key
   ```

## Deployment Workflow

### Step 1: Deploy Core Contracts

Deploy to Polygon mainnet:

```bash
forge script script/DeployMatchbox.s.sol \
  --rpc-url $POLYGON_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

Or deploy to testnet (Mumbai):

```bash
forge script script/DeployMatchbox.s.sol \
  --rpc-url $MUMBAI_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**Save the deployed addresses:**
- MatchboxRouter: `<address>`
- MatchboxFactory: `<address>`
- Implementation: `<address>`

### Step 2: Update Environment

Add the deployed addresses to your `.env`:

```bash
FACTORY_ADDRESS=<deployed_factory_address>
ROUTER_ADDRESS=<deployed_router_address>
```

### Step 3: Create Your First Matchbox

```bash
forge script script/CreateMatchbox.s.sol \
  --rpc-url $POLYGON_RPC_URL \
  --broadcast \
  -vvvv
```

This will deploy a personal Matchbox vault for your address.

## Testing

### Run All Tests

```bash
forge test
```

### Run with Detailed Output

```bash
forge test -vvv
```

### Run Specific Test File

```bash
forge test --match-path test/Matchbox.t.sol
```

### Run Specific Test Function

```bash
forge test --match-test testCreateMatchbox
```

### Generate Gas Report

```bash
forge test --gas-report
```

### Generate Coverage Report

```bash
forge coverage
```

## Using Your Matchbox

### Example: Creating a 2-Step Parlay

Here's a complete example of creating and executing a parlay:

```solidity
// 1. Get your Matchbox address
address matchboxAddress = factory.getMatchboxesForOwner(msg.sender)[0];
Matchbox matchbox = Matchbox(matchboxAddress);

// 2. Define your conditional sequence
Matchbox.Rule[] memory rules = new Matchbox.Rule[](2);

// Step 1: Bet $100 on "Will Bitcoin reach $100k in Q1?" - YES
// Only execute if price is between $0.40 and $0.60
rules[0] = Matchbox.Rule({
    conditionId: 0x1234...abcd, // Get from Polymarket API
    outcomeIndex: 1,             // 1 = YES
    minPrice: 4000,              // 0.40 minimum
    maxPrice: 6000,              // 0.60 maximum
    useAllFunds: false,
    specificAmount: 100e6        // 100 USDC
});

// Step 2: If BTC hits 100k, use ALL proceeds to bet on
// "Will ETH reach $10k in Q1?" - YES
// Only execute if price is below $0.50
rules[1] = Matchbox.Rule({
    conditionId: 0x5678...efgh,
    outcomeIndex: 1,
    minPrice: 0,
    maxPrice: 5000,              // Will revert if price > 0.50
    useAllFunds: true,           // Use all proceeds from step 1
    specificAmount: 0
});

// 3. Initialize the sequence
matchbox.initializeSequence(rules);

// 4. Approve USDC
IERC20(USDC).approve(matchboxAddress, 100e6);

// 5. Get order data from Polymarket API
bytes memory orderData = getOrderDataFromPolymarket(
    rules[0].conditionId,
    rules[0].outcomeIndex,
    100e6
);

// 6. Execute first step
matchbox.executeFirstStep(100e6, orderData);

// 7. Set up Chainlink Automation
// Register your Matchbox with Chainlink Automation
// It will automatically execute step 2 when BTC market resolves
```

### Monitoring Your Matchbox

Check the status of your sequence:

```solidity
uint256 currentStep = matchbox.currentStep();
uint256 totalSteps = matchbox.totalSteps();
bool isActive = matchbox.isActive();

console.log("Progress:", currentStep, "/", totalSteps);
console.log("Active:", isActive);
```

### Withdrawing Funds

At any time, you can withdraw your funds:

```solidity
// Withdraw all USDC
matchbox.withdrawFunds(USDC_ADDRESS, 0);

// Withdraw specific amount
matchbox.withdrawFunds(USDC_ADDRESS, 50e6);
```

### Emergency Stop

Deactivate your sequence if needed:

```solidity
matchbox.deactivate();
```

## Polymarket Integration

### Getting Market Data

Use Polymarket's API to get market information:

```bash
# Get market details
curl https://clob.polymarket.com/markets

# Get orderbook
curl https://clob.polymarket.com/book?market=<market_id>
```

### Finding Condition IDs

1. Go to [Polymarket](https://polymarket.com)
2. Find your market
3. Extract the condition ID from the URL or API
4. Use it in your `Rule.conditionId`

### Getting Order Data

To execute trades, you need order data from Polymarket's CLOB:

```javascript
// Pseudo-code for fetching order data
const orders = await polymarketAPI.getOrders({
  market: conditionId,
  side: 'BUY',
  outcome: outcomeIndex,
  amount: amountIn
});

const orderData = ethers.utils.defaultAbiCoder.encode(
  ['tuple(...)[]'],
  [orders]
);
```

## Chainlink Automation Setup

### 1. Register Your Matchbox

Go to [Chainlink Automation](https://automation.chain.link)

### 2. Create New Upkeep

- **Target Contract**: Your Matchbox address
- **Check Function**: `checkUpkeep(bytes calldata checkData)`
- **Perform Function**: `executeNextStep(bytes calldata performData)`
- **Trigger**: Custom Logic

### 3. Fund Your Upkeep

Add LINK tokens to ensure your automation runs.

### 4. Monitor Execution

The automation network will:
1. Monitor when markets resolve
2. Call `checkUpkeep()` to see if next step is ready
3. Execute `executeNextStep()` when conditions are met

## Troubleshooting

### Build Errors

If you get "Stack too deep" errors:
```bash
# The foundry.toml is already configured with via_ir = true
# If you still have issues, try:
forge clean
forge build
```

### Transaction Reverts

Common reasons transactions revert:

1. **Price Constraint Not Met**: The market price doesn't satisfy your min/max price
   - Check current market price
   - Adjust your price constraints

2. **Insufficient Balance**: Not enough USDC or conditional tokens
   - Check your Matchbox balance
   - Fund your Matchbox if needed

3. **Market Not Resolved**: Trying to execute next step before previous market resolves
   - Wait for market resolution
   - Check market status on Polymarket

4. **Sequence Inactive**: The sequence was deactivated
   - Check `matchbox.isActive()`
   - Re-initialize if needed

### Gas Issues

If gas is too high:
- The protocol uses via-IR optimization, which may increase deployment gas
- Runtime gas is optimized
- Consider using Flashbots or private RPCs for lower MEV risk

## Security Best Practices

1. **Start Small**: Test with small amounts first
2. **Use Testnet**: Thoroughly test on Mumbai before mainnet
3. **Set Reasonable Constraints**: Don't set price ranges too wide
4. **Monitor Active Sequences**: Check your Matchbox status regularly
5. **Keep Private Keys Safe**: Never commit `.env` to git
6. **Audit Your Rules**: Double-check your rule logic before deploying

## Advanced Configuration

### Custom Router Implementation

If you need custom trading logic:

```solidity
// Deploy custom router
CustomRouter router = new CustomRouter(...);

// Deploy factory with custom router
MatchboxFactory factory = new MatchboxFactory(
    address(router),
    CTF_ADDRESS,
    USDC_ADDRESS
);
```

### Multiple Strategies

Deploy multiple Matchboxes for different strategies:

```solidity
// Conservative parlay
address conservative = factory.createMatchbox(bytes32("conservative"));

// Aggressive parlay  
address aggressive = factory.createMatchbox(bytes32("aggressive"));

// Each has independent rules and funds
```

## Support

- **Issues**: Open an issue on GitHub
- **Discord**: Join our community (TBD)
- **Documentation**: See [CONTRACTS_README.md](./CONTRACTS_README.md)

---

Happy building! 🚀

