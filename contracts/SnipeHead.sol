///// Portal: https://www.snipehead.xyz \\\\\
//                  /\
//                 /  \
//                /    \
//               /______\
//               |  ***  |
//               |  ***  |
//               |  o o  |
//               |  ^ ^  |
//               | _/ \_ |
//                /     \
//               /_______\
//               |  ***  |
//               |  ***  |
//               |  /|\  |
//               |  / \  |
//               |_______|
//                  |||
//                  |||
//                 / 0 \
//                ( === )
//                 `---'
//                  /|\
//                 / | \
//                /  |  \
//               /___|___\
//                   |||
//                   |||
//                  /   \
//                 /     \
//                /_______\
//                |  ***  |
//                |  ***  |
//                |_______|
//                (   O   )
//                 ( === )
//                  `---'
/////////////////////////////////////////////////////

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

///// Portal: https://www.snipehead.xyz \\\\\
contract SnipeHead is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("SnipeHead", "SHD")
        ERC20Permit("SnipeHead")
    {
        _mint(recipient, 21000000000 * 10 ** decimals());
    }
}
