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
    ticketMgmtInstance = await TicketMgmt.new({ from: owner });

    // Deploy EventMgmt contract with TicketMgmt address
    eventMgmtInstance = await EventMgmt.new(ticketMgmtInstance.address, { from: owner });

    // Deploy TicketMkt contract with EventMgmt address
    ticketMktInstance = await TicketMkt.new(eventMgmtInstance.address, { from: owner });

  });

  it("Testing Deployment of Contracts", async () => {
    assert.notEqual(ticketMgmtInstance.address, "0x0", "TicketMgmt contract not deployed");
    assert.notEqual(eventMgmtInstance.address, "0x0", "EventMgmt contract not deployed");
    assert.notEqual(ticketMktInstance.address, "0x0", "TicketMkt contract not deployed");
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
  
    const eventCreated = result.logs.find((log) => log.event === "EventCreated");
    
    assert.exists(eventCreated, "EventCreated not emitted");
  
    const emittedEventId = eventCreated.args.eventId.toNumber();
    const emittedEventName = eventCreated.args.eventName;
    const emittedEventOrganiser = eventCreated.args.eventOrganiser;
    const emittedEventDescription = eventCreated.args.eventDescription;
    const emittedMaxResalePercentage = eventCreated.args.maxResalePercentage.toNumber();
  
    assert.equal(emittedEventName, eventName, "Event name does not match");
    assert.equal(emittedEventDescription, eventDescription, "Event description does not match");
    assert.equal(emittedMaxResalePercentage, maxResalePercentage, "Max resale percentage does not match");

  });
  

  it("Test Creation of Category and Minting of Tickets", async () => {
    const eventName = "Test Event";
    const eventDescription = "This is a test event.";
    const maxResalePercentage = 20;
  
    // Create the event
    const createEventResult = await ticketMktInstance.createEvent(
      eventName,
      eventDescription,
      maxResalePercentage,
      { from: owner }
    );
  
    const eventCreated = createEventResult.logs.find((log) => log.event === "EventCreated");
    assert.exists(eventCreated, "EventCreated not emitted");
    const eventId = eventCreated.args.eventId.toNumber();
  
    // Create a ticket category for the event
    const categoryName = "VIP";
    const categoryDescription = "Exclusive VIP access";
    const ticketPrice = web3.utils.toWei("1", "ether");
    const numberOfTickets = 100;
  
    try {
      const createCategoryResult = await ticketMktInstance.createTicketCategory(
        eventId,
        categoryName,
        categoryDescription,
        ticketPrice,
        numberOfTickets,
        { from: owner }
      );
  
      const createCategory = createCategoryResult.logs.find((log) => log.event === "createCategory");
      assert.exists(createCategory, "createTicketCategory result is undefined");
  
    } catch (error) {
      console.error("Error creating ticket category:", error.message);
      assert.fail("createTicketCategory failed unexpectedly");
    }
  });

  it("Test Buying of Tickets", async () => {

  });

});