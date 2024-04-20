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
    const eventId = 1;  // Replace eventId with a created event id
    const ticketId = 101;  // Replace ticketId with a created ticket id

      //List a ticket for sale
      await ticketMktInstance.listTicketForResale(ticketId, ticketPrice, { from: user1 });

      //User2 buys the ticket
      const result = await ticketMktInstance.buyTicket(ticketId, {
        from: user2,
        value: ticketPrice
      });

      //Ensure the ticket is transferred to user2
      const ownerOfTicket = await ticketMgmtInstance.getTicketOwner(ticketId);
      assert.equal(ownerOfTicket, user2, "The ticket owner should be user2 after purchase");

      //Check for the 'ticketBought' event
      assert.equal(result.logs[0].event, "ticketBought", "Event ticketBought should be emitted");
      assert.equal(result.logs[0].args.buyer, user2, "The buyer in the event should be user2");
    });
  


  it("#8 Test List Tickets for Resale - For Resellers", async () => {
    const resalePrice = web3.utils.toWei("2", "ether");
    const ticketId = 101;  // Replace with a ticket that user1 owns

    //User1 lists the ticket for resale
    await ticketMktInstance.listTicketForResale(ticketId, resalePrice, { from: user1 });

    //Check if the ticket is marked as for sale
    const ticketInfo = await ticketMgmtInstance.getTicketInfo(ticketId);
    assert.equal(ticketInfo.isOnSale, true, "Ticket should be marked as for sale");
    assert.equal(ticketInfo.resalePrice, resalePrice, "Resale price should be set correctly");
  });


  it("#9 Test Gift Ticket - For Resellers", async () => {

    const ticketId = 101;  //Assuming user1 owns this ticket and it's not for sale

      //User1 gifts the ticket to user2
      await ticketMktInstance.giftTicket(ticketId, user2, { from: user1 });

      //Ensure the ticket is transferred to user2
      const ownerOfTicket = await ticketMgmtInstance.getTicketOwner(ticketId);
      assert.equal(ownerOfTicket, user2, "The ticket owner should be user2 after gifting");
    });


  it("#10 Test Unlist Ticket from Resale - For Resellers", async () => {
    const ticketId = 101;  //Assuming user1 owns this ticket and it's for sale

    //User1 unlists the ticket from resale
    await ticketMktInstance.unlistTicketFromResale(ticketId, { from: user1 });

    //Check if the ticket is unmarked as for sale
    const ticketInfo = await ticketMgmtInstance.getTicketInfo(ticketId);
    assert.equal(ticketInfo.isOnSale, false, "Ticket should be unmarked as for sale");
  });




});
