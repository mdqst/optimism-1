// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { OptimismMintableERC20Factory } from "src/universal/OptimismMintableERC20Factory.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @custom:proxied true
/// @title L1OptimismMintableERC20Factory
/// @notice Allows users to create L1 tokens that represent L2 native tokens.
contract L1OptimismMintableERC20Factory is OptimismMintableERC20Factory, Initializable {
    /// @notice
    address internal standardBridge;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @param _bridge Contract of the bridge on this domain.
    function initialize(address _bridge) public initializer {
        standardBridge = _bridge;
    }

    /// @notice Getter function for the bridge contract.
    /// @return Contract of the bridge on this domain.
    function bridge() public view virtual override returns (address) {
        return standardBridge;
    }
}
