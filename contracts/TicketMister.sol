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

    // eventId mapped to array of ticketIds of all tickets sold
    mapping(uint256 => uint256[]) private ticketsSold;

    // mapping from user address to rewards balance
    mapping(address => uint256) public rewardsBalance;


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

    // Events Emitted
    event eventCreated(uint256 eventId, string eventName, address organiser);
    event RewardEarned(address indexed user, uint256 rewardsEarned);

    event ticketSold(
        uint256 ticketId,
        address buyer,
        address seller,
        uint256 price
    );
    event ticketListedForResale(
        uint256 ticketId,
        address seller,
        uint256 price
    ); // emitted when listing ticket (NOT by organisers)
    event ticketUnlistedFromResale(uint256 ticketId, address seller);

    // emitted when organiser updates event details
    event EventDetailsUpdated(uint eventId, string eventName, string eventDescription, uint256 maxResalePercentage);

    // emitted to check max resale price calculated
    event MaxResalePriceCalculated(uint maxResalePrice);

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

         // Apply automatic rewards redemption
        uint256 discount = 0;
        if (rewardsBalance[msg.sender] >= 100) { 
            discount = (msg.value / 100) * 1 ether; // maybe change to wei?
            if (discount > msg.value) {
                discount = msg.value;
            }
            rewardsBalance[msg.sender] -= 100; // Deduct 100 rewards
        }
        uint256 payableValue = msg.value - discount; //the payable value needs to change due to rewards

        // Calculate rewards for the buyer
        uint256 rewardsEarned = (msg.value * 10) / 100; // 10% of ticket price as rewards
        rewardsBalance[msg.sender] += rewardsEarned;

        // transfer ticket to new owner
        transferTicket(previousOwner, msg.sender, ticketId);
        ownerPayable.transfer(payableValue);

        // update respective ticketInfo
        tickets[ticketId].owner = msg.sender;
        tickets[ticketId].isForSale = false;
        tickets[ticketId].resalePrice = 0;
        
        // Update ticketsSold mapping
        ticketsSold[ticketInfo.eventId].push(ticketId);

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
        emit RewardEarned(msg.sender, rewardsEarned);
    }

    // Function to list a ticket for resale
    function listTicketForResale(uint256 ticketId, uint256 price) public {
        require(ownerOf(ticketId) == msg.sender, "You don't own this ticket");
        TicketInfo memory ticket = tickets[ticketId];
        require(ticket.isForSale == false, "Ticket is already listed for sale");
        require(ticket.resalePrice == 0, "Ticket is already listed for resale");

        // Calculate max resale price based on the resale percentage
        EventInfo memory eventInfo = events[ticket.eventId];  
        uint256 maxResalePrice = ticket.originalPrice * ((eventInfo.maxResalePercentage / 100) + 1);


        require(
            price <= maxResalePrice,
            "Resale price cannot be higher than the maximum resale price"
        );

        // Update ticket info
        tickets[ticketId].resalePrice = price;
        tickets[ticketId].isForSale = true;

        // Add ticket to ticketsForSale mapping
        ticketsForSale[ticket.eventId].push(ticketId);

        emit ticketListedForResale(ticketId, msg.sender, price);
    }

    // Function to unlist a ticket from resale
    function unlistTicketFromResale(uint256 ticketId) public {
        require(ownerOf(ticketId) == msg.sender, "You don't own this ticket");
        TicketInfo memory ticket = tickets[ticketId];
        require(ticket.isForSale == true, "Ticket is not listed for resale");

        // Update ticket info
        tickets[ticketId].isForSale = false;
        tickets[ticketId].resalePrice = 0;

        // Remove ticket from ticketsForSale mapping
        removeTicketFromTicketsForSale(ticket.eventId, ticketId);

        emit ticketUnlistedFromResale(ticketId, msg.sender);
    }

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


    // This is the function for a ticket owners to transfer multiple tickets
    function transferMultipleTickets(address to, uint256[] memory ticketIds) public {
        for (uint256 i = 0; i < ticketIds.length; i++) {
            uint256 ticketId = ticketIds[i];
            require(ownerOf(ticketId) == msg.sender, "You don't own all of these tickets");
            // Transfer ticket to new owner
            transferTicket(msg.sender, to, ticketId);
            // Update ticket owner in storage
            tickets[ticketId].owner = to;
        }
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

    // This is the function for organisers to cancel an event
    function cancelEventAndRefund(uint256 eventId) public onlyOrganiser(eventId) {
        EventInfo storage eventInfo = events[eventId];
        require(eventInfo.isActive, "Event is not active");

        // Refund ticket holders
        uint256[] memory ticketsSoldForEvent = ticketsSold[eventId];
        for (uint256 i = 0; i < ticketsSoldForEvent.length; i++) {
            uint256 ticketId = ticketsSoldForEvent[i];
            address payable ticketOwner = payable(ownerOf(ticketId));
            uint256 resalePrice = tickets[ticketId].resalePrice;
            if (resalePrice > 0) {
                ticketOwner.transfer(resalePrice);
            } else {
                ticketOwner.transfer(tickets[ticketId].originalPrice);
            }

            // Clear ticket ownership and remove it from mappings
            _transfer(ticketOwner, address(0), ticketId);
            delete tickets[ticketId];
        }
        
        // Unlist remaining tickets for sale
        delete ticketsForSale[eventId];

        // Mark event as inactive
        events[eventId].isActive = false;
    }


    // This function is for event organisers to update event details 
    function updateEventDetails(
        uint256 eventId,
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) public onlyOrganiser(eventId) {
        EventInfo storage eventInfo = events[eventId];
        
        // Check if the event is active
        require(eventInfo.isActive, "Event is not active");

        // Update event details
        events[eventId].eventName = eventName;
        events[eventId].eventDescription = eventDescription;
        events[eventId].maxResalePercentage = maxResalePercentage;
        
        emit EventDetailsUpdated(eventId, eventName, eventDescription, maxResalePercentage);
    }


    function viewMyTickets() public view returns (TicketInfo[] memory) {
        uint256[] memory ticketIds = ticketsOwned[msg.sender];
        TicketInfo[] memory myTickets = new TicketInfo[](ticketIds.length);
        for (uint256 i = 0; i < ticketIds.length; i++) {
            uint256 ticketId = ticketIds[i];
            myTickets[i] = tickets[ticketId];
        }
        return myTickets;
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

