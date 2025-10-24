// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPolymarketCTF
 * @notice Interface for Polymarket's Conditional Token Framework (CTF)
 * @dev Based on Gnosis Conditional Tokens Framework
 */
interface IPolymarketCTF {
    /**
     * @notice Redeems conditional tokens for collateral after market resolution
     * @param collateralToken The collateral token address (e.g., USDC)
     * @param parentCollectionId The parent collection ID (0x0 for simple conditions)
     * @param conditionId The unique condition identifier
     * @param indexSets Array of index sets representing the positions to redeem
     */
    function redeemPositions(
        address collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external;

    /**
     * @notice Gets the outcome slot count for a condition
     * @param conditionId The unique condition identifier
     * @return The number of outcome slots (typically 2 for binary markets)
     */
    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint256);

    /**
     * @notice Gets the payout numerator for a specific outcome
     * @param conditionId The unique condition identifier
     * @param index The outcome index
     * @return The payout numerator for that outcome
     */
    function payoutNumerators(bytes32 conditionId, uint256 index) external view returns (uint256);

    /**
     * @notice Gets the payout denominator for a condition
     * @param conditionId The unique condition identifier
     * @return The payout denominator
     */
    function payoutDenominator(bytes32 conditionId) external view returns (uint256);

    /**
     * @notice Calculates the collection ID for a condition
     * @param parentCollectionId The parent collection ID
     * @param conditionId The condition ID
     * @param indexSet The index set representing the position
     * @return The collection ID
     */
    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) external view returns (bytes32);

    /**
     * @notice Gets the position ID (ERC1155 token ID) for a position
     * @param collateralToken The collateral token address
     * @param collectionId The collection ID
     * @return The position ID
     */
    function getPositionId(address collateralToken, bytes32 collectionId) external pure returns (uint256);

    /**
     * @notice Gets the balance of a specific position token
     * @param account The account to check
     * @param id The position ID (ERC1155 token ID)
     * @return The balance
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @notice Transfers position tokens
     * @param from The sender address
     * @param to The recipient address
     * @param id The position ID
     * @param value The amount to transfer
     * @param data Additional data
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;
}

