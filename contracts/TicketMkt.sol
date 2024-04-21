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

    constructor(address _eventMgmtAddress) {
        IEventMgmtInstance = IEventMgmt(_eventMgmtAddress);
    }

    // address of event organiser mapped to an array of eventIds
    mapping(address => uint256[]) private eventsOrganised;
    // address of owner mapped to array of ticketIds of the tickets they own
    mapping(address => uint256[]) private ticketsOwned;
    // eventId mapped to array of ticketIds of all tickets on sale (whether first sale or resale)
    mapping(uint256 => uint256[]) private ticketsOnSale;
    // address of recipient mapped to reward points earned
    mapping(address => uint256) private rewardPoints;

    event EventCreated(
        uint256 eventId,
        string eventName,
        address eventOrganiser,
        string eventDescription,
        string eventLocation,
        string eventDate,
        uint256 maxResalePercentage
    );

    event TicketCategoryCreated(
        uint256 categoryId,
        uint256 eventId,
        string categoryName,
        string categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    );

    event TicketBought(uint256 ticketId, address buyer, address seller);
    event TicketGifted(uint256 ticketId, address recipient);
    event RewardEarned(address indexed recipient, uint256 amount);
    event RewardUsed(address indexed rewardUser, uint256 amount);


    event TicketRefunded(
        uint256 ticketId,
        address refundRecipient,
        uint256 refundAmount
    );
    event EventDescriptionUpdated(uint256 eventId, string newDescription);
    event EventLocationUpdated(uint256 eventId, string newLocation);
    event EventDateUpdated(uint256 eventId, string newDate);
    event MaxResalePercentageUpdated(uint256 eventId, uint256 newMaxPercentage);

    /**
        Main Functions For Event Organisers
     */
    function createEvent(
        string memory eventName,
        string memory eventDescription,
        string memory eventLocation,
        string memory eventDate,
        uint256 maxResalePercentage
    ) public returns (uint256 eventId) {
        eventId = IEventMgmtInstance.createEvent(
            eventName,
            eventDescription,
            eventLocation,
            eventDate,
            maxResalePercentage
        );
        eventsOrganised[msg.sender].push(eventId);

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

    function createTicketCategory(
        uint256 eventId,
        string memory categoryName,
        string memory categoryDescription,
        uint256 ticketPrice,
        uint256 numberOfTickets
    ) public onlyEventOrganiser(eventId) returns (uint256 categoryId) {
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
        emit TicketCategoryCreated(
        categoryId,
        eventId,
        categoryName,
        categoryDescription,
        ticketPrice,
        numberOfTickets
    );
    }

    function updateEventDescription(
        uint256 eventId,
        string memory newDescription
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateEventDescription(eventId, newDescription);
        emit EventDescriptionUpdated(eventId, newDescription);
    }

    function updateEventLocation(
        uint256 eventId,
        string memory newLocation
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateEventLocation(eventId, newLocation);
        emit EventLocationUpdated(eventId, newLocation);
    }

    function updateEventDate(
        uint256 eventId,
        string memory newDate
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateEventDate(eventId, newDate);
        emit EventDateUpdated(eventId, newDate);
    }

    function updateMaxResalePercentage(
        uint256 eventId,
        uint256 newMaxPercentage
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateMaxResalePercentage(eventId, newMaxPercentage);
        emit MaxResalePercentageUpdated(eventId, newMaxPercentage);
    }

    function getRefundAmount(
        uint256 eventId
    ) public view onlyEventOrganiser(eventId) returns (uint256 refundAmount) {
        uint256[] memory eventTickets = getEventTickets(eventId);
        refundAmount = 0;
        for (uint256 index = 0; index < eventTickets.length; index++) {
            uint256 ticketId = eventTickets[index];
            address ticketOwner = IEventMgmtInstance.getTicketOwner(ticketId);
            if (ticketOwner != msg.sender) {
                refundAmount += IEventMgmtInstance.getOriginalTicketPrice(
                    ticketId
                );
            }
        }
        return refundAmount;
    }

    function cancelEventAndRefund(
        uint256 eventId
    ) public payable onlyEventOrganiser(eventId) {
        require(
            msg.value == getRefundAmount(eventId),
            "You need to have the exact amount for refunding!"
        );
        uint256[] memory eventTickets = getEventTickets(eventId);
        for (uint256 index = 0; index < eventTickets.length; index++) {
            uint256 ticketId = eventTickets[index];
            address ticketOwner = IEventMgmtInstance.getTicketOwner(ticketId);

            if (ticketOwner != msg.sender) {
                address payable refundRecipient = payable(ticketOwner);
                uint256 refundAmount = IEventMgmtInstance
                    .getOriginalTicketPrice(ticketId);
                refundRecipient.transfer(refundAmount);
                emit TicketRefunded(ticketId, refundRecipient, refundAmount);
            }

            // remove from ticketsOwned
            for (
                // iterate through ticketsOwned for previous owner
                uint256 i = 0;
                i < ticketsOwned[ticketOwner].length;
                i++
            ) {
                // find the ticketId in the array
                if (ticketsOwned[ticketOwner][i] == ticketId) {
                    removeTicketFromTicketsOwned(ticketOwner, i);
                    break;
                }
            }

            // remove from ticketsOnSale
            if (IEventMgmtInstance.isForSale(ticketId)) {
                for (
                    // iterate through ticketsForSale for event
                    uint256 j = 0;
                    j < ticketsOnSale[eventId].length;
                    j++
                ) {
                    // find the ticketId in the array
                    if (ticketsOnSale[eventId][j] == ticketId) {
                        removeTicketFromTicketsOnSale(eventId, j);
                        break;
                    }
                }
            }

            IEventMgmtInstance.cancelTicket(ticketId);
        }
        IEventMgmtInstance.cancelEvent(eventId);
    }

    /**
        Main Functions For Ticket Buyers
     */
    function buyTicket(uint256 ticketId) public payable {
        require(
            IEventMgmtInstance.isForSale(ticketId),
            "This ticket is not for sale!"
        );

        uint256 ticketPrice = IEventMgmtInstance.getTicketPrice(ticketId);

        // Calculate discount based on reward points
        uint256 maxDiscountPercent = 20; // Maximum discount is 20%
        uint256 discountPer100Points = 2; // Each 100 points gives a 2% discount
        uint256 pointsForMaxDiscount = maxDiscountPercent / discountPer100Points * 100; // Calculate points needed for maximum discount

        uint256 discount = (rewardPoints[msg.sender] >= pointsForMaxDiscount) ? (ticketPrice * maxDiscountPercent / 100) :
                        (ticketPrice * rewardPoints[msg.sender] / 100 / discountPer100Points);

        // Calculate the number of points used based on the discount granted
        uint256 pointsUsed = (discount * 100 * 100) / (ticketPrice * discountPer100Points);
        rewardPoints[msg.sender] = rewardPoints[msg.sender] > pointsUsed ? rewardPoints[msg.sender] - pointsUsed : 0;
        emit RewardUsed(msg.sender, pointsUsed);
           
        uint256 payableValue = ticketPrice - discount;


        require(
            msg.value == payableValue,
            "You must pay the exact amount that this is listed for!"
        );

        address currentOwner = IEventMgmtInstance.getTicketOwner(ticketId);
        require(msg.sender != currentOwner, "You already own this ticket!");

                // Check if the ticket seller is the event organiser
        bool isEventOrganiser = IEventMgmtInstance.isEventOrganiser(
            IEventMgmtInstance.getEventId(ticketId),
            currentOwner
        );

        uint256 rewardsEarned = 0;
        if (isEventOrganiser) {
            // Calculate rewards earned
            rewardsEarned = (payableValue * 10) / 100; // 10% of ticket price as rewards
            rewardPoints[msg.sender] += rewardsEarned;
            emit RewardEarned(msg.sender, rewardsEarned);
        }


        // Calculate rewards earned
        //uint256 rewardsEarned = (payableValue * 10) / 100; // 10% of ticket price as rewards
        //rewardPoints[msg.sender] += rewardsEarned;

        // transfer to new owner
        IEventMgmtInstance.transferTicket(ticketId, msg.sender);

        // pay current owner
        address payable ownerPayable = payable(currentOwner);
        ownerPayable.transfer(payableValue);

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
        emit TicketBought(ticketId, msg.sender, currentOwner);
    }

    function checkRewardPointsBalance(
        address account
    ) public view returns (uint256) {
        return rewardPoints[account];
    }

    function checkDiscountedPrice(uint256 ticketId) public view returns (uint256 discountedPrice) {
        require(IEventMgmtInstance.isForSale(ticketId), "This ticket is not for sale!");

        uint256 originalPrice = IEventMgmtInstance.getTicketPrice(ticketId);

        // Calculate discount based on reward points
        uint256 maxDiscountPercent = 20; // Maximum discount is 20%
        uint256 discountPer100Points = 2; // Each 100 points gives a 2% discount
        uint256 pointsForMaxDiscount = maxDiscountPercent / discountPer100Points * 100; // Calculate points needed for maximum discount

        uint256 discount = (rewardPoints[msg.sender] >= pointsForMaxDiscount) ? (originalPrice * maxDiscountPercent / 100) :
                        (originalPrice * rewardPoints[msg.sender] / 100 / discountPer100Points);

        discountedPrice = originalPrice - discount;

        return discountedPrice;
    }


    /**
        Main Functions For Resellers
     */
    function listTicketForResale(uint256 ticketId, uint256 resalePrice) public {
        require(
            IEventMgmtInstance.getTicketOwner(ticketId) == msg.sender,
            "You do not own this ticket!"
        );
        require(
            IEventMgmtInstance.isForSale(ticketId) == false,
            "This ticket is already listed for sale!"
        );
        require(
            resalePrice <= IEventMgmtInstance.calculateMaxResalePrice(ticketId),
            "Resale price cannot be higher than the maximum resale price!"
        );

        IEventMgmtInstance.listTicketForResale(ticketId, resalePrice);
        ticketsOnSale[IEventMgmtInstance.getEventId(ticketId)].push(ticketId);
    }

    function giftTicket(uint256 ticketId, address recipient) public {
        address currentOwner = IEventMgmtInstance.getTicketOwner(ticketId);
        require(
            currentOwner == msg.sender,
            "You do not own this ticket!"
        );
        require(
            IEventMgmtInstance.isForSale(ticketId) == false,
            "This ticket is listed for sale! Unlist it to gift it!"
        );
        require(recipient != address(0), "Invalid recipient!");
        IEventMgmtInstance.giftTicket(ticketId, recipient);

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
        ticketsOwned[recipient].push(ticketId);
        emit TicketGifted(ticketId, recipient);
    }

    function unlistTicketFromResale(uint256 ticketId) public {
        require(
            IEventMgmtInstance.getTicketOwner(ticketId) == msg.sender,
            "You do not own this ticket!"
        );
        require(
            IEventMgmtInstance.isForSale(ticketId) == true,
            "This ticket is not listed for sale!"
        );

        IEventMgmtInstance.unlistTicketFromResale(ticketId);
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
    }

    /**
        Helper Functions (Private)
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

    /**
        Getter Functions
     */
    function getEventInfo(
        uint256 eventId
    )
        public
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
        )
    {
        return IEventMgmtInstance.getEventInfo(eventId);
    }

    function getCategoryInfo(
        uint256 categoryId
    )
        public
        view
        returns (
            uint256 eventId,
            string memory categoryName,
            string memory categoryDescription,
            uint256 ticketPrice,
            uint256[] memory ticketIds
        )
    {
        return IEventMgmtInstance.getCategoryInfo(categoryId);
    }

    function getTicketInfo(
        uint256 ticketId
    )
        public
        view
        returns (
            uint256 eventId,
            uint256 categoryId,
            address owner,
            bool isOnSale,
            uint256 originalPrice,
            uint256 resalePrice
        )
    {
        return IEventMgmtInstance.getTicketInfo(ticketId);
    }

    function getEventTickets(
        uint256 eventId
    ) public view returns (uint256[] memory eventTickets) {
        return IEventMgmtInstance.getEventTickets(eventId);
    }

    function getCategoryTickets(
        uint256 categoryId
    ) public view returns (uint256[] memory categoryTickets) {
        return IEventMgmtInstance.getCategoryTickets(categoryId);
    }

    /**
        Getter functions (State variables)
    */
    function getEventsOrganised()
        public
        view
        returns (uint256[] memory eventIds)
    {
        return eventsOrganised[msg.sender];
    }

    function getTicketsOwned()
        public
        view
        returns (uint256[] memory ticketIds)
    {
        return ticketsOwned[msg.sender];
    }

    function getTicketsOnSale(
        uint256 eventId
    ) public view returns (uint256[] memory ticketIds) {
        return ticketsOnSale[eventId];
    }

    function getTicketOwner(uint256 ticketId) public view returns (address) {
        return IEventMgmtInstance.getTicketOwner(ticketId);
    }

    function getOriginalTicketPrice(uint256 ticketId) public view returns (uint256) {
        return IEventMgmtInstance.getOriginalTicketPrice(ticketId);
    }

    /**
        Modifiers
     */
    modifier onlyEventOrganiser(uint256 eventId) {
        require(
            IEventMgmtInstance.isEventOrganiser(eventId, msg.sender),
            "Only event organiser can perform this action!"
        );
        _;
    }
}
