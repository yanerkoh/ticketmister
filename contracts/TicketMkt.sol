// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./EventMgmt.sol";
import "./TicketMgmt.sol";

contract TicketMkt {
    using SafeMath for uint256;

    IEventMgmt private IEventMgmtInstance;

    // address of event organiser mapped to an array of eventIds
    mapping(address => uint256[]) private eventsOrganised;
    // address of owner mapped to array of ticketIds of the tickets they own
    mapping(address => uint256[]) private ticketsOwned;
    // eventId mapped to array of ticketIds of all tickets on sale (whether first sale or resale)
    mapping(uint256 => uint256[]) private ticketsOnSale;

    event ticketBought(uint256 ticketId, address buyer, address seller);

    function createEvent(
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) private returns (uint256 eventId) {
        eventId = IEventMgmtInstance.createEvent(
            eventName,
            eventDescription,
            maxResalePercentage
        );
        eventsOrganised[msg.sender].push(eventId);
    }

    function createTicketCategory(
        uint256 eventId,
        string memory categoryName,
        string memory categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) private onlyEventOrganiser(eventId) returns (uint256 categoryId) {
        categoryId = IEventMgmtInstance.createCategory(
            eventId,
            categoryName,
            categoryDescription,
            ticketPrice,
            numberOfTickets
        );
        uint256[] memory tickets = IEventMgmtInstance.getCategoryTickets(
            categoryId
        );
        for (uint256 i = 0; i < tickets.length; i++) {
            ticketsOwned[msg.sender].push(tickets[i]);
            ticketsOnSale[eventId].push(tickets[i]);
        }
    }

    function buyTicket(uint256 ticketId) public payable {
        require(
            IEventMgmtInstance.isForSale(ticketId),
            "This ticket is not for sale!"
        );

        uint256 ticketPrice = IEventMgmtInstance.getTicketPrice(ticketId);
        require(
            msg.value == ticketPrice,
            "You must pay the exact amount that this is listed for!"
        );

        address currentOwner = IEventMgmtInstance.getTicketOwner(ticketId);
        require(msg.sender != currentOwner, "You already own this ticket!");

        // pay current owner
        address payable ownerPayable = payable(currentOwner);
        ownerPayable.transfer(msg.value);

        // transfer to new owner
        IEventMgmtInstance.transferTicket(ticketId, msg.sender);

        // update mappings
        for (
            // iterate through ticketsOwned for previous owner
            uint256 index = 0;
            index < ticketsOwned[currentOwner].length;
            index++
        ) {
            // find the ticketId in the array
            if (ticketsOwned[currentOwner][index] == ticketId) {
                removeTicketFromTicketsOwned(currentOwner, index);
                break;
            }
        }

        // update mappings
        ticketsOwned[msg.sender].push(ticketId);

        // update mappings
        uint256 eventId = IEventMgmtInstance.getEventId(ticketId);
        for (
            // iterate through ticketsForSale for event
            uint256 index = 0;
            index < ticketsOnSale[eventId].length;
            index++
        ) {
            // find the ticketId in the array
            if (ticketsOnSale[eventId][index] == ticketId) {
                removeTicketFromTicketsOnSale(eventId, index);
                break;
            }
        }

        emit ticketBought(ticketId, msg.sender, currentOwner);
    }

    function removeTicketFromTicketsOwned(address owner, uint256 index)
        private
    {
        // index = index of ticket to remove
        for (uint256 i = index; i < ticketsOwned[owner].length - 1; i++) {
            // shift all tickets from index onwards, to the left
            ticketsOwned[owner][i] = ticketsOwned[owner][i + 1];
        }

        // remove last element
        ticketsOwned[owner].pop();
    }

    function removeTicketFromTicketsOnSale(
        uint256 eventId,
        uint256 index
    ) private {
        // index = index of ticket to remove
        for (uint256 i = index; i < ticketsOnSale[eventId].length - 1; i++) {
            // shift all tickets from index onwards, to the left
            ticketsOnSale[eventId][i] = ticketsOnSale[eventId][i + 1];
        }

        // remove last element
        ticketsOnSale[eventId].pop();
    }

    modifier onlyEventOrganiser(uint256 eventId) {
        require(
            IEventMgmtInstance.isEventOrganiser(eventId, msg.sender),
            "Only event organiser can perform this action"
        );
        _;
    }
}
