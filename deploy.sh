#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
POLYGON_RPC_URL="${POLYGON_RPC_URL:-https://polygon-rpc.com}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}" # Default Anvil key

# File to store Anvil PID
ANVIL_PID_FILE=".anvil.pid"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Matchbox Local Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Function to cleanup Anvil on exit
cleanup() {
    if [ -f "$ANVIL_PID_FILE" ]; then
        ANVIL_PID=$(cat "$ANVIL_PID_FILE")
        if ps -p $ANVIL_PID > /dev/null 2>&1; then
            echo -e "\n${YELLOW}Stopping Anvil node (PID: $ANVIL_PID)...${NC}"
            kill $ANVIL_PID
            wait $ANVIL_PID 2>/dev/null
        fi
        rm "$ANVIL_PID_FILE"
    fi
}

# Function to stop any existing Anvil instances on the port
stop_existing_anvil() {
    echo -e "${YELLOW}Checking for existing Anvil instances on port $ANVIL_PORT...${NC}"
    
    # Try to find and kill process on the port
    EXISTING_PID=$(lsof -ti:$ANVIL_PORT)
    if [ ! -z "$EXISTING_PID" ]; then
        echo -e "${YELLOW}Found existing process on port $ANVIL_PORT (PID: $EXISTING_PID). Stopping it...${NC}"
        kill $EXISTING_PID 2>/dev/null
        sleep 2
    fi
}

# Set up trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Check if required tools are installed
command -v anvil >/dev/null 2>&1 || { 
    echo -e "${RED}Error: anvil is not installed. Please install Foundry first.${NC}"
    echo "Visit: https://book.getfoundry.sh/getting-started/installation"
    exit 1
}

command -v forge >/dev/null 2>&1 || { 
    echo -e "${RED}Error: forge is not installed. Please install Foundry first.${NC}"
    exit 1
}

# Stop any existing Anvil instances
stop_existing_anvil

# Step 1: Start Anvil node forking Polygon
echo -e "${GREEN}Step 1: Starting Anvil node (forking Polygon)...${NC}"
echo -e "  - Fork URL: $POLYGON_RPC_URL"
echo -e "  - Port: $ANVIL_PORT"
echo -e "  - Chain ID: 31337 (Anvil Local)"
echo ""

# Start Anvil in the background and save PID
anvil \
    --fork-url "$POLYGON_RPC_URL" \
    --port "$ANVIL_PORT" \
    --chain-id 31337 \
    --accounts 10 \
    --balance 10000 \
    > anvil.log 2>&1 &

ANVIL_PID=$!
echo $ANVIL_PID > "$ANVIL_PID_FILE"

echo -e "${GREEN}✓ Anvil started (PID: $ANVIL_PID)${NC}"
echo -e "  Log file: anvil.log"
echo ""

# Step 2: Wait for Anvil to be ready
echo -e "${YELLOW}Step 2: Waiting for Anvil to be ready...${NC}"
sleep 3

# Check if Anvil is running
if ! ps -p $ANVIL_PID > /dev/null; then
    echo -e "${RED}Error: Anvil failed to start. Check anvil.log for details.${NC}"
    exit 1
fi

# Test connection
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        -H "Content-Type: application/json" \
        http://localhost:$ANVIL_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Anvil is ready!${NC}\n"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}Error: Anvil failed to respond. Check anvil.log for details.${NC}"
    exit 1
fi

# Step 3: Deploy contracts
echo -e "${GREEN}Step 3: Deploying Matchbox contracts...${NC}"
echo -e "  - Using private key: ${PRIVATE_KEY:0:10}...${NC}"
echo ""

# Export environment variables for the deployment script
export PRIVATE_KEY="$PRIVATE_KEY"

# Run the deployment script and capture output
DEPLOY_OUTPUT=$(forge script script/DeployMatchbox.s.sol \
    --rpc-url http://localhost:$ANVIL_PORT \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    -vvv 2>&1)

DEPLOY_EXIT_CODE=$?

# Display the output
echo "$DEPLOY_OUTPUT"

if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
    echo -e "\n${RED}Error: Deployment failed with exit code $DEPLOY_EXIT_CODE${NC}"
    echo -e "${YELLOW}Check the output above for details.${NC}"
    exit 1
fi

# Extract deployed addresses from output
ROUTER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "MatchboxRouter:\s+0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")
FACTORY_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "MatchboxFactory:\s+0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")
IMPLEMENTATION_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "Implementation:\s+0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${GREEN}Local Node Information:${NC}"
echo -e "  - RPC URL: http://localhost:$ANVIL_PORT"
echo -e "  - Chain ID: 31337 (Anvil Local)"
echo -e "  - Forked from: Polygon Mainnet"
echo ""

echo -e "${GREEN}Available Accounts:${NC}"
echo -e "  Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo -e "  Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""

echo -e "${GREEN}Polymarket Addresses (from Polygon):${NC}"
echo -e "  - USDC: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
echo -e "  - CTF: 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045"
echo -e "  - Exchange: 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"
echo ""

echo -e "${YELLOW}Deployed Contract Addresses:${NC}"
if [ -n "$ROUTER_ADDRESS" ]; then
    echo -e "  - MatchboxRouter: ${GREEN}$ROUTER_ADDRESS${NC}"
else
    echo -e "  - MatchboxRouter: ${RED}(not found in output)${NC}"
fi
if [ -n "$FACTORY_ADDRESS" ]; then
    echo -e "  - MatchboxFactory: ${GREEN}$FACTORY_ADDRESS${NC}"
else
    echo -e "  - MatchboxFactory: ${RED}(not found in output)${NC}"
fi
if [ -n "$IMPLEMENTATION_ADDRESS" ]; then
    echo -e "  - Implementation: ${GREEN}$IMPLEMENTATION_ADDRESS${NC}"
else
    echo -e "  - Implementation: ${RED}(not found in output)${NC}"
fi
echo ""

echo -e "${YELLOW}Note: Anvil is running in the background.${NC}"
echo -e "Press Ctrl+C to stop the node and exit, or run:"
echo -e "  ${GREEN}kill $ANVIL_PID${NC}"
echo ""

# Keep script running so Anvil stays alive
echo -e "${GREEN}Anvil node is running. Press Ctrl+C to stop...${NC}\n"
wait $ANVIL_PID

