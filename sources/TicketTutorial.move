module TicketTutorial::Tickets {
    use Std::Signer;
    use Std::Vector;
    use AptosFramework::TestCoin::TestCoin;
	use AptosFramework::Coin;
    #[test_only]
    use AptosFramework::ManagedCoin;

    /* STRUCTS */

    // resource able to be hold in account
    struct ConcertTicket has key, store, drop {
        seat: vector<u8>,
        ticket_code: vector<u8>,
        price: u64
    }

    struct Venue has key {
        available_tickets: vector<ConcertTicket>,
        max_seats: u64
    }

    // Resource to hold multiple ConcerTicket (in case user wants to have more than one ticket)
    struct TicketEnvelope has key {
        tickets: vector<ConcertTicket>
    }

    /* ERRORS */

    const ENO_VENUE: u64 = 0;
    const ENO_TICKETS: u64 = 1;
    const ENO_ENVELOPE: u64 = 2;
    const EINVALID_TICKET_COUNT: u64 = 3;
    const EINVALID_TICKET: u64 = 4;
    const EINVALID_PRICE: u64 = 5;
    const EMAX_SEATS: u64 = 6;
    const EINVALID_BALANCE: u64 = 7;

    /* CODE */

    // private function
    fun get_ticket_info(venue_owner_addr: address, seat:vector<u8>): (bool, vector<u8>, u64, u64) acquires Venue {
        let venue = borrow_global<Venue>(venue_owner_addr);
        let i = 0;
        let len = Vector::length<ConcertTicket>(&venue.available_tickets);
        while (i < len) {
            let ticket= Vector::borrow<ConcertTicket>(&venue.available_tickets, i);
            if (ticket.seat == seat) return (true, ticket.ticket_code, ticket.price, i);
            i = i + 1;
        };
        // return (succeded, ticket_code, price, index)
        return (false, b"", 0, 0)
    }

    public(script) fun init_venue(venue_owner: &signer, max_seats: u64) {
        // Creates vector of ConcertTicket resource
        let available_tickets = Vector::empty<ConcertTicket>();
        // Create Venue resource and move into venue_owner account
        move_to<Venue>(venue_owner, Venue {available_tickets, max_seats})
    }

    public(script) fun available_ticket_count(venue_owner_addr: address): u64 acquires Venue {
        // Gets Venue resource owned by venue_owner_addr from global storage
        let venue = borrow_global<Venue>(venue_owner_addr);
        // returns number of available_tickets
        Vector::length<ConcertTicket>(&venue.available_tickets) 	
    }

    // No need to check for recipient's signature as function can't be executed without recipient signature
    public(script) fun create_ticket(venue_owner: &signer, seat: vector<u8>, ticket_code: vector<u8>, price: u64) acquires Venue {
        let venue_owner_addr = Signer::address_of(venue_owner);
        // Verify venue has been created 
        assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
        // Get number of available tickets
        let current_seat_count = available_ticket_count(venue_owner_addr);
        // Gets mutable Venue resource owned  by venue_owner_addr from global storage
        let venue = borrow_global_mut<Venue>(venue_owner_addr);
        // Check there are available seats to sell!
        assert!(current_seat_count < venue.max_seats, EMAX_SEATS);
        // Create a ticket and add to mutable Venue's available_tickets
        Vector::push_back(&mut venue.available_tickets, ConcertTicket {seat, ticket_code, price});
    }

    // Use this wrapper function to abstain user from getting certain ConcertTicket data
    public(script) fun get_ticket_price(venue_owner_addr: address, seat:vector<u8>): (bool, u64) acquires Venue {
        // Use _ for unused values
        let (success, _, price, _) = get_ticket_info(venue_owner_addr, seat);assert!(success, EINVALID_TICKET);
        return (success, price)
    }

    // Lets buyer purchase a ticket from a specific venue and specify the seat they want
    public(script) fun purchase_ticket(buyer: &signer, venue_owner_addr: address, seat: vector<u8>) acquires Venue, TicketEnvelope {
        let buyer_addr = Signer::address_of(buyer);
        let (success, _, price, index) = get_ticket_info(venue_owner_addr, seat);
        // Check if it's a valid seat
        assert!(success, EINVALID_TICKET);
        let venue = borrow_global_mut<Venue>(venue_owner_addr);
        // Pay venue_owner price of the ticket
        Coin::transfer<TestCoin>(buyer, venue_owner_addr, price);
        // Get and remove ticket from available_tickets using index returned in get_ticket_info
        let ticket = Vector::remove<ConcertTicket>(&mut venue.available_tickets, index);
        // Check if this is the first ticket the buyer has purchased
        if (!exists<TicketEnvelope>(buyer_addr)) {
            // If it is, create TicketEnvelope resource
            move_to<TicketEnvelope>(buyer, TicketEnvelope {tickets: Vector::empty<ConcertTicket>()});
        };
        // Add ticket to the buyer's TicketEnvelope
        let envelope = borrow_global_mut<TicketEnvelope>(buyer_addr);
        Vector::push_back<ConcertTicket>(&mut envelope.tickets, ticket);
    }

    /* TESTS */

    // Since we don't have on chain resources, faucet is a way to simulate having TestCoin resources and give it to accounts
    #[test(venue_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    public(script) fun sender_can_buy_ticket(venue_owner: signer, buyer: signer, faucet: signer) acquires Venue, TicketEnvelope { 	
        let venue_owner_addr = Signer::address_of(&venue_owner);

        // Initialize the venue
        init_venue(&venue_owner, 3);
        assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);

        // Create some tickets
        create_ticket(&venue_owner, b"A24", b"AB43C7F", 15);
        create_ticket(&venue_owner, b"A25", b"AB43CFD", 15);
        create_ticket(&venue_owner, b"A26", b"AB13C7F", 20);

        // Verify we have 3 tickets now
        assert!(available_ticket_count(venue_owner_addr)==3, EINVALID_TICKET_COUNT);

        // Verify seat and price
        let (success, price) = get_ticket_price(venue_owner_addr, b"A24");
        assert!(success, EINVALID_TICKET);
        assert!(price==15, EINVALID_PRICE);

        // Initialize TestCoin module with imposter faucet account
        ManagedCoin::initialize<TestCoin>(&faucet, b"TestCoin", b"TEST", 6, false);
        ManagedCoin::register<TestCoin>(&faucet);
        ManagedCoin::register<TestCoin>(&venue_owner);
		ManagedCoin::register<TestCoin>(&buyer);
		
        let amount = 1000;
        let faucet_addr = Signer::address_of(&faucet);
        let buyer_addr = Signer::address_of(&buyer);
        ManagedCoin::mint<TestCoin>(&faucet, faucet_addr, amount);
        Coin::transfer<TestCoin>(&faucet, buyer_addr, 100);
        assert!(Coin::balance<TestCoin>(buyer_addr) == 100, EINVALID_BALANCE);

        // Buy ticket
        purchase_ticket(&buyer, venue_owner_addr, b"A24");
        // Verify TicketEnvelope resource exists for buyer
        assert!(exists<TicketEnvelope>(buyer_addr), ENO_ENVELOPE);
        // Verify buyer's TestCoin amount decreased according to bought ticket's price
        assert!(Coin::balance<TestCoin>(buyer_addr) == 85, EINVALID_BALANCE);
        // Verify venue's TestCoin amount increased according to sold ticket's price 
        assert!(Coin::balance<TestCoin>(venue_owner_addr) == 15, EINVALID_BALANCE);
        // Verify that bought ticket is no longer available
	    assert!(available_ticket_count(venue_owner_addr)==2, EINVALID_TICKET_COUNT);

		// buy a second ticket & ensure balance has changed by 20
		purchase_ticket(&buyer, venue_owner_addr, b"A26");
		assert!(Coin::balance<TestCoin>(buyer_addr) == 65, EINVALID_BALANCE);
		assert!(Coin::balance<TestCoin>(venue_owner_addr) == 35, EINVALID_BALANCE);
    }	
}