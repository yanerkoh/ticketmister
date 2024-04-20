const TicketMgmt = artifacts.require("TicketMgmt");
const EventMgmt = artifacts.require("EventMgmt");
const TicketMkt = artifacts.require("TicketMkt");

contract("TicketMister Tests", (accounts) => {
  let ticketMgmtInstance;
  let eventMgmtInstance;
  let ticketMktInstance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before(async () => {
    // Deploy TicketMgmt contract
    ticketMgmtInstance = await TicketMgmt.deployed();

    // Deploy EventMgmt contract with TicketMgmt address

    eventMgmtInstance = await EventMgmt.new(ticketMgmtInstance.address, {
      from: accounts[1],
    });

    // Deploy TicketMkt contract with EventMgmt address
    ticketMktInstance = await TicketMkt.new(eventMgmtInstance.address, {
      from: accounts[1],
    });

    eventMgmtInstance = await EventMgmt.deployed();

    // Deploy TicketMkt contract with EventMgmt address
    ticketMktInstance = await TicketMkt.deployed();

  });

  it("Testing Deployment of Contracts", async () => {
    assert.notEqual(
      ticketMgmtInstance.address,
      "0x0",
      "TicketMgmt contract not deployed"
    );

    assert.notEqual(
      eventMgmtInstance.address,
      "0x0",
      "EventMgmt contract not deployed"
    );

    assert.notEqual(
      ticketMktInstance.address,
      "0x0",
      "TicketMkt contract not deployed"
    );
  });

  it("Test Creation of Event", async () => {
    const eventName = "Test Event";

    const eventDescription = "This is a test event.";

    const maxResalePercentage = 20;

    const result = await ticketMktInstance.createEvent(
      eventName,
      eventDescription,
      maxResalePercentage,
      { from: owner }
    );

    const eventCreated = result.logs.find(
      (log) => log.event === "EventCreated"
    );

    assert.exists(eventCreated, "EventCreated not emitted");

    const emittedEventId = eventCreated.args.eventId.toNumber();

    const emittedEventName = eventCreated.args.eventName;

    const emittedEventOrganiser = eventCreated.args.eventOrganiser;

    const emittedEventDescription = eventCreated.args.eventDescription;

    const emittedMaxResalePercentage =
      eventCreated.args.maxResalePercentage.toNumber();

    assert.equal(emittedEventName, eventName, "Event name does not match");

    assert.equal(
      emittedEventDescription,
      eventDescription,
      "Event description does not match"
    );

    assert.equal(
      emittedMaxResalePercentage,
      maxResalePercentage,
      "Max resale percentage does not match"
    );
  });

  it("Test Creation of Category and Minting of Tickets", async () => {
    const eventId = 1;

    const categoryName = "Test Cat";

    const categoryDescription = "This is a test category.";

    const ticketPrice = web3.utils.toWei("1", "ether");

    const numberOfTickets = 10;

    const createCategoryResult = await ticketMktInstance.createTicketCategory(
      eventId,
      categoryName,
      categoryDescription,
      ticketPrice,
      numberOfTickets,
      { from: owner }
    );

    const createCategory = createCategoryResult.logs.find(
      (log) => log.event === "CategoryCreated"
    );

    assert.exists(createCategory, "createTicketCategory result is undefined");
  });

  it("Test Updating of Event Description", async () => {
    const newDescription = "New event description";

    await ticketMktInstance.updateEventDescription(1, newDescription, {
      from: owner,
    });

    const eventInfo = await ticketMktInstance.getEventInfo(1);

    const getDescription = eventInfo.eventDescription;

    assert.equal(
      getDescription,
      newDescription,
      "Event description not updated correctly"
    );
  });

  it("Test Updating of Max Resale Percentage", async () => {
    const newMaxPercentage = 30;

    await ticketMktInstance.updateMaxResalePercentage(1, newMaxPercentage, {
      from: owner,
    });

    const eventInfo = await ticketMktInstance.getEventInfo(1);

    const getMaxPercentage = eventInfo.maxResalePercentage;

    assert.equal(
      getMaxPercentage,
      newMaxPercentage,
      "Max resale percentage not updated"
    );
  });

  it("Test Cancellation of Event and Refund", async () => {

  });

  /*it("Test Buying of Tickets", async () => {

  });
*/


  it("#7 Test Buy Tickets - For Ticket Buyers", async () => {

    const ticketPrice = web3.utils.toWei("1", "ether");
    const payableValue = ticketPrice
    const ticketId = 1;

    // List the ticket for sale at full price
    // await ticketMktInstance.listTicketForResale(ticketId, ticketPrice, { from: owner });

    // User1 buys the ticket with exact discounted price
    const result = await ticketMktInstance.buyTicket(ticketId, {
      from: user1,
      value: payableValue
    });

    // Ensure the ticket is transferred to user1
    const ownerOfTicket = await ticketMgmtInstance.getTicketOwner(ticketId);
    assert.equal(ownerOfTicket, user1, "The ticket owner should be user1 after purchase");

    // Check for the 'ticketBought' event and 'RewardEarned' event
    assert.equal(result.logs[0].event, "ticketBought", "Event ticketBought should be emitted");
    assert.equal(result.logs[1].event, "RewardEarned", "Event RewardEarned should be emitted");
    assert.equal(result.logs[0].args.buyer, user1, "The buyer in the event should be user1");

  });



  it("#8 Test List Tickets for Resale - For Resellers", async () => {
    const resalePrice = web3.utils.toWei("1", "ether");
    const ticketId = 1;  // Replace with a ticket that user1 owns

    //User1 lists the ticket for resale
    await ticketMktInstance.listTicketForResale(ticketId, resalePrice, { from: user1 });


    // Check if the ticket is in the ticketsOnSale list for its event
    const eventId = 1; // Get the event ID from the ticket info
    const ticketsOnSale = await ticketMktInstance.getTicketsOnSale(eventId);
    assert.isTrue(ticketsOnSale.includes(ticketId), "Ticket should be listed in the tickets on sale for its event");
  });

  it("#10 Test Unlist Ticket from Resale - For Resellers", async () => {
    const resalePrice = web3.utils.toWei("1", "ether");
    const ticketId = 1;  


    //User1 unlists the ticket from resale
    await ticketMktInstance.unlistTicketFromResale(ticketId, { from: user1 });

    // Check if the ticket is removed from ticketsOnSale list for its event
    const eventId = 1; // Get the event ID from the ticket info
    const ticketsOnSale = await ticketMktInstance.getTicketsOnSale(eventId);
    assert.isFalse(ticketsOnSale.includes(ticketId), "Ticket should not be listed in the tickets on sale for its event");
  });


  it("#9 Test Gift Ticket - For Resellers", async () => {
    const ticketPrice = web3.utils.toWei("1", "ether");
    const payableValue = ticketPrice
    const ticketId = 2;


    // User1 buys the ticket 
    const result = await ticketMktInstance.buyTicket(ticketId, {
      from: user1,
      value: payableValue
    });

  
    //User1 gifts the ticket to user2
    await ticketMktInstance.giftTicket(ticketId, user2, { from: user1 });

    //Ensure the ticket is transferred to user2
    const ownerOfTicket = await ticketMgmtInstance.getTicketOwner(ticketId);
    assert.equal(ownerOfTicket, user2, "The ticket owner should be user2 after gifting");
  });





});
