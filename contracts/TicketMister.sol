// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
//use uint256 private _tokenIds instead;
//to increment: _tokenIds++;
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TicketMister is ERC721URIStorage, Ownable {
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
        uint256[] categoryIds; // list of categoryIds for this event
    }

    struct CategoryInfo {
        uint256 eventId; // event that this category is tagged to
        uint256 categoryId;
        string categoryName;
        string description;
        uint256 ticketPrice;
        uint256 numberOfTickets; // number of tickets for this category
    }

    struct TicketInfo {
        uint256 eventId; // event that this category is tagged to
        uint256 categoryId; // category that this ticket is tagged to
        uint256 ticketId;
        address owner;
        uint256 originalPrice;
        bool isForSale;
        uint256 resalePrice;
    }

    // Events
    event eventCreated(uint256 eventId, string eventName, address organiser);
    event ticketSold(
        uint256 ticketId,
        address buyer,
        address seller,
        uint256 price
    );
    event ticketListedForResale(
        uint256 ticketId,
        address seller,
        uint256 newResalePrice,
        uint256 resalePercentage
    ); // emitted when listing ticket (NOT by organisers)
    event ticketUnlistedFromResale(uint256 ticketId, address seller);

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
            new uint256[](0)
        );

        // Update events mapping (eventId => EventInfo)
        events[newEventId] = newEvent;

        // push new event to allEventsArray
        allEventsArray.push(newEvent);

        // push new event to eventsOrganised mapping (organiser => eventId[])
        eventsOrganised[msg.sender].push(newEventId);

        emit eventCreated(newEventId, eventName, msg.sender);
    }

    // user needs to create event first before they can create category and mint tickets for that event
    function createCategory(
        uint256 eventId,
        string memory categoryName,
        string memory description,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) public onlyOrganiser(eventId) {
        categoryIdCounter++;
        uint256 newCategoryId = categoryIdCounter;

        // Create new category struct
        CategoryInfo memory newCategory = CategoryInfo(
            eventId,
            newCategoryId,
            categoryName,
            description,
            ticketPrice,
            numberOfTickets
        );

        // Update categories mapping (categoryId => CategoryInfo)
        categories[newCategoryId] = newCategory;

        // push new category to event's ticketCategories array
        events[eventId].categoryIds.push(newCategoryId);

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
        address to, // address of owner (im unsure what the use of this is - 'to' & 'owner' are the same address when minting)
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
                newTicketId,
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

    function buyTicket(uint256 ticketId) public payable {
        require(_exists(ticketId), "This ticket doesn't exist!");
        TicketInfo memory ticketInfo = tickets[ticketId];
        address previousOwner = ticketInfo.owner;
        require(ticketInfo.isForSale, "This ticket is not for sale!");
        require(
            msg.value == ticketInfo.resalePrice,
            "You must pay the exact amount that this is listed for!"
        );
        require(msg.sender != previousOwner, "You already own this ticket!");
        address payable ownerPayable = payable(previousOwner);

        // transfer ticket to new owner
        transferTicket(previousOwner, msg.sender, ticketId);
        ownerPayable.transfer(msg.value);

        // update respective ticketInfo
        tickets[ticketId].owner = msg.sender;
        tickets[ticketId].isForSale = false;
        tickets[ticketId].resalePrice = 0;

        // remove ticket from ticketsOwned for previous owner
        for (
            // iterate through ticketsOwned for previous owner
            uint256 index = 0;
            index < ticketsOwned[previousOwner].length;
            index++
        ) {
            // find the ticketId in the array
            if (ticketsOwned[previousOwner][index] == ticketId) {
                removeTicketFromTicketsOwned(previousOwner, index);
                break;
            }
        }

        // add ticket to new owner
        ticketsOwned[msg.sender].push(ticketId);

        // remove ticket from ticketsForSale for event
        for (
            // iterate through ticketsForSale for event
            uint256 index = 0;
            index < ticketsForSale[ticketInfo.eventId].length;
            index++
        ) {
            // find the ticketId in the array
            if (ticketsForSale[ticketInfo.eventId][index] == ticketId) {
                removeTicketFromTicketsForSale(ticketInfo.eventId, index);
                break;
            }
        }

        // update eventInfo if ticket was bought from organiser
        if (previousOwner == events[ticketInfo.eventId].organiser) {
            events[ticketInfo.eventId].soldTickets++;
        }

        emit ticketSold(ticketId, msg.sender, previousOwner, msg.value);
    }

    /*
    // Function to list a ticket for resale
    function listTicketForResale(
        uint256 ticketId,
        uint256 resalePercentage
    ) public {
        require(ownerOf(ticketId) == msg.sender, "You don't own this ticket");
        TicketInfo storage ticket = tickets[ticketId];
        require(ticket.isForSale == false, "Ticket is already listed for sale");
        require(ticket.resalePrice == 0, "Ticket is already listed for resale");
        require(
            resalePercentage > 0 && resalePercentage <= 100,
            "Invalid resale percentage"
        );

        // Calculate resale price based on the resale percentage
        uint256 newResalePrice = ticket.originalPrice.mul(resalePercentage).div(
            100
        );

        // Update ticket info
        ticket.resalePrice = newResalePrice;
        ticket.resalePercentage = resalePercentage;
        ticket.isForSale = true;

        // Add ticket to ticketsForSale mapping
        ticketsForSale[ticket.eventId].push(ticketId);

        emit ticketListedForResale(
            ticketId,
            msg.sender,
            newResalePrice,
            resalePercentage
        );
    }

    // Function to unlist a ticket from resale
    function unlistTicketFromResale(uint256 ticketId) public {
        require(ownerOf(ticketId) == msg.sender, "You don't own this ticket");
        TicketInfo storage ticket = tickets[ticketId];
        require(ticket.isForSale == true, "Ticket is not listed for resale");

        // Update ticket info
        ticket.isForSale = false;
        ticket.resalePrice = 0;
        ticket.resalePercentage = 0;

        // Remove ticket from ticketsForSale mapping
        removeTicketFromTicketsForSale(ticket.eventId, ticketId);

        emit ticketUnlistedFromResale(ticketId, msg.sender);
    }
    */

    function removeTicketFromTicketsOwned(
        address owner,
        uint256 index
    ) private {
        // index = index of ticket to remove
        for (uint256 i = index; i < ticketsOwned[owner].length - 1; i++) {
            // shift all tickets from index onwards, to the left
            ticketsOwned[owner][i] = ticketsOwned[owner][i + 1];
        }

        // remove last element
        ticketsOwned[owner].pop();
    }

    function removeTicketFromTicketsForSale(
        uint256 eventId,
        uint256 index
    ) private {
        // index = index of ticket to remove
        for (uint256 i = index; i < ticketsForSale[eventId].length - 1; i++) {
            // shift all tickets from index onwards, to the left
            ticketsForSale[eventId][i] = ticketsForSale[eventId][i + 1];
        }

        // remove last element
        ticketsForSale[eventId].pop();
    }

    function transferTicket(
        address from,
        address to,
        uint256 ticketId
    ) private {
        require(ownerOf(ticketId) == from, "Ticket not owned by sender");
        require(to != address(0), "Invalid recipient address");
        require(from != address(0), "Invalid sender address");
        _transfer(from, to, ticketId);
    } // im not sure whether this works - because we completely remove 'tokens'

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

    // This is the function to see all of the tickets being sold for a specific event
    function viewAllEventTickets(
        uint256 eventId
    ) public view returns (TicketInfo[] memory) {
        require(eventId <= eventIdCounter, "This event doesn't exist");
        uint256[] memory ticketIdsForSale = ticketsForSale[eventId];
        TicketInfo[] memory allEventTickets = new TicketInfo[](
            ticketIdsForSale.length
        );
        for (
            uint256 counter = 0;
            counter < ticketIdsForSale.length;
            counter++
        ) {
            uint256 ticketId = ticketIdsForSale[counter];
            TicketInfo memory ticketInfo = tickets[ticketId];
            allEventTickets[counter] = ticketInfo;
        }
        return (allEventTickets);
    }

    function getEventInfo(
        uint256 eventId
    )
        public
        view
        returns (
            uint256,
            address,
            string memory,
            string memory,
            uint256,
            uint256,
            uint256,
            bool,
            uint256[] memory
        )
    {
        require(eventId <= eventIdCounter, "This event does not exist");
        EventInfo memory eventInfo = events[eventId];
        return (
            eventInfo.eventId,
            eventInfo.organiser,
            eventInfo.eventName,
            eventInfo.eventDescription,
            eventInfo.numberOfTickets,
            eventInfo.soldTickets,
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
        returns (
            uint256,
            uint256,
            string memory,
            string memory,
            uint256,
            uint256
        )
    {
        require(
            categoryId <= categoryIdCounter,
            "This category does not exist"
        );
        CategoryInfo memory categoryInfo = categories[categoryId];
        return (
            categoryInfo.eventId,
            categoryInfo.categoryId,
            categoryInfo.categoryName,
            categoryInfo.description,
            categoryInfo.ticketPrice,
            categoryInfo.numberOfTickets
        );
    }

    function getTicketInfo(
        uint256 ticketId
    )
        public
        view
        returns (uint256, uint256, uint256, address, uint256, bool, uint256)
    {
        require(ticketId <= ticketIdCounter, "This ticket does not exist");
        TicketInfo memory ticketInfo = tickets[ticketId];
        return (
            ticketInfo.eventId,
            ticketInfo.categoryId,
            ticketInfo.ticketId,
            ticketInfo.owner,
            ticketInfo.originalPrice,
            ticketInfo.isForSale,
            ticketInfo.resalePrice
        );
    }
}
