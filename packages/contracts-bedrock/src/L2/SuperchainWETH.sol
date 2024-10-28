// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import { WETH98 } from "src/universal/WETH98.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Preinstalls } from "src/libraries/Preinstalls.sol";
import { SafeSend } from "src/universal/SafeSend.sol";

// Interfaces
import { ISemver } from "src/universal/interfaces/ISemver.sol";
import { IL2ToL2CrossDomainMessenger } from "src/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import { IL1Block } from "src/L2/interfaces/IL1Block.sol";
import { IETHLiquidity } from "src/L2/interfaces/IETHLiquidity.sol";
import { ICrosschainERC20 } from "src/L2/interfaces/ICrosschainERC20.sol";
import { Unauthorized, NotCustomGasToken } from "src/libraries/errors/CommonErrors.sol";

error CallerNotL2ToL2CrossDomainMessenger();

/// @notice Thrown when attempting to relay a message and the cross domain message sender is not `address(this)`
error InvalidCrossDomainSender();

/// @custom:proxied true
/// @custom:predeploy 0x4200000000000000000000000000000000000024
/// @title SuperchainWETH
/// @notice SuperchainWETH is a version of WETH that can be freely transfrered between chains
///         within the superchain. SuperchainWETH can be converted into native ETH on chains that
///         do not use a custom gas token.
contract SuperchainWETH is WETH98, ICrosschainERC20, ISemver {
    event SendETH(address indexed from, address indexed to, uint256 amount, uint256 destination);

    event RelayETH(address indexed from, address indexed to, uint256 amount, uint256 source);

    /// @notice Semantic version.
    /// @custom:semver 1.0.0-beta.9
    string public constant version = "1.0.0-beta.9";

    /// @inheritdoc WETH98
    function deposit() public payable override {
        if (IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) revert NotCustomGasToken();
        super.deposit();
    }

    /// @inheritdoc WETH98
    function withdraw(uint256 _amount) public override {
        if (IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) revert NotCustomGasToken();
        super.withdraw(_amount);
    }

    /// @inheritdoc WETH98
    function allowance(address owner, address spender) public view override returns (uint256) {
        if (spender == Preinstalls.Permit2) return type(uint256).max;
        return super.allowance(owner, spender);
    }

    /// @notice Mints WETH to an address.
    /// @param _to The address to mint WETH to.
    /// @param _amount The amount of WETH to mint.
    function _mint(address _to, uint256 _amount) internal {
        _balanceOf[_to] += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    /// @notice Burns WETH from an address.
    /// @param _from The address to burn WETH from.
    /// @param _amount The amount of WETH to burn.
    function _burn(address _from, uint256 _amount) internal {
        _balanceOf[_from] -= _amount;
        emit Transfer(_from, address(0), _amount);
    }

    /// @notice Allows the SuperchainTokenBridge to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function crosschainMint(address _to, uint256 _amount) external {
        if (msg.sender != Predeploys.SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();

        _mint(_to, _amount);

        // Mint from ETHLiquidity contract.
        if (!IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) {
            IETHLiquidity(Predeploys.ETH_LIQUIDITY).mint(_amount);
        }

        emit CrosschainMint(_to, _amount);
    }

    /// @notice Allows the SuperchainTokenBridge to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function crosschainBurn(address _from, uint256 _amount) external {
        if (msg.sender != Predeploys.SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();

        _burn(_from, _amount);

        // Burn to ETHLiquidity contract.
        if (!IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) {
            IETHLiquidity(Predeploys.ETH_LIQUIDITY).burn{ value: _amount }();
        }

        emit CrosschainBurn(_from, _amount);
    }

    /// @notice Sends ETH to some target address on another chain.
    /// @param _to      Address to send tokens to.
    /// @param _chainId  Chain ID of the destination chain.
    function sendETH(address _to, uint256 _chainId) public payable {
        if (IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) {
            revert NotCustomGasToken();
        }

        // Burn to ETHLiquidity contract.
        IETHLiquidity(Predeploys.ETH_LIQUIDITY).burn{ value: msg.value }();

        // Send message to other chain.
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER).sendMessage({
            _destination: _chainId,
            _target: address(this),
            _message: abi.encodeCall(this.relayETH, (msg.sender, _to, msg.value))
        });

        // Emit event.
        emit SendETH(msg.sender, _to, msg.value, _chainId);
    }

    /// @notice Relays ETH received from another chain.
    /// @param _from    Address of the msg.sender of sendETH on the source chain.
    /// @param _to     Address to relay tokens to.
    /// @param _amount     Amount of tokens to relay.
    function relayETH(address _from, address _to, uint256 _amount) external {
        // Receive message from other chain.
        IL2ToL2CrossDomainMessenger messenger = IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        if (msg.sender != address(messenger)) revert CallerNotL2ToL2CrossDomainMessenger();
        if (messenger.crossDomainMessageSender() != address(this)) revert InvalidCrossDomainSender();
        if (IL1Block(Predeploys.L1_BLOCK_ATTRIBUTES).isCustomGasToken()) {
            revert NotCustomGasToken();
        }

        // Mint from ETHLiquidity contract.
        IETHLiquidity(Predeploys.ETH_LIQUIDITY).mint(_amount);

        // Get source chain ID.
        uint256 source = messenger.crossDomainMessageSource();

        new SafeSend{ value: _amount }(payable(_to));

        // Emit event.
        emit RelayETH(_from, _to, _amount, source);
    }
}
