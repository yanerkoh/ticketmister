// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

interface ITicketMgmt {
    function createTickets(
        uint256 eventId,
        uint256 categoryId,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) external returns (uint256[] memory ticketIds);

    function getEventId(uint256 ticketId) external view returns (uint256);
    function getTicketOwner(uint256 ticketId) external view returns (address);
    function isForSale(uint256 ticketId) external view returns (bool);
    function getOriginalTicketPrice(uint256 ticketId) external view returns (uint256);
    function getResaleTicketPrice(uint256 ticketId) external view returns (uint256);

    function transferTicket(uint256 ticketId, address newOwner) external;
}

contract TicketMgmt is ERC721URIStorage, ITicketMgmt {
    constructor() ERC721("TicketMister", "TMT") {}
    
    // counter for ticketId - incremented each time a new tick is created;
    uint256 private ticketCounter;

    // mapping of ticketId to TicketInfo
    mapping(uint256 => TicketInfo) public tickets;

    struct TicketInfo {
        uint256 ticketId;
        uint256 eventId;
        uint256 categoryId;
        address owner;
        bool isOnSale;
        uint256 originalPrice;
        uint256 resalePrice;
    }

    event TicketsCreated(uint256 eventId, uint256 categoryId, uint256 numberOfTickets, address owner);
    event TicketTransferred(uint256 ticketId, address previousOwner, address newOwner);

    function createTickets(
        uint256 eventId,
        uint256 categoryId,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) external override returns (uint256[] memory ticketIds) {
        ticketIds = new uint256[](numberOfTickets);

        for (uint256 i = 0; i < numberOfTickets; i++) {
            uint256 ticketId = ticketCounter;
            ticketCounter++;
            require(
                !_exists(ticketId),
                "Ticket token has already been created."
            );
            _safeMint(tx.origin, ticketId);

            TicketInfo memory newTicket = TicketInfo({
                ticketId: ticketId,
                eventId: eventId,
                categoryId: categoryId,
                owner: tx.origin,
                isOnSale: true,
                originalPrice: ticketPrice,
                resalePrice: 0
            });

            tickets[ticketId] = newTicket;
            ticketIds[i] = ticketId;
        }

        emit TicketsCreated(eventId, categoryId, numberOfTickets, tx.origin);
        return ticketIds;
    }

    function getEventId(uint256 ticketId) public view override returns (uint256) {
        return tickets[ticketId].eventId;
    }

    function getTicketOwner(uint256 ticketId) public view override returns (address) {
        return tickets[ticketId].owner;
    }

    function isForSale(uint256 ticketId) public view override returns (bool) {
        return tickets[ticketId].isOnSale;
    }

    function getOriginalTicketPrice(uint256 ticketId) public view override returns (uint256) {
        return tickets[ticketId].originalPrice;
    }

    function getResaleTicketPrice(uint256 ticketId) public view override returns (uint256) {
        return tickets[ticketId].resalePrice;
    }

    function transferTicket(uint256 ticketId, address newOwner) public override {
        address currentOwner = tickets[ticketId].owner;
        _transfer(currentOwner, newOwner, ticketId);
        tickets[ticketId].owner = newOwner;
        emit TicketTransferred(ticketId, currentOwner, newOwner);
    }

}
