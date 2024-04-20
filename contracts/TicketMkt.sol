// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./EventMgmt.sol";
import "./TicketMgmt.sol";
import "./RewardToken.sol";

contract TicketMkt {
    using SafeMath for uint256;

    IEventMgmt private IEventMgmtInstance;
    RewardToken private rewardToken;

    constructor(address _eventMgmtAddress, address _rewardTokenAddress) {
        IEventMgmtInstance = IEventMgmt(_eventMgmtAddress);
        rewardToken = RewardToken(_rewardTokenAddress);
    }

    // address of event organiser mapped to an array of eventIds
    mapping(address => uint256[]) private eventsOrganised;
    // address of owner mapped to array of ticketIds of the tickets they own
    mapping(address => uint256[]) private ticketsOwned;
    // eventId mapped to array of ticketIds of all tickets on sale (whether first sale or resale)
    mapping(uint256 => uint256[]) private ticketsOnSale;

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

    event ticketBought(uint256 ticketId, address buyer, address seller);
    event ticketGifted(uint256 ticketId, address recipient);
    event RewardEarned(address indexed recipient, uint256 amount);

    event ticketRefunded(
        uint256 ticketId,
        address refundRecipient,
        uint256 refundAmount
    );

    /**
        Main Functions For Event Organisers
     */
    function createEvent(
        string memory eventName,
        string memory eventDescription,
        uint256 maxResalePercentage
    ) public returns (uint256 eventId) {
        eventId = IEventMgmtInstance.createEvent(
            eventName,
            eventDescription,
            maxResalePercentage
        );
        eventsOrganised[msg.sender].push(eventId);

        emit EventCreated(
            eventId,
            eventName,
            tx.origin,
            eventDescription,
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
    }

    function updateEventDescription(
        uint256 eventId,
        string memory newDescription
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateEventDescription(eventId, newDescription);
    }

    function updateMaxResalePercentage(
        uint256 eventId,
        uint256 newMaxPercentage
    ) public onlyEventOrganiser(eventId) {
        IEventMgmtInstance.updateMaxResalePercentage(eventId, newMaxPercentage);
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
                emit ticketRefunded(ticketId, refundRecipient, refundAmount);
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
        require(
            msg.value == ticketPrice,
            "You must pay the exact amount that this is listed for!"
        );

        address currentOwner = IEventMgmtInstance.getTicketOwner(ticketId);
        require(msg.sender != currentOwner, "You already own this ticket!");

        // Redemption logic
        uint256 discount = 0;
        if (rewardToken.balanceOf(msg.sender) >= 100) {
            discount = (msg.value / 100); // Calculate discount
            rewardToken.burnFrom(msg.sender, 100); // Burn tokens for redemption
        }
        uint256 payableValue = msg.value - discount;

        // Calculate rewards earned
        uint256 rewardsEarned = (msg.value * 10) / 100; // 10% of ticket price as rewards
        rewardToken.mint(msg.sender, rewardsEarned);

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
        emit ticketBought(ticketId, msg.sender, currentOwner);
        emit RewardEarned(msg.sender, rewardsEarned);
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
        require(
            IEventMgmtInstance.getTicketOwner(ticketId) == msg.sender,
            "You do not own this ticket!"
        );
        require(
            IEventMgmtInstance.isForSale(ticketId) == false,
            "This ticket is listed for sale! Unlist it to gift it!"
        );
        require(recipient != address(0), "Invalid recipient!");
        IEventMgmtInstance.giftTicket(ticketId, recipient);
        emit ticketGifted(ticketId, recipient);
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
