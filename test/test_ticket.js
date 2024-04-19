const TicketMister = artifacts.require('TicketMister');

contract('TicketMister', function(accounts) {
    let ticketMisterInstance;
    const organizer = accounts[0];
    const buyer = accounts[1];

    before(async () => {
        ticketMisterInstance = await TicketMister.deployed();
    });

    describe('Event Creation', () => {
        it('should create a new event', async () => {
            const eventName = 'Test Event';
            const eventDescription = 'This is a test event';
            const maxResalePercentage = 50;

            await ticketMisterInstance.createEvent(eventName, eventDescription, maxResalePercentage);

            const eventInfo = await ticketMisterInstance.getEventInfo(1); // Assuming this is the first event created

            assert.equal(eventInfo.eventName, eventName);
            assert.equal(eventInfo.eventDescription, eventDescription);
            assert.equal(eventInfo.maxResalePercentage, maxResalePercentage);
        });

        it('should not allow creation of event with invalid parameters', async () => {
            // Test creating event with empty name or description
            await truffleAssert.reverts(
                ticketMisterInstance.createEvent('', 'Description', 50),
                'Event name cannot be empty'
            );
            await truffleAssert.reverts(
                ticketMisterInstance.createEvent('Event', '', 50),
                'Event description cannot be empty'
            );

            // Test creating event with invalid maxResalePercentage
            await truffleAssert.reverts(
                ticketMisterInstance.createEvent('Event', 'Description', 101),
                'Max resale percentage must be between 0 and 100'
            );
        });
    });

    describe('Category Creation and Ticket Minting', () => {
        before(async () => {
            // Create an event before testing category creation
            await ticketMisterInstance.createEvent('Test Event', 'Description', 50);
        });

        it('should create a new category for an event and mint tickets', async () => {
            const eventId = 1; // Assuming this is the eventId of the event created
            const categoryName = 'VIP';
            const description = 'VIP ticket category';
            const ticketPrice = web3.utils.toWei('1', 'ether');
            const numberOfTickets = 10;

            await ticketMisterInstance.createCategory(
                eventId,
                categoryName,
                description,
                ticketPrice,
                numberOfTickets
            );

            const categoryInfo = await ticketMisterInstance.getCategoryInfo(1); // Assuming this is the first category created

            assert.equal(categoryInfo.categoryName, categoryName);
            assert.equal(categoryInfo.description, description);
            assert.equal(categoryInfo.ticketPrice, ticketPrice);
            assert.equal(categoryInfo.numberOfTickets, numberOfTickets);

            const categoryTickets = await ticketMisterInstance.getCategoryTickets(1);
            assert.equal(categoryTickets.length, numberOfTickets);
        });

        it('should not allow creation of category with invalid parameters', async () => {
            const eventId = 1; // Assuming this is the eventId of the event created

            // Test creating category with empty name or description
            await truffleAssert.reverts(
                ticketMisterInstance.createCategory(eventId, '', 'Description', web3.utils.toWei('1', 'ether'), 10),
                'Category name cannot be empty'
            );
            await truffleAssert.reverts(
                ticketMisterInstance.createCategory(eventId, 'VIP', '', web3.utils.toWei('1', 'ether'), 10),
                'Category description cannot be empty'
            );

            // Test creating category with invalid ticket price or number of tickets
            await truffleAssert.reverts(
                ticketMisterInstance.createCategory(eventId, 'VIP', 'Description', 0, 10),
                'Ticket price must be greater than 0'
            );
            await truffleAssert.reverts(
                ticketMisterInstance.createCategory(eventId, 'VIP', 'Description', web3.utils.toWei('1', 'ether'), 0),
                'Number of tickets must be greater than 0'
            );
        });
    });

    describe('Ticket Purchase and Resale', () => {
        before(async () => {
            // Create a category with tickets before testing ticket purchase
            const eventId = 1; // Assuming this is the eventId of the event created
            const categoryName = 'VIP';
            const description = 'VIP ticket category';
            const ticketPrice = web3.utils.toWei('1', 'ether');
            const numberOfTickets = 10;

            await ticketMisterInstance.createCategory(
                eventId,
                categoryName,
                description,
                ticketPrice,
                numberOfTickets
            );
        });

        it('should allow buying of tickets', async () => {
            const ticketId = 1; // Assuming this is the ID of a ticket that is for sale
            const ticketPrice = web3.utils.toWei('1', 'ether');
            const initialBalanceBuyer = await web3.eth.getBalance(buyer);

            await ticketMisterInstance.buyTicket(ticketId, { from: buyer, value: ticketPrice });

            const finalBalanceBuyer = await web3.eth.getBalance(buyer);

            assert.isTrue(finalBalanceBuyer > initialBalanceBuyer); // Buyer's balance should decrease after purchase
            assert.equal(await ticketMisterInstance.ownerOf(ticketId), buyer); // Owner of the ticket should change
        });

        it('should not allow buying a ticket with insufficient payment', async () => {
            const ticketId = 2; // Assuming this is the ID of another ticket that is for sale
            const ticketPrice = web3.utils.toWei('2', 'ether'); // Higher than actual ticket price

            await truffleAssert.reverts(
                ticketMisterInstance.buyTicket(ticketId, { from: buyer, value: ticketPrice }),
                'You must pay the exact amount that this is listed for!'
            );
        });

        it('should list a ticket for resale and allow unlisting', async () => {
            const ticketId = 1; // Assuming this is the ID of a ticket owned by the buyer
            const resalePrice = web3.utils.toWei('1.5', 'ether');

            await ticketMisterInstance.listTicketForResale(ticketId, resalePrice, { from: buyer });

            let ticketInfo = await ticketMisterInstance.getTicketInfo(ticketId);
            assert.isTrue(ticketInfo.isForSale); // Ticket should be listed for resale
            assert.equal(ticketInfo.resalePrice, resalePrice); // Resale price should match the listed price

            await ticketMisterInstance.unlistTicketFromResale(ticketId, { from: buyer });

            ticketInfo = await ticketMisterInstance.getTicketInfo(ticketId);
            assert.isFalse(ticketInfo.isForSale); // Ticket should no longer be listed for resale
            assert.equal(ticketInfo.resalePrice, 0); // Resale price should be reset to 0
        });
    });

});

