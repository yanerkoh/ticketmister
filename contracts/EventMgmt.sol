// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;

import "./TicketMgmt.sol";

interface IEventMgmt {
    function createEvent(
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) external returns (uint256 eventId);

    function createCategory(
        uint256 eventId,
        string memory categoryName,
        string memory categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) external returns (uint256 categoryId);

    function getEventTickets(uint256 eventId) external view returns (uint256[] memory tickets);
    function getEventCategories(uint256 eventId) external view returns (uint256[] memory categories);
    function getCategoryTickets(uint256 categoryId) external view returns (uint256[] memory tickets);
    function isEventOrganiser(uint256 eventId, address user) external view returns (bool);

    function getEventId(uint256 ticketId) external view returns (uint256);
    function getTicketOwner(uint256 ticketId) external view returns (address);
    function isForSale(uint256 ticketId) external view returns (bool);
    function getTicketPrice(uint256 ticketId) external view returns (uint256);

    function transferTicket(uint256 ticketId, address newOwner) external;
    
}

contract EventMgmt is IEventMgmt {

    ITicketMgmt private ITicketMgmtInstance;

    constructor(address _ticketMgmtAddress) {
        ITicketMgmtInstance = ITicketMgmt(_ticketMgmtAddress);
    }

    // counter for eventId - incremented each time a new event is created;
    uint256 private eventCounter;
    // counter for categoryId - incremented each time a new category is created;
    uint256 private categoryCounter;

    // mapping of eventId to EventInfo
    mapping(uint256 => EventInfo) public events;
    // mapping of categoryId to CategoryInfo
    mapping(uint256 => CategoryInfo) public categories;

    struct EventInfo {
        uint256 eventId;
        string eventName;
        address eventOrganiser;
        string eventDescription;
        uint256 maxResalePercentage;
        bool isActive;
        uint256[] categoryIds;
        uint256[] ticketIds;
    }

    struct CategoryInfo {
        uint256 eventId;
        uint256 categoryId;
        string categoryName;
        string categoryDescription;
        uint256 ticketPrice;
        uint256[] ticketIds;
    }

    event EventCreated(
        uint256 eventId,
        string eventName,
        address eventOrganiser,
        string eventDescription,
        uint256 maxResalePercentage
    );

    event CategoryCreated(
        uint256 categoryId,
        uint256 eventId,
        string categoryName,
        string categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    );

    function createEvent(
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) public override returns (uint256 eventId) {
        eventId = eventCounter;
        eventCounter++;
        EventInfo memory newEvent = EventInfo({
            eventId: eventId,
            eventName: eventName,
            eventOrganiser: tx.origin,
            eventDescription: eventDescription,
            maxResalePercentage: maxResalePercentage,
            isActive: true,
            categoryIds: new uint256[](0),
            ticketIds: new uint256[](0)
        });
        events[eventId] = newEvent;

        emit EventCreated(
            eventId,
            eventName,
            tx.origin,
            eventDescription,
            maxResalePercentage
        );
    }

    function createCategory(
        uint256 eventId,
        string memory categoryName,
        string memory categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) public override returns (uint256 categoryId) {
        categoryId = categoryCounter;
        categoryCounter++;
        CategoryInfo memory newCategory = CategoryInfo({
            eventId: eventId,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryDescription: categoryDescription,
            ticketPrice: ticketPrice,
            ticketIds: ITicketMgmtInstance.createTickets(eventId, categoryId, ticketPrice, numberOfTickets)
        });

        categories[categoryId] = newCategory;
        events[eventId].categoryIds.push(categoryId);
        for (uint256 index = 0; index < numberOfTickets; index++) {
            events[eventId].ticketIds.push(newCategory.ticketIds[index]);
        }

        emit CategoryCreated(
            categoryId,
            eventId,
            categoryName,
            categoryDescription,
            ticketPrice,
            numberOfTickets
        );
        return categoryId;
    }

    function getEventTickets(uint256 eventId) public view override returns (uint256[] memory) {
        require((eventId >= 0) && (eventId < eventCounter) , "Event does not exist!");
        uint256[] memory eventTickets = events[eventId].ticketIds;
        return eventTickets;
    }

    function getEventCategories(uint256 eventId) public view override returns (uint256[] memory) {
        require((eventId >= 0) && (eventId < eventCounter) , "Event does not exist!");
        uint256[] memory eventCategories = events[eventId].categoryIds;
        return eventCategories;
    }

    function getCategoryTickets(uint256 categoryId) public view override returns (uint256[] memory) {
        require((categoryId >= 0) && (categoryId < categoryCounter), "Category does not exist!");
        uint256[] memory tickets = categories[categoryId].ticketIds;
        return tickets;
    }

    function isEventOrganiser(uint256 eventId, address user) public view override returns (bool) {
        require((eventId >= 0) && (eventId < eventCounter) , "Event does not exist!");
        return events[eventId].eventOrganiser == user;
    }

    function getTicketOwner(uint256 ticketId) public view override returns (address) {
        return ITicketMgmtInstance.getTicketOwner(ticketId);
    }

    function getTicketPrice(uint256 ticketId) public view override returns (uint256) {
        if (ITicketMgmtInstance.getResaleTicketPrice(ticketId) != 0) {
            return ITicketMgmtInstance.getResaleTicketPrice(ticketId);
        } else {
            return ITicketMgmtInstance.getOriginalTicketPrice(ticketId);
        }
    }

    function isForSale(uint256 ticketId) public view override returns (bool) {
        return ITicketMgmtInstance.isForSale(ticketId);
    }

    function transferTicket(uint256 ticketId, address newOwner) public override {
        ITicketMgmtInstance.transferTicket(ticketId, newOwner);
    }

    function getEventId(uint256 ticketId) public view override returns (uint256) {
       return ITicketMgmtInstance.getEventId(ticketId);
    }
}
