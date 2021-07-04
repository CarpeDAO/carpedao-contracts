// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/drafts/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CARPE is ERC20, ERC20Permit {
    uint256 constant tokenSupply = 1000000 * 1 ether;

    constructor() ERC20("Carpe DAO", "CARPE") ERC20Permit("Carpe DAO") {
        _mint(msg.sender, tokenSupply);
    }
}
