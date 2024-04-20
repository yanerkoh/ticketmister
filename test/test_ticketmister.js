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
  
    const eventsOrganised = await ticketMktInstance.eventsOrganised(owner);
  
    assert.equal(eventsOrganised.length, 1, "eventsOrganised length is incorrect");
    assert.equal(eventsOrganised[0].toNumber(), emittedEventId, "Event ID not stored in eventsOrganised mapping");
  });
  

  it("Test Creation of Category and Minting of Tickets", async () => {
    const eventId = 0;
    const categoryName = "VIP";
    const categoryDescription = "Exclusive VIP access";
    const ticketPrice = web3.utils.toWei("1", "ether");
    const numberOfTickets = 100;
  
    const result = await ticketMktInstance.createTicketCategory(
      eventId,
      categoryName,
      categoryDescription,
      ticketPrice,
      numberOfTickets,
      { from: owner }
    );
  
    const eventCreated = result.logs.find((log) => log.event === "EventCreated");
    assert.exists(eventCreated, "EventCreated not emitted");
    const emittedEventId = eventCreated.args.eventId.toNumber();
    const createdEvent = await eventMgmtInstance.events(emittedEventId);
    assert.equal(createdEvent.eventName, eventName, "Event name does not match");
    assert.equal(createdEvent.eventDescription, eventDescription, "Event description does not match");
    assert.equal(createdEvent.maxResalePercentage.toNumber(), maxResalePercentage, "Max resale percentage does not match");

    const eventsOrganised = await ticketMktInstance.eventsOrganised(owner);
    assert.equal(eventsOrganised.length, 1, "eventsOrganised length is incorrect");
    assert.equal(eventsOrganised[0].toNumber(), eventId, "Event ID not stored in eventsOrganised mapping");


  });

  it("Test Buying of Tickets", async () => {

  });

});