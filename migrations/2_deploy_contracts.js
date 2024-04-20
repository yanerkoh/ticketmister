const TicketMgmt = artifacts.require("TicketMgmt");
const EventMgmt = artifacts.require("EventMgmt");
const TicketMkt = artifacts.require("TicketMkt");

module.exports = function (deployer) {
  deployer.deploy(TicketMgmt)
    .then(function() {
      return deployer.deploy(EventMgmt, TicketMgmt.address);
    })
    .then(function() {
      return deployer.deploy(TicketMkt, EventMgmt.address);
    })
    .then(() => {
      console.log("Deployment completed successfully!");
    })
    .catch((err) => {
      console.error("Deployment error:", err);
    });
};
