// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

interface IBalanceOf {
    function balanceOf(address) external view returns (uint256);
}

/// @dev Plain 18-decimal ERC-20 etched at the hardcoded SHD address.
contract MockSHD is ERC20 {
    function name() public pure override returns (string memory) {
        return "SnipeHead";
    }

    function symbol() public pure override returns (string memory) {
        return "SHD";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Faithful-enough Uniswap V2 pair: reserves + balances accounting, mint(), sync().
///      Includes the properties the factory relies on: mint() credits (balance - reserve),
///      sync() can be called by anyone, first mint locks MINIMUM_LIQUIDITY.
contract MockPair is ERC20 {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;
    uint112 private _r0;
    uint112 private _r1;

    constructor(address a, address b) {
        (token0, token1) = a < b ? (a, b) : (b, a);
    }

    function name() public pure override returns (string memory) {
        return "Mock LP";
    }

    function symbol() public pure override returns (string memory) {
        return "MLP";
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (_r0, _r1, 0);
    }

    function sync() external {
        _r0 = uint112(IBalanceOf(token0).balanceOf(address(this)));
        _r1 = uint112(IBalanceOf(token1).balanceOf(address(this)));
    }

    function mint(address to, address /*senderOrigin*/) external returns (uint256 liquidity) {
        uint256 b0 = IBalanceOf(token0).balanceOf(address(this));
        uint256 b1 = IBalanceOf(token1).balanceOf(address(this));
        uint256 a0 = b0 - _r0;
        uint256 a1 = b1 - _r1;
        uint256 supply = totalSupply();

        if (supply == 0) {
            liquidity = FixedPointMathLib.sqrt(a0 * a1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdEaD), MINIMUM_LIQUIDITY);
        } else {
            liquidity = FixedPointMathLib.min(a0 * supply / _r0, a1 * supply / _r1);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _r0 = uint112(b0);
        _r1 = uint112(b1);
    }
}

contract MockV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function createPair(address a, address b) external returns (address pair) {
        require(getPair[a][b] == address(0), "PAIR_EXISTS");
        pair = address(new MockPair(a, b));
        getPair[a][b] = pair;
        getPair[b][a] = pair;
    }
}
