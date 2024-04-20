// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;

import "./TicketMgmt.sol";

interface IEventMgmt {
    function createEvent(
        string memory eventName,
        string memory eventDescription,
        string memory eventLocation,
        string memory eventDate,
        uint256 maxResalePercentage
    ) external returns (uint256 eventId);

    function createCategory(
        uint256 eventId,
        string memory categoryName,
        string memory categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) external returns (uint256 categoryId);

    function updateEventDescription(
        uint256 eventId,
        string memory newDescription
    ) external;

    function updateMaxResalePercentage(
        uint256 eventId,
        uint256 newMaxResalePercentage
    ) external;

    function updateEventLocation(
        uint256 eventId,
        string memory newLocation
    ) external;

    function updateEventDate(
        uint256 eventId,
        string memory newDate
    ) external;

    function cancelEvent(uint256 eventId) external;
    function cancelTicket(uint256 ticketId) external;

    function getEventInfo(
        uint256 eventId
    )
        external
        view
        returns (
            string memory eventName,
            address eventOrganiser,
            string memory eventDescription,
            string memory eventLocation,
            string memory eventDate,
            uint256 maxResalePercentage,
            bool isActive,
            uint256[] memory categoryIds
        );

    function getCategoryInfo(
        uint256 categoryId
    )
        external
        view
        returns (
            uint256 eventId,
            string memory categoryName,
            string memory categoryDescription,
            uint256 ticketPrice,
            uint256[] memory ticketIds
        );

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

    function getEventTickets(
        uint256 eventId
    ) external view returns (uint256[] memory tickets);

    function getCategoryTickets(
        uint256 categoryId
    ) external view returns (uint256[] memory tickets);

    function isEventOrganiser(
        uint256 eventId,
        address user
    ) external view returns (bool);

    function getEventId(uint256 ticketId) external view returns (uint256);

    function getTicketOwner(uint256 ticketId) external view returns (address);

    function isForSale(uint256 ticketId) external view returns (bool);

    function getTicketPrice(uint256 ticketId) external view returns (uint256);

    function getOriginalTicketPrice(
        uint256 ticketId
    ) external view returns (uint256);

    function transferTicket(uint256 ticketId, address newOwner) external;

    function calculateMaxResalePrice(
        uint256 ticketId
    ) external view returns (uint256);

    function listTicketForResale(
        uint256 ticketId,
        uint256 resalePrice
    ) external;

    function giftTicket(
        uint256 ticketId,
        address recipient
    ) external;

    function unlistTicketFromResale(uint256 ticketId) external;
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
        string eventLocation;
        string eventDate;
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
        string eventLocation,
        string eventDate,
        uint256 maxResalePercentage
    );

    event EventDescriptionUpdated(uint256 eventId, string newDescription);

    event EventLocationUpdated(uint256 eventId, string newDescription);

    event EventDateUpdated(uint256 eventId, string newDescription);

    event EventMaxResalePercentageUpdated(
        uint256 eventId,
        uint256 newMaxResalePercentage
    );

    event EventCancelled(uint256 eventId);

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
        string memory eventLocation,
        string memory eventDate,
        uint256 maxResalePercentage
    ) public override returns (uint256 eventId) {
        eventCounter++;
        eventId = eventCounter;
        EventInfo memory newEvent = EventInfo({
            eventId: eventId,
            eventName: eventName,
            eventOrganiser: tx.origin,
            eventDescription: eventDescription,
            eventLocation: eventLocation,
            eventDate: eventDate,
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
            eventLocation,
            eventDate,
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
        categoryCounter++;
        categoryId = categoryCounter;
        CategoryInfo memory newCategory = CategoryInfo({
            eventId: eventId,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryDescription: categoryDescription,
            ticketPrice: ticketPrice,
            ticketIds: ITicketMgmtInstance.createTickets(
                eventId,
                categoryId,
                ticketPrice,
                numberOfTickets
            )
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

    function updateEventDescription(
        uint256 eventId,
        string memory newDescription
    ) external override {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        events[eventId].eventDescription = newDescription;
        emit EventDescriptionUpdated(eventId, newDescription);
    }

    function updateEventLocation(
        uint256 eventId,
        string memory newLocation
    ) external override {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        events[eventId].eventLocation = newLocation;
        emit EventLocationUpdated(eventId, newLocation);
    }

    function updateEventDate(
        uint256 eventId,
        string memory newDate
    ) external override {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        events[eventId].eventDate = newDate;
        emit EventDateUpdated(eventId, newDate);
    }

    function updateMaxResalePercentage(
        uint256 eventId,
        uint256 newMaxResalePercentage
    ) external override {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        events[eventId].maxResalePercentage = newMaxResalePercentage;
        emit EventMaxResalePercentageUpdated(eventId, newMaxResalePercentage);
    }

    function cancelEvent(uint256 eventId) external override {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        require(events[eventId].isActive, "Event is not active!");
        events[eventId].isActive = false;
        emit EventCancelled(eventId);
    }

    function cancelTicket(uint256 ticketId) external override {
        ITicketMgmtInstance.cancelTicket(ticketId);
    }

    function getEventInfo(
        uint256 eventId
    )
        public
        view
        override
        returns (
            string memory,
            address,
            string memory,
            string memory,
            string memory,
            uint256,
            bool,
            uint256[] memory
        )
    {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        EventInfo memory eventInfo = events[eventId];
        return (
            eventInfo.eventName,
            eventInfo.eventOrganiser,
            eventInfo.eventDescription,
            eventInfo.eventLocation,
            eventInfo.eventDate,
            eventInfo.maxResalePercentage,
            eventInfo.isActive,
            eventInfo.categoryIds
        );
    }

    function getCategoryInfo(
        uint256 categoryId
    )
        public
        view
        override
        returns (
            uint256,
            string memory,
            string memory,
            uint256,
            uint256[] memory
        )
    {
        require(
            (categoryId > 0) && (categoryId <= categoryCounter),
            "Category does not exist!"
        );
        CategoryInfo memory categoryInfo = categories[categoryId];
        return (
            categoryInfo.eventId,
            categoryInfo.categoryName,
            categoryInfo.categoryDescription,
            categoryInfo.ticketPrice,
            categoryInfo.ticketIds
        );
    }

    function getTicketInfo(
        uint256 ticketId
    )
        public
        view
        override
        returns (uint256, uint256, address, bool, uint256, uint256)
    {
        return ITicketMgmtInstance.getTicketInfo(ticketId);
    }

    function getEventTickets(
        uint256 eventId
    ) public view override returns (uint256[] memory) {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        uint256[] memory eventTickets = events[eventId].ticketIds;
        return eventTickets;
    }

    function getCategoryTickets(
        uint256 categoryId
    ) public view override returns (uint256[] memory) {
        require(
            (categoryId > 0) && (categoryId <= categoryCounter),
            "Category does not exist!"
        );
        uint256[] memory categoryTickets = categories[categoryId].ticketIds;
        return categoryTickets;
    }

    function isEventOrganiser(
        uint256 eventId,
        address user
    ) public view override returns (bool) {
        require(
            (eventId > 0) && (eventId <= eventCounter),
            "Event does not exist!"
        );
        return events[eventId].eventOrganiser == user;
    }

    function getTicketOwner(
        uint256 ticketId
    ) public view override returns (address) {
        return ITicketMgmtInstance.getTicketOwner(ticketId);
    }

    function getTicketPrice(
        uint256 ticketId
    ) public view override returns (uint256 currentSalePrice) {
        if (ITicketMgmtInstance.getResaleTicketPrice(ticketId) != 0) {
            return ITicketMgmtInstance.getResaleTicketPrice(ticketId);
        } else {
            return ITicketMgmtInstance.getOriginalTicketPrice(ticketId);
        }
    }

    function getOriginalTicketPrice(
        uint256 ticketId
    ) public view override returns (uint256 originalTicketPrice) {
        return ITicketMgmtInstance.getOriginalTicketPrice(ticketId);
    }

    function isForSale(uint256 ticketId) public view override returns (bool) {
        return ITicketMgmtInstance.isForSale(ticketId);
    }

    function transferTicket(
        uint256 ticketId,
        address newOwner
    ) public override {
        ITicketMgmtInstance.transferTicket(ticketId, newOwner);
    }

    function calculateMaxResalePrice(
        uint256 ticketId
    ) public view override returns (uint256) {
        uint256 originalPrice = ITicketMgmtInstance.getOriginalTicketPrice(
            ticketId
        );
        uint256 maxResalePercentage = events[
            ITicketMgmtInstance.getEventId(ticketId)
        ].maxResalePercentage;
        return originalPrice + ((originalPrice * maxResalePercentage) / 100);
    }

    function listTicketForResale(
        uint256 ticketId,
        uint256 resalePrice
    ) public override {
        ITicketMgmtInstance.listTicketForResale(ticketId, resalePrice);
    }

    function giftTicket(
        uint256 ticketId,
        address recipient
    ) public override {
        ITicketMgmtInstance.transferTicket(ticketId, recipient);
    }

    function unlistTicketFromResale(uint256 ticketId) public override {
        ITicketMgmtInstance.unlistTicketFromResale(ticketId);
    }

    function getEventId(
        uint256 ticketId
    ) public view override returns (uint256) {
        return ITicketMgmtInstance.getEventId(ticketId);
    }
}