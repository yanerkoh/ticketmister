const TicketMgmt = artifacts.require("TicketMgmt");
const EventMgmt = artifacts.require("EventMgmt");
const TicketMkt = artifacts.require("TicketMkt");

module.exports = function (deployer) {
  let ticketMgmtInstance;

  deployer.deploy(TicketMgmt)
    .then((ticketMgmt) => {
      ticketMgmtInstance = ticketMgmt;

      return deployer.deploy(EventMgmt, ticketMgmtInstance.address);
    })
    .then((eventMgmt) => {
      return deployer.deploy(TicketMkt, eventMgmt.address);
    })
    .then(() => {
      console.log("Deployment completed successfully!");
    })
    .catch((err) => {
      console.error("Deployment error:", err);
    });
};