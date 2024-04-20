// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {
    mapping(address => uint256) private _balances;

    constructor() ERC20("RewardToken", "RT") {}

    // Function to mint new reward tokens
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // Function to burn reward tokens for redeeming them
    function burnFrom(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
}
