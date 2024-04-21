const TicketMgmt = artifacts.require("TicketMgmt");
const EventMgmt = artifacts.require("EventMgmt");
const TicketMkt = artifacts.require("TicketMkt");
const BigNumber = require('bignumber.js');

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

    const eventLocation = "Test Location";

    const eventDate = "12/12/2024";

    const maxResalePercentage = 20;

    const result = await ticketMktInstance.createEvent(
      eventName,
      eventDescription,
      eventLocation,
      eventDate,
      maxResalePercentage,
      { from: owner }
    );

    const eventCreated = result.logs.find(
      (log) => log.event === "EventCreated"
    );

    assert.exists(eventCreated, "EventCreated not emitted");

    const emittedEventId = eventCreated.args.eventId.toNumber();

    const event = await ticketMktInstance.getEventInfo(emittedEventId);

    assert.isTrue(
      event.isActive,
      "Event should be active after creation"
    );

    const emittedEventName = eventCreated.args.eventName;

    const emittedEventOrganiser = eventCreated.args.eventOrganiser;

    const emittedEventDescription = eventCreated.args.eventDescription;

    const emittedEventLocation = eventCreated.args.eventLocation;

    const emittedEventDate = eventCreated.args.eventDate;

    const emittedMaxResalePercentage =
      eventCreated.args.maxResalePercentage.toNumber();

    assert.equal(emittedEventName, eventName, "Event name does not match");

    assert.equal(
      emittedEventDescription,
      eventDescription,
      "Event description does not match"
    );

    assert.equal(
        emittedEventLocation,
        eventLocation,
        "Event location does not match"
    );

      assert.equal(
        emittedEventDate,
        eventDate,
        "Event date does not match"
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
      (log) => log.event === "TicketCategoryCreated"
    );

    assert.exists(createCategory, "createTicketCategory result is undefined");

    const emittedCategoryId = createCategory.args.categoryId;

    const emittedCategoryName = createCategory.args.categoryName;

    const emittedCategoryDescription = createCategory.args.categoryDescription;

    const emittedTicketPrice = createCategory.args.ticketPrice;

    const emittedNumberOfTickets = createCategory.args.numberOfTickets;

    assert.equal(
      emittedCategoryName,
      categoryName,
      "Category name does not match"
    );

    assert.equal(
      emittedCategoryDescription,
      categoryDescription,
      "Category description does not match"
    );

    assert.equal(
      emittedTicketPrice,
      ticketPrice,
      "Ticket Price does not match"
    );

    assert.equal(
      emittedNumberOfTickets,
      numberOfTickets,
      "Number of tickets does not match"
    );

    const tickets = await ticketMktInstance.getCategoryTickets(emittedCategoryId);

    assert.equal(
        tickets.length,
        numberOfTickets,
        "Number of tickets should match"
    );

    const ticketsOnSale = await ticketMktInstance.getTicketsOnSale(eventId);

    const ticketIdsOnSale = ticketsOnSale.map(ticketBN => ticketBN.toNumber());

    for (let i = 0; i < tickets.length; i++) {
        const ticketId = tickets[i];
        const ticketIdBN = new BigNumber(ticketId);
        const isOnSale = ticketIdsOnSale.includes(ticketIdBN.toNumber());
        assert.isTrue(
            isOnSale,
            `Ticket with ID ${ticketId} should be on sale for event ${eventId}`
        );
    }
        
  });

  it("Creation of category cannot be done by a user who is not the event organiser", async () => {
    const eventId = 1;
    const categoryName = "Test Cat 2";
    const categoryDescription = "This is a test category 2.";
    const ticketPrice = web3.utils.toWei("1", "ether");
    const numberOfTickets = 10;

    const nonOrganizerAccount = user1;

    try {
        await ticketMktInstance.createTicketCategory(
            eventId,
            categoryName,
            categoryDescription,
            ticketPrice,
            numberOfTickets,
            { from: nonOrganizerAccount }
        );

        assert.fail("Category creation should have reverted for non-organizer");
    } catch (error) {
        assert(
            error.message.includes("revert"),
            `Expected revert but got error: ${error.message}`
        );
    }
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

  it("Test Updating of Event Location", async () => {
    const newLocation = "New event location";

    await ticketMktInstance.updateEventLocation(1, newLocation, {
      from: owner,
    });

    const eventInfo = await ticketMktInstance.getEventInfo(1);

    const getLocation = eventInfo.eventLocation;

    assert.equal(
      getLocation,
      newLocation,
      "Event location not updated correctly"
    );
  });

  it("Test Updating of Event Date", async () => {
    const newDate = "New event date";

    await ticketMktInstance.updateEventDate(1, newDate, {
      from: owner,
    });

    const eventInfo = await ticketMktInstance.getEventInfo(1);

    const getDate = eventInfo.eventDate;

    assert.equal(
      getDate,
      newDate,
      "Event date not updated correctly"
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

  it("Test Buy Tickets - For Ticket Buyers", async () => {

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

    // Check for the 'ticketBought' event and 'RewardUsed' event
    assert.equal(result.logs[0].event, "RewardUsed", "Event RewardUsed should be emitted");
    assert.equal(result.logs[1].event, "RewardEarned", "Event RewardEarned should be emitted");
    assert.equal(result.logs[2].event, "TicketBought", "Event TicketBought should be emitted");
    assert.equal(result.logs[2].args.buyer, user1, "The buyer in the event should be user1");

  });

  it("Test Cancellation of Event and Refund", async () => {
    const eventName = "Test Event 2";

    const eventDescription = "This is a test event to test the cancellation and refund.";

    const eventLocation = "Test Location for cancellation";

    const eventDate = "12/12/2024";
    
    const maxResalePercentage = 20;

    await ticketMktInstance.createEvent(
      eventName,
      eventDescription,
      eventLocation,
      eventDate,
      maxResalePercentage,
      { from: owner }
    );

    const categoryName = "Test Cat 2";

    const eventId = 2;

    const categoryDescription = "This is a test category to test the cancellation and refund.";

    const ticketPrice = web3.utils.toWei("1", "ether");

    const numberOfTickets = 10;

    await ticketMktInstance.createTicketCategory(
      eventId,
      categoryName,
      categoryDescription,
      ticketPrice,
      numberOfTickets,
      { from: owner }
    );

    const user1PayableValue = await ticketMktInstance.checkDiscountedPrice(12, { from: user1});
    const user2PayableValue = await ticketMktInstance.checkDiscountedPrice(13, { from: user2});

    await ticketMktInstance.buyTicket(12, { from: user1, value: user1PayableValue });

    await ticketMktInstance.buyTicket(13, { from: user2, value: user2PayableValue });

    const refundAmount = await ticketMktInstance.getRefundAmount(eventId);

    const ticketOwner1 = await ticketMktInstance.getTicketOwner(12);

    const ticketOwner2 = await ticketMktInstance.getTicketOwner(13);

    const originalBalance1 = await web3.eth.getBalance(ticketOwner1);

    const originalBalance2 = await web3.eth.getBalance(ticketOwner2);

    const expectedRefund1 = await ticketMktInstance.getOriginalTicketPrice(1);

    const expectedRefund2 = await ticketMktInstance.getOriginalTicketPrice(2);

    await ticketMktInstance.cancelEventAndRefund(eventId, {
      from: owner,
      value: refundAmount,
    });

    const newBalance1 = await web3.eth.getBalance(ticketOwner1);

    const newBalance2 = await web3.eth.getBalance(ticketOwner2);

    const ticketRefund1 = newBalance1 - originalBalance1;

    const ticketRefund2 = newBalance2 - originalBalance2;

    assert(
      ticketRefund1.toString() === expectedRefund1.toString(),
      "Ticket owner 1 was not refunded correctly"
    );

    assert(
      ticketRefund2.toString() === expectedRefund2.toString(),
      "Ticket owner 2 was not refunded correctly"
    );

    const event = await ticketMktInstance.getEventInfo(eventId);

    assert.isFalse(
      event.isActive,
      "Event should be inactive after cancellation"
    );
  });

  it("Test List Tickets for Resale - For Resellers", async () => {
    const resalePrice = web3.utils.toWei("1", "ether");
    const ticketId = 1;
    const ticketIdBN = new BigNumber(ticketId); // Replace with a ticket that user1 owns

    //User1 lists the ticket for resale
    await ticketMktInstance.listTicketForResale(ticketId, resalePrice, { from: user1 });


    // Check if the ticket is in the ticketsOnSale list for its event
    const eventId = 1; // Get the event ID from the ticket info
    const ticketsOnSale = await ticketMktInstance.getTicketsOnSale(eventId);
    const ticketIdsOnSale = ticketsOnSale.map(ticketBN => ticketBN.toNumber());
    assert.isTrue(ticketIdsOnSale.includes(ticketIdBN.toNumber()), "Ticket should be listed in the tickets on sale for its event");
  });

  it("Test Unlist Ticket from Resale - For Resellers", async () => {
    const resalePrice = web3.utils.toWei("1", "ether");
    const ticketId = 1;  
    const ticketIdBN = new BigNumber(ticketId);

    //User1 unlists the ticket from resale
    await ticketMktInstance.unlistTicketFromResale(ticketId, { from: user1 });

    // Check if the ticket is removed from ticketsOnSale list for its event
    const eventId = 1; // Get the event ID from the ticket info
    const ticketsOnSale = await ticketMktInstance.getTicketsOnSale(eventId);
    const ticketIdsOnSale = ticketsOnSale.map(ticketBN => ticketBN.toNumber());
    assert.isFalse(ticketIdsOnSale.includes(ticketIdBN.toNumber()), "Ticket should not be listed in the tickets on sale for its event");
  });


  it("Test Gift Ticket - For Resellers", async () => {
    const ticketPrice = web3.utils.toWei("1", "ether");
    const ticketId = 2;
    const payableValue = await ticketMktInstance.checkDiscountedPrice(ticketId, { from: user1});

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
