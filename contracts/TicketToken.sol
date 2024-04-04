pragma solidity ^0.5.0;

import "./ERC20.sol";

contract TicketToken { //TKT
    ERC20 erc20Contract;
    uint256 supplyLimit;
    uint256 currentSupply;
    address owner;
    
    constructor() public {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
        supplyLimit = 1000000000;
    }

    event tKTChecked(uint256 credit);

    function getTKT() public payable {
        uint256 amt = msg.value / 10000000000000000; // Get TKT eligible
        require(erc20Contract.totalSupply() + amt < supplyLimit, "TKT supply is not enough");
        // erc20Contract.transferFrom(owner, msg.sender, amt);
        erc20Contract.mint(msg.sender, amt);
        
    }

    function checkTKT() public returns(uint256) {
        uint256 credit = erc20Contract.balanceOf(msg.sender);
        emit tKTChecked(credit);
        return credit;
    }

    function transferTKT(address receipt, uint256 amt) public {
        erc20Contract.transfer(receipt, amt);
    }

    function transferTKTFrom(address from, address to, uint256 amt) public {
        erc20Contract.transferFrom(from, to, amt);
    }

    function giveAllowance(address receipt, uint256 amt) public {
        erc20Contract.approve(receipt, amt);
    }

}