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
    ticketMgmtInstance = await TicketMgmt.new({ from: accounts[1] });

    // Deploy EventMgmt contract with TicketMgmt address
    eventMgmtInstance = await EventMgmt.new(ticketMgmtInstance.address, {
        from: accounts[1],
    });

    // Deploy TicketMkt contract with EventMgmt address
    ticketMktInstance = await TicketMkt.new(eventMgmtInstance.address, {
        from: accounts[1],
    });
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
      { from: accounts[1] }
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
    const categoryName = "Test Cat";

    const categoryDescription = "This is a test category.";

    const ticketPrice = web3.utils.toWei("1", "ether");

    const numberOfTickets = 100;

    const createCategoryResult = await ticketMktInstance.createTicketCategory(
      1,
      categoryName,
      categoryDescription,
      ticketPrice,
      numberOfTickets,
      { from: accounts[1] }
    );

    console.log("test " + createCategoryResult);

    const createCategory = createCategoryResult.logs.find(
      (log) => log.event === "createCategory"
    );

    assert.exists(createCategory, "createTicketCategory result is undefined");
  });

  it("Test Updating of Event Description", async () => {
    const newDescription = "New event description";

    await ticketMktInstance.updateEventDescription(1, newDescription, {
      from: accounts[1],
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
      from: accounts[1],
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
});
