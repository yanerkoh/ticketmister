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

    function getTicketInfo(
        uint256 ticketId
    )
        external
        view
        returns (
            uint256 eventId,
            uint256 categoryId,
            address owner,
            bool isOnSale,
            uint256 originalPrice,
            uint256 resalePrice
        );

    function getEventId(uint256 ticketId) external view returns (uint256);

    function getTicketOwner(uint256 ticketId) external view returns (address);

    function isForSale(uint256 ticketId) external view returns (bool);

    function getOriginalTicketPrice(
        uint256 ticketId
    ) external view returns (uint256);

    function getResaleTicketPrice(
        uint256 ticketId
    ) external view returns (uint256);

    function transferTicket(uint256 ticketId, address newOwner) external;

    function listTicketForResale(
        uint256 ticketId,
        uint256 resalePrice
    ) external;

    function unlistTicketFromResale(uint256 ticketId) external;

    function cancelTicket(uint256 ticketId) external;
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

    event TicketsCreated(
        uint256 eventId,
        uint256 categoryId,
        uint256 numberOfTickets,
        address owner
    );
    event TicketTransferred(
        uint256 ticketId,
        address previousOwner,
        address newOwner
    );
    event TicketListedForResale(
        uint256 ticketId,
        address owner,
        uint256 resalePrice
    );
    event TicketUnlistedFromResale(uint256 ticketId, address owner);
    event TicketCancelled(uint256 ticketId);

    function createTickets(
        uint256 eventId,
        uint256 categoryId,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) external override returns (uint256[] memory ticketIds) {
        ticketIds = new uint256[](numberOfTickets);

        for (uint256 i = 0; i < numberOfTickets; i++) {
            ticketCounter++;
            uint256 ticketId = ticketCounter;
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

    function cancelTicket(uint256 ticketId) external override {
        _burn(ticketId);
        delete tickets[ticketId];
        emit TicketCancelled(ticketId);
    }

    function getTicketInfo(
        uint256 ticketId
    )
        external
        view
        override
        returns (uint256, uint256, address, bool, uint256, uint256)
    {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        TicketInfo memory ticketInfo = tickets[ticketId];
        return (
            ticketInfo.eventId,
            ticketInfo.categoryId,
            ticketInfo.owner,
            ticketInfo.isOnSale,
            ticketInfo.originalPrice,
            ticketInfo.resalePrice
        );
    }

    function getEventId(
        uint256 ticketId
    ) public view override returns (uint256) {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        return tickets[ticketId].eventId;
    }

    function getTicketOwner(
        uint256 ticketId
    ) public view override returns (address) {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        return tickets[ticketId].owner;
    }

    function isForSale(uint256 ticketId) public view override returns (bool) {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        return tickets[ticketId].isOnSale;
    }

    function getOriginalTicketPrice(
        uint256 ticketId
    ) public view override returns (uint256) {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        return tickets[ticketId].originalPrice;
    }

    function getResaleTicketPrice(
        uint256 ticketId
    ) public view override returns (uint256) {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        return tickets[ticketId].resalePrice;
    }

    function transferTicket(
        uint256 ticketId,
        address newOwner
    ) public override {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        address currentOwner = tickets[ticketId].owner;
        _transfer(currentOwner, newOwner, ticketId);
        tickets[ticketId].owner = newOwner;
        tickets[ticketId].isOnSale = false;
        emit TicketTransferred(ticketId, currentOwner, newOwner);
    }

    function listTicketForResale(
        uint256 ticketId,
        uint256 resalePrice
    ) public override {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        tickets[ticketId].isOnSale = true;
        tickets[ticketId].resalePrice = resalePrice;
        emit TicketListedForResale(ticketId, tx.origin, resalePrice);
    }

    function unlistTicketFromResale(uint256 ticketId) public override {
        require(
            (ticketId > 0) && (ticketId <= ticketCounter),
            "Ticket does not exist!"
        );
        tickets[ticketId].isOnSale = false;
        emit TicketUnlistedFromResale(ticketId, tx.origin);
    }
    
}
