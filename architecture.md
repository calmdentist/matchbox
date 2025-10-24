# Matchbox Protocol Architecture

## Overview

Matchbox is a non-custodial, decentralized automation layer built on top of existing prediction markets (e.g., Polymarket). It enables users to create and execute complex, conditional wagers (e.g., parlays, if-then bets) by routing funds to underlying liquid markets, rather than attempting to create new, illiquid markets for every conditional outcome.

The architecture is designed for maximum security, non-custodial ownership, and capital efficiency. It is composed of three distinct layers:

1. **The Design Layer (dApp)**
2. **The Logic Layer (Smart Contracts)**
3. **The Execution Layer (Automation)**

---

## 1. The Design Layer (dApp)

This is the user-facing web application that serves as the "builder" or "factory" for creating a new Matchbox.

**Function:** Provides a simple, no-code interface for users to browse underlying markets (via Polymarket's API) and design their conditional sequence.

### User Flow:

1. User connects their wallet.
2. User defines a sequence (e.g., "Buy YES on Market A").
3. User adds a conditional, automated "next step" (e.g., "IF Market A resolves YES, use proceeds to buy YES on Market B").
4. User adds key constraints (e.g., "Only execute Step 2 IF the price of 'YES on B' is LESS THAN 0.50").

**Action:** The dApp bundles these rules into a set of instructions. When the user clicks "Deploy," it initiates the on-chain transactions to the Logic Layer.

---

## 2. The Logic Layer (Smart Contracts)

This is the core on-chain, non-custodial foundation of the protocol. It consists of two primary contract types.

### MatchboxFactory.sol

- **Type:** Singleton, audited contract.
- **Purpose:** Its sole responsibility is to deploy new `Matchbox.sol` contracts for users via the gas-efficient EIP-1167 "minimal proxy" pattern. It also maintains a public registry of all active Matchboxes.

### Matchbox.sol

- **Type:** User-owned, non-custodial vault. Each user deploys their own unique instance.
- **Purpose:** This contract is the "Matchbox" itself. It is owned only by the user and is responsible for:
  - Holding the user's funds (USDC).
  - Holding the user's acquired assets (Polymarket conditional tokens, e.g., "YES on A" shares).
  - Storing the user's predefined ruleset.

#### Example Data Structure

The rules are stored in a simple, on-chain struct:

```solidity
struct Rule {
    address market;       // Address of the Polymarket market
    uint256 outcomeIndex; // 0 for NO, 1 for YES
    uint256 maxPrice;     // Max price to pay (e.g., 50e16 for $0.50)
    uint256 minPrice;     // Min price to pay
}

struct Sequence {
    Rule[] steps; // An array of rules to be executed in order
}

Sequence public sequence;
address public immutable owner; // The user who deployed it
```

#### Key Functions:

- **`executeStep1(uint amountIn)`:** Called by the user at creation. It takes their USDC and calls the MatchboxRouter to execute the first trade.

- **`executeNextStep()`:** This function is the core of the automation. It can only be called by the trusted Execution Layer trigger. It redeems the proceeds from the previous step and calls the MatchboxRouter to execute the next trade, passing in the new rules.

- **`withdrawFunds()`:** A function restricted to the owner (the user) that allows them to pull all funds (USDC or conditional tokens) out of their vault at any time, ensuring the protocol remains non-custodial.

---

## 3. The Execution Layer (Automation)

This layer is responsible for triggering the `Matchbox.sol` vault and executing its trades with the defined constraints.

### Decentralized Trigger (e.g., Chainlink Automation)

- **Type:** External, decentralized oracle network.
- **Purpose:** Matchbox offloads the "monitoring" task to a battle-tested service.
- **Action:** When a user deploys their Matchbox, the dApp helps them register a new automation "job." This job simply monitors the underlying market (e.g., Market A). As soon as that market resolves, the automation network calls the `executeNextStep()` function on the user's specific `Matchbox.sol` contract, paying the gas fee to "ignite" the next step in the sequence.

### MatchboxRouter.sol

- **Type:** Singleton, stateless, and heavily-audited utility contract.
- **Purpose:** This is the protocol's "adapter" to the outside world. It is the only contract with the complex logic needed to interact with Polymarket's AMM.

#### Key Innovation (Atomic Constraint Enforcement)

This contract enforces the user's price constraints.

**Action:**

1. The user's `Matchbox.sol` calls `MatchboxRouter.swapWithConstraints(...)`, passing in the funds (e.g., $200) and the rule (e.g., `maxPrice: 0.50`).

2. The Router calculates the `minAmountOut` required to satisfy this price (e.g., $200 / $0.50 = 400 shares).

3. It then calls Polymarket's AMM, providing this `minAmountOut` as the slippage protection.

4. **Success:** If the price is 40 cents, the swap gets 500 shares (which is > 400) and succeeds. The 500 shares are sent to the `Matchbox.sol` vault.

5. **Failure (Constraint Met):** If the price is 55 cents, the AMM can only provide 363 shares. This is < 400, so the swap call atomically reverts. The transaction fails, and the $200 in proceeds are safely returned to the `Matchbox.sol` vault, unspent. The parlay is broken, as intended by the user.