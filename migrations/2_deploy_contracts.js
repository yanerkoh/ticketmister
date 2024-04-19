const TicketMister = artifacts.require("TicketMister");

module.exports = (deployer, network, accounts) => {
    deployer.deploy(TicketMister, { gas: 10000000 });
};