pragma solidity ^0.5.0;

import "./ERC20.sol";

contract TicketToken {
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

    event creditChecked(uint256 credit);

    function getCredit() public payable {
        uint256 amt = msg.value / 10000000000000000; // Get Ticket tokens eligible
        require(erc20Contract.totalSupply() + amt < supplyLimit, "Ticket supply is not enough");
        // erc20Contract.transferFrom(owner, msg.sender, amt);
        erc20Contract.mint(msg.sender, amt);
        
    }

    function checkCredit() public returns(uint256) {
        uint256 credit = erc20Contract.balanceOf(msg.sender);
        emit creditChecked(credit);
        return credit;
    }

    function transferCredit(address receipt, uint256 amt) public {
        erc20Contract.transfer(receipt, amt);
    }

    function transferCreditFrom(address from, address to, uint256 amt) public {
        erc20Contract.transferFrom(from, to, amt);
    }

    function giveAllowance(address receipt, uint256 amt) public {
        erc20Contract.approve(receipt, amt);
    }

}