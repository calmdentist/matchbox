// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPolymarketCTF} from "./interfaces/IPolymarketCTF.sol";

/**
 * @title Matchbox
 * @notice User-owned, non-custodial vault for conditional wagering sequences
 * @dev Each user deploys their own Matchbox via the MatchboxFactory
 * @author calmxbt
 *
 * Key Features:
 * - Non-custodial: Only the owner can withdraw funds
 * - Holds user's USDC and conditional tokens
 * - Stores predefined rule sequences
 * - Executes trades via MatchboxRouter with price constraints
 * - Can be triggered by external automation (e.g., Chainlink Automation)
 */
contract Matchbox {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidStep();
    error SequenceComplete();
    error StepNotReady();
    error InvalidRule();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StepExecuted(uint256 indexed stepIndex, uint256 amountIn, uint256 amountOut);
    event FundsWithdrawn(address indexed token, uint256 amount);
    event SequenceCreated(uint256 totalSteps);
    event StepSkipped(uint256 indexed stepIndex, string reason);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The owner of this Matchbox (the user who deployed it)
    address public immutable OWNER;

    /// @notice The MatchboxRouter contract that executes trades
    address public immutable ROUTER;

    /// @notice The Polymarket CTF contract
    IPolymarketCTF public immutable CTF;

    /// @notice The collateral token (USDC)
    address public immutable COLLATERAL_TOKEN;

    /// @notice Current step in the sequence (0-indexed)
    uint256 public currentStep;

    /// @notice Total number of steps in the sequence
    uint256 public totalSteps;

    /// @notice Whether the sequence is active
    bool public isActive;

    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a single rule/step in the conditional sequence
     * @param conditionId The Polymarket condition ID
     * @param outcomeIndex The outcome to bet on (0 = NO, 1 = YES)
     * @param minPrice Minimum acceptable price (in basis points, e.g., 5000 = 0.50)
     * @param maxPrice Maximum acceptable price (in basis points, e.g., 5000 = 0.50)
     * @param useAllFunds Whether to use all available funds or a specific amount
     * @param specificAmount If useAllFunds is false, the specific amount to use
     */
    struct Rule {
        bytes32 conditionId;
        uint256 outcomeIndex;
        uint256 minPrice; // In basis points (10000 = 1.00 = $1)
        uint256 maxPrice; // In basis points
        bool useAllFunds;
        uint256 specificAmount;
    }

    /// @notice Array of rules defining the sequence
    Rule[] public sequence;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes a new Matchbox vault
     * @param _owner The owner of this Matchbox
     * @param _router The MatchboxRouter address
     * @param _ctf The Polymarket CTF address
     * @param _collateralToken The collateral token address (USDC)
     */
    constructor(address _owner, address _router, address _ctf, address _collateralToken) {
        OWNER = _owner;
        ROUTER = _router;
        CTF = IPolymarketCTF(_ctf);
        COLLATERAL_TOKEN = _collateralToken;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the sequence with rules
     * @param rules Array of rules defining the conditional sequence
     */
    function initializeSequence(Rule[] calldata rules) external {
        if (msg.sender != OWNER) revert Unauthorized();
        if (isActive) revert InvalidStep();
        if (rules.length == 0) revert InvalidRule();

        for (uint256 i = 0; i < rules.length; i++) {
            // Validate rule parameters
            if (rules[i].maxPrice > 10000 || rules[i].minPrice > rules[i].maxPrice) {
                revert InvalidRule();
            }
            sequence.push(rules[i]);
        }

        totalSteps = rules.length;
        isActive = true;

        emit SequenceCreated(totalSteps);
    }

    /**
     * @notice Executes the first step in the sequence
     * @param amountIn The amount of collateral to use for the first step
     * @param orderData Encoded order data for the MatchboxRouter
     */
    function executeFirstStep(uint256 amountIn, bytes calldata orderData) external {
        if (msg.sender != OWNER) revert Unauthorized();
        if (!isActive) revert InvalidStep();
        if (currentStep != 0) revert InvalidStep();

        // Transfer collateral from owner to this contract
        IERC20(COLLATERAL_TOKEN).safeTransferFrom(OWNER, address(this), amountIn);

        // Approve router to spend collateral
        IERC20(COLLATERAL_TOKEN).forceApprove(ROUTER, amountIn);

        // Execute trade via router
        (bool success, bytes memory result) = ROUTER.call(orderData);
        if (!success) revert TransferFailed();

        uint256 amountOut = abi.decode(result, (uint256));

        currentStep++;
        emit StepExecuted(0, amountIn, amountOut);
    }

    /**
     * @notice Withdraws funds from the Matchbox (owner only)
     * @param token The token to withdraw (collateral or conditional token)
     * @param amount The amount to withdraw (0 = withdraw all)
     */
    function withdrawFunds(address token, uint256 amount) external {
        if (msg.sender != OWNER) revert Unauthorized();

        uint256 balance;
        if (token == COLLATERAL_TOKEN) {
            balance = IERC20(COLLATERAL_TOKEN).balanceOf(address(this));
        } else {
            // For conditional tokens (ERC1155), we need the token ID
            // This is a simplified version - in production, track token IDs
            balance = IERC20(token).balanceOf(address(this));
        }

        uint256 withdrawAmount = amount == 0 ? balance : amount;
        if (withdrawAmount > balance) revert TransferFailed();

        IERC20(token).safeTransfer(OWNER, withdrawAmount);

        emit FundsWithdrawn(token, withdrawAmount);
    }

    /**
     * @notice Emergency function to deactivate the sequence
     */
    function deactivate() external {
        if (msg.sender != OWNER) revert Unauthorized();
        isActive = false;
    }

    /*//////////////////////////////////////////////////////////////
                        AUTOMATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes the next step in the sequence
     * @dev Called by trusted automation network (e.g., Chainlink Automation)
     * @param orderData Encoded order data for the MatchboxRouter
     */
    function executeNextStep(bytes calldata orderData) external {
        if (!isActive) revert InvalidStep();
        if (currentStep >= totalSteps) revert SequenceComplete();

        Rule memory rule = sequence[currentStep];

        // First, try to redeem the previous step's tokens
        if (currentStep > 0) {
            _redeemPreviousStep(currentStep - 1);
        }

        // Get available collateral balance
        uint256 availableBalance = IERC20(COLLATERAL_TOKEN).balanceOf(address(this));
        if (availableBalance == 0) revert TransferFailed();

        // Determine amount to use for this step
        uint256 amountIn = rule.useAllFunds ? availableBalance : rule.specificAmount;
        if (amountIn > availableBalance) {
            amountIn = availableBalance;
        }

        // Approve router to spend collateral
        IERC20(COLLATERAL_TOKEN).forceApprove(ROUTER, amountIn);

        // Execute trade via router with constraints
        (bool success, bytes memory result) = ROUTER.call(orderData);

        if (!success) {
            // If trade fails (e.g., price constraint not met), skip this step
            emit StepSkipped(currentStep, "Price constraint not met");
            isActive = false;
            return;
        }

        uint256 amountOut = abi.decode(result, (uint256));

        currentStep++;
        emit StepExecuted(currentStep - 1, amountIn, amountOut);

        // If this was the last step, deactivate
        if (currentStep >= totalSteps) {
            isActive = false;
        }
    }

    /**
     * @notice Checks if the next step is ready to execute
     * @dev Used by Chainlink Automation for upkeep checks
     * @return upkeepNeeded Whether the next step can be executed
     * @return performData Encoded data for executeNextStep
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (!isActive || currentStep >= totalSteps) {
            return (false, "");
        }

        // Check if the previous market has resolved
        if (currentStep > 0) {
            Rule memory prevRule = sequence[currentStep - 1];
            // Check if condition is resolved by checking if payout denominator is set
            uint256 denominator = CTF.payoutDenominator(prevRule.conditionId);
            if (denominator == 0) {
                // Market not resolved yet
                return (false, "");
            }
        }

        upkeepNeeded = true;
        performData = ""; // In production, this would include order data
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeems conditional tokens from a previous step
     * @param stepIndex The step index to redeem
     */
    function _redeemPreviousStep(uint256 stepIndex) internal {
        Rule memory rule = sequence[stepIndex];

        // Get the position ID for the conditional token
        bytes32 collectionId = CTF.getCollectionId(bytes32(0), rule.conditionId, 1 << rule.outcomeIndex);

        uint256 positionId = CTF.getPositionId(COLLATERAL_TOKEN, collectionId);

        // Check balance of conditional tokens
        uint256 balance = CTF.balanceOf(address(this), positionId);

        if (balance > 0) {
            // Redeem the tokens for collateral
            uint256[] memory indexSets = new uint256[](1);
            indexSets[0] = 1 << rule.outcomeIndex;

            CTF.redeemPositions(COLLATERAL_TOKEN, bytes32(0), rule.conditionId, indexSets);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the rule for a specific step
     * @param stepIndex The step index
     * @return The rule for that step
     */
    function getRule(uint256 stepIndex) external view returns (Rule memory) {
        if (stepIndex >= totalSteps) revert InvalidStep();
        return sequence[stepIndex];
    }

    /**
     * @notice Gets the entire sequence
     * @return The array of rules
     */
    function getSequence() external view returns (Rule[] memory) {
        return sequence;
    }
}

