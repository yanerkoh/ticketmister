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

  it("should deploy contracts correctly", async () => {
    assert.notEqual(ticketMgmtInstance.address, "0x0", "TicketMgmt contract not deployed");
    assert.notEqual(eventMgmtInstance.address, "0x0", "EventMgmt contract not deployed");
    assert.notEqual(ticketMktInstance.address, "0x0", "TicketMkt contract not deployed");
  });


});