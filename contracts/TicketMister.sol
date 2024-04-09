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

    // To keep track of how many events were created
    uint256 private numberOfEvents = 0;

    // tokenId => TicketInformation
    // each token mapped to the respective ticket information
    mapping(uint256 => TicketInformation) private ticketNFTS;

    // user's address => array of tokenIds
    // each user mapped to the array of tokenIds they own
    mapping(address => uint256[]) private userTickets;

    // user's address => array of event information
    // each user mapped to the array of events they created
    mapping(address => EventInformation[]) private eventsCreatedByUser;

    // eventId => event information
    // each event mapped to the respective event information
    mapping(uint256 => EventInformation) private allEvents;

    // eventId => array of tokenIds
    // each event mapped to the array of tokenIds for that event
    mapping(uint256 => uint256[]) private ticketsSoldForEvent;
    
    // array storing all of the events
    EventInformation[] allEventsArray;

    struct TicketInformation {
        
        uint256 eventId;
        
        uint256 tokenId;
        
        uint256 price;
        
        address owner;
        
        bool isListed;
        
        string tokenURI;
    }

    struct EventInformation {
        
        string name;
        
        address creatorAddress;
        
        uint256 eventID; // based on uint256 private numberOfEvents
        
        uint256 ticketsForSale; // when initialising an event, use to define the number of tickets on sale 
        
        uint256 ticketsSold;
        
        uint256 maxTicketPrice;
        
        uint256 minTicketPrice;
        
        bool isActive;
        
        uint256 ticketPrice;
    }

}