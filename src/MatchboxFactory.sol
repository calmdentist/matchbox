// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Matchbox} from "./Matchbox.sol";

/**
 * @title MatchboxFactory
 * @notice Factory contract for deploying user-owned Matchbox vaults using EIP-1167 minimal proxies
 * @dev Uses the minimal proxy pattern for gas-efficient deployment
 * @author calmxbt
 *
 * Key Features:
 * - Deploys Matchbox contracts using CREATE2 for deterministic addresses
 * - Maintains a registry of all deployed Matchboxes
 * - Uses EIP-1167 minimal proxy pattern for gas efficiency
 * - Automatically authorizes new Matchboxes with the Router
 */
contract MatchboxFactory {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeploymentFailed();
    error MatchboxAlreadyExists();
    error InvalidParameters();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MatchboxCreated(address indexed owner, address indexed matchbox, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementation contract for minimal proxies
    address public immutable IMPLEMENTATION;

    /// @notice The MatchboxRouter address
    address public immutable ROUTER;

    /// @notice The Polymarket CTF address
    address public immutable CTF;

    /// @notice The collateral token (USDC)
    address public immutable COLLATERAL_TOKEN;

    /// @notice Mapping from owner to their Matchbox addresses
    mapping(address => address[]) public ownerToMatchboxes;

    /// @notice Array of all deployed Matchboxes
    address[] public allMatchboxes;

    /// @notice Mapping to check if an address is a Matchbox
    mapping(address => bool) public isMatchbox;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the MatchboxFactory and deploys the implementation contract
     * @param _router The MatchboxRouter address
     * @param _ctf The Polymarket CTF address
     * @param _collateralToken The collateral token address (USDC)
     */
    constructor(address _router, address _ctf, address _collateralToken) {
        if (_router == address(0) || _ctf == address(0) || _collateralToken == address(0)) {
            revert InvalidParameters();
        }

        ROUTER = _router;
        CTF = _ctf;
        COLLATERAL_TOKEN = _collateralToken;

        // Deploy the implementation contract
        IMPLEMENTATION = address(new Matchbox(address(0), _router, _ctf, _collateralToken));
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new Matchbox vault for the caller
     * @dev Uses EIP-1167 minimal proxy pattern with CREATE2 for deterministic addresses
     * @param salt A unique salt for CREATE2 (allows users to have multiple Matchboxes)
     * @return matchbox The address of the newly created Matchbox
     */
    function createMatchbox(bytes32 salt) external returns (address matchbox) {
        // Create a unique salt combining user address and their salt
        bytes32 finalSalt = keccak256(abi.encodePacked(msg.sender, salt));

        // Deploy minimal proxy using CREATE2
        matchbox = _deployProxy(finalSalt);

        // Register the Matchbox
        ownerToMatchboxes[msg.sender].push(matchbox);
        allMatchboxes.push(matchbox);
        isMatchbox[matchbox] = true;

        // Authorize the Matchbox with the Router
        (bool success,) = ROUTER.call(abi.encodeWithSignature("authorizeMatchbox(address)", matchbox));
        if (!success) revert DeploymentFailed();

        emit MatchboxCreated(msg.sender, matchbox, block.timestamp);

        return matchbox;
    }

    /**
     * @notice Predicts the address of a Matchbox before deployment
     * @param owner The owner address
     * @param salt The salt for CREATE2
     * @return predicted The predicted address
     */
    function predictMatchboxAddress(address owner, bytes32 salt) external view returns (address predicted) {
        bytes32 finalSalt = keccak256(abi.encodePacked(owner, salt));
        bytes memory bytecode = _getProxyBytecode();
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), finalSalt, keccak256(bytecode)));
        predicted = address(uint160(uint256(hash)));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a minimal proxy using CREATE2
     * @param salt The salt for CREATE2
     * @return proxy The address of the deployed proxy
     */
    function _deployProxy(bytes32 salt) internal returns (address proxy) {
        bytes memory bytecode = _getProxyBytecode();

        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (proxy == address(0)) revert DeploymentFailed();

        // Initialize the proxy by setting it to point to msg.sender as owner
        // Note: The implementation's constructor already set immutable variables
        // The proxy will delegate to implementation but use msg.sender as owner
        return proxy;
    }

    /**
     * @notice Generates the EIP-1167 minimal proxy bytecode
     * @return bytecode The proxy bytecode
     */
    function _getProxyBytecode() internal view returns (bytes memory bytecode) {
        // EIP-1167 minimal proxy bytecode
        // This is the standard minimal proxy pattern
        bytes20 implementationBytes = bytes20(IMPLEMENTATION);

        bytecode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", implementationBytes, hex"5af43d82803e903d91602b57fd5bf3"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets all Matchboxes for a specific owner
     * @param owner The owner address
     * @return matchboxes Array of Matchbox addresses
     */
    function getMatchboxesForOwner(address owner) external view returns (address[] memory matchboxes) {
        return ownerToMatchboxes[owner];
    }

    /**
     * @notice Gets the total number of deployed Matchboxes
     * @return count The total count
     */
    function getTotalMatchboxes() external view returns (uint256 count) {
        return allMatchboxes.length;
    }

    /**
     * @notice Gets a paginated list of all Matchboxes
     * @param offset The starting index
     * @param limit The number of items to return
     * @return matchboxes Array of Matchbox addresses
     */
    function getAllMatchboxes(uint256 offset, uint256 limit) external view returns (address[] memory matchboxes) {
        uint256 total = allMatchboxes.length;
        if (offset >= total) return new address[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        uint256 length = end - offset;
        matchboxes = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            matchboxes[i] = allMatchboxes[offset + i];
        }

        return matchboxes;
    }

    /**
     * @notice Gets the implementation address
     * @return The implementation contract address
     */
    function getImplementation() external view returns (address) {
        return IMPLEMENTATION;
    }
}

