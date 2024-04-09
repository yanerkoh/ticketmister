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

    constructor() ERC721("TEST", "TEST") {}

    // 1 token = 1 ticket

    // counter for eventId - incremented each time a new event is created
    uint256 private eventsCreated;

    // counter for categoryId - incremented each time a new category is created
    uint256 private categoriesCreated;

    // counter for ticketId - incremented each time a new ticket is created
    uint256 private ticketCreated;

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

    // eventId mapped to array of ticketIds of the sold tickets
    mapping(uint256 => uint256[]) private ticketsSold;

    // array storing all of the events
    EventInfo[] allEventsArray;

    struct EventInfo {
        uint256 eventId;
        address organiser;
        string eventName;
        string eventDescription;
        uint256 numberOfTickets; // total number of tickets for this event
        uint256 soldTickets; // number of tickets currently sold for this event
        uint256 maxResalePercentage; // maximum percentage that the ticket price can be resold for - might be complicated with decimals
        bool isActive;
        CategoryInfo[] ticketCatgories;
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
}
