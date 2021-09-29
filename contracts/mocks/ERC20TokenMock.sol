// contracts/ExampleToken.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20TokenMock is ERC20 {

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_) ERC20(name_, symbol_) public {
        _mint(msg.sender, totalSupply_ * 10 ** uint256(decimals()));
    }
}
