// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;
/**
 * @title TicketSmartContract
 * @dev  Implements ticketing system along with its various functions
 */

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
//use uint256 private _tokenIds instead;
//to increment: _tokenIds++;
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TicketMister is ERC721URIStorage, Ownable {
    uint256 private _tokenIds;

    constructor() ERC721("TicketMister", "TMT") {}

    // 1 token = 1 ticket

    // counter for eventId - incremented each time a new event is created
    uint256 private eventIdCounter;

    // counter for categoryId - incremented each time a new category is created
    uint256 private categoryIdCounter;

    // counter for ticketId - incremented each time a new ticket is created
    uint256 private ticketIdCounter;

    // ticketId mapped to TicketInfo struct
    mapping(uint256 => TicketInfo) private tickets;

    // eventId mapped to EventInfo struct
    mapping(uint256 => EventInfo) private events;

    // categoryId mapped to CategoryInfo struct
    mapping(uint256 => CategoryInfo) private categories;

    // address of event organiser mapped to an array of eventIds
    mapping(address => uint256[]) private eventsOrganised;

    // address of owner mapped to array of ticketIds of the tickets they own
    mapping(address => uint256[]) private ticketsOwned;

    // eventId mapped to array of ticketIds of all tickets on sale (whether first sale or resale)
    mapping(uint256 => uint256[]) private ticketsForSale;

    // array storing all of the events
    EventInfo[] allEventsArray;

    struct EventInfo {
        uint256 eventId;
        address organiser;
        string eventName;
        string eventDescription;
        uint256 numberOfTickets; // total number of tickets for this event
        uint256 soldTickets; // number of tickets already sold for this event - updated when someone buys from organiser
        uint256 maxResalePercentage; // maximum percentage that the ticket price can be resold for - might be complicated with decimals
        bool isActive;
        CategoryInfo[] ticketCategories;
    }

    struct CategoryInfo {
        uint256 eventId; // event that this category is tagged to
        string categoryName;
        string description;
        uint256 ticketPrice;
        uint256 numberOfTickets; // number of tickets for this category
    }

    struct TicketInfo {
        uint256 eventId; // event that this category is tagged to
        uint256 categoryId; // where is our categoryId generated from?
        address owner;
        uint256 originalPrice;
        bool isForSale;
        uint256 resalePrice;
    }

    // function to create a new event - anyone can create a new event
    function createEvent(
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) public {
        eventIdCounter++;
        uint256 newEventId = eventIdCounter;

        // Create new event struct
        EventInfo memory newEvent = EventInfo(
            newEventId,
            msg.sender,
            eventName,
            eventDescription,
            0,
            0,
            maxResalePercentage,
            true,
            new CategoryInfo[](0)
        );

        // Update events mapping (eventId => EventInfo)
        events[newEventId] = newEvent;

        // push new event to allEventsArray
        allEventsArray.push(newEvent);

        // push new event to eventsOrganised mapping (organiser => eventId[])
        eventsOrganised[msg.sender].push(newEventId);
    }

    // user needs to create event first before they can create category and mint tickets for that event
    function createCategory(
        uint256 eventId,
        string memory categoryName,
        string memory description,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) private onlyOrganiser(eventId) {
        categoryIdCounter++;
        uint256 newCategoryId = categoryIdCounter;

        // Create new category struct
        CategoryInfo memory newCategory = CategoryInfo(
            eventId,
            categoryName,
            description,
            ticketPrice,
            numberOfTickets
        );

        // Update categories mapping (categoryId => CategoryInfo)
        categories[newCategoryId] = newCategory;

        // push new category to event's ticketCategories array
        events[eventId].ticketCategories.push(newCategory);

        // mint tickets for this category
        mintTickets(
            msg.sender,
            eventId,
            newCategoryId,
            numberOfTickets,
            ticketPrice,
            msg.sender
        );

        // increment total number of tickets for this event
        events[eventId].numberOfTickets += numberOfTickets;
    }

    // this function will be called when createCategory is called, to mint the tickets for that respective category
    function mintTickets(
        address to, // address of owner (im unsure what the use of this is but we follow github for now)
        uint256 eventId, // will be generated when event is created
        uint256 categoryId, // will be generated when category is created
        uint256 numberOfTickets,
        uint256 ticketPrice,
        address owner // address of owner
    ) private onlyOrganiser(eventId) {
        for (uint256 counter = 0; counter < numberOfTickets; counter++) {
            ticketIdCounter++;
            uint256 newTicketId = ticketIdCounter;
            require(!_exists(newTicketId), "Token has already been minted");
            _safeMint(to, newTicketId);

            // Each ticketId will have the ticket information mapped to it (ticketID => TicketInfo)
            // Create new ticket struct
            TicketInfo memory newTicket = TicketInfo(
                eventId,
                categoryId,
                owner,
                ticketPrice,
                true, // when minted, will be for sale
                ticketPrice // set resale price as original price at the start. buying will always use resale price
            );

            // Update tickets mapping (ticketId => TicketInfo)
            tickets[newTicketId] = newTicket;

            // push tickets minted to 'ticketsForSale' (eventId => uint256[] List of ticketIds for sale)
            ticketsForSale[eventId].push(newTicketId);

            // push tickets minted to 'ticketsOwned' for organiser (owner => uint256[] List of ticketIds owned)
            ticketsOwned[owner].push(newTicketId);
        }
    }

    // only the organiser can execute a specific function
    modifier onlyOrganiser(uint256 eventId) {
        address eventOrganiserAddress = getEventOrganiserAddress(eventId);
        require(
            msg.sender == eventOrganiserAddress,
            "Only the organiser of this event can execute this"
        );
        _;
    }

    function getEventOrganiserAddress(
        uint256 eventId
    ) private view returns (address) {
        return events[eventId].organiser;
    }
}
