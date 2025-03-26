module only4fans::only4fans {
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use std::string::String;
    use aptos_framework::event::{Self, EventHandle};

    use only4fans::error_config;

    struct Only4FansAdmin has key {
        admin: address,
        fee: u256,
        total_fees: u256,
        machine_address: address
    }

    struct IdolsManagement has key {
        all_idols: u64,
        source: address,
        resource_cap: SignerCapability,
        idols_registering_events: EventHandle<IdolRegisteringEvent>,
        collection_update_events: EventHandle<CollectionUpdateEvent>
    }

    struct IdolRegisteringEvent has drop, store {
        name: String,
        bio: String,
        height: u8,
        weight: u8,
        birthday_year: u16,
        avatar: String
    }

    struct CollectionUpdateEvent has drop, store {
        collection_name: String,
        amounts: u64,
        price: u256
    }

    struct IdolInfo has key {
        owner_addr: address,
        name: String,
        username: String,
        bio: String,
        avatar: String,
        height: u8,
        weight: u8,
        birthday_year: u16,
        total_collections: u64,
        total_media: u64,
        total_fans: u64,
        total_likes: u64
    }

    fun init_module(caller: &signer) {
        let admin_addr = signer::address_of(caller);
        let (_, resource_cap) = account::create_resource_account(caller, b"idolsmanagement");
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        let machine_address = account::get_signer_capability_address(&resource_cap);

        move_to<Only4FansAdmin>(caller, Only4FansAdmin {
            admin: admin_addr,
            fee: 100_000_000,
            total_fees: 0,
            machine_address,
        });

        move_to<IdolsManagement>(&resource_signer_from_cap, IdolsManagement {
            all_idols: 0,
            source: admin_addr,
            resource_cap: resource_cap,
            idols_registering_events: account::new_event_handle<IdolRegisteringEvent>(caller),
            collection_update_events: account::new_event_handle<CollectionUpdateEvent>(caller),
        });
    }

    // -->>> Region:: START  --->>>  Idols
    public entry fun idol_register(
        caller: &signer,
        machine_address: address,
        name: String,
        username: String,
        height: u8,
        weight: u8,
        birthday_year: u16,
        bio: String,
        avatar: String
    ) acquires IdolsManagement {
        assert!(exists<IdolsManagement>(machine_address), error_config::get_enot_already_permission());

        let idols_management = borrow_global_mut<IdolsManagement>(machine_address);

        let idol_addr = signer::address_of(caller);
        move_to(caller, IdolInfo {
            owner_addr: idol_addr,
            name,
            username,
            bio,
            avatar,
            height,
            weight,
            birthday_year,
            total_collections: 0,
            total_media: 0,
            total_fans: 0,
            total_likes: 0
        });

        // let resource_signer_from_cap = account::create_signer_with_capability(&idols_management.resource_cap);
        idols_management.all_idols = idols_management.all_idols + 1;

        event::emit_event<IdolRegisteringEvent>(
            &mut idols_management.idols_registering_events,
            IdolRegisteringEvent {
                name,
                bio,
                height,
                weight,
                birthday_year,
                avatar
            }
        )
    }
    // <<<-- Region:: END    <<<---  Idols

    // -->>> Region:: START  --->>>  Admin Configuration
    public entry fun change_fee(caller: &signer, owner_addr: address, new_fee: u256) acquires Only4FansAdmin {
        let addr = signer::address_of(caller);
        let admin_info = borrow_global_mut<Only4FansAdmin>(owner_addr);

        assert!(admin_info.admin == addr, error_config::get_enot_admin());

        admin_info.fee = new_fee;
    }

    #[view]
    public fun get_fee(admin: address): u256 acquires Only4FansAdmin {
        let info = borrow_global<Only4FansAdmin>(admin);
        info.fee
    }
    // <<<-- Region:: END    <<<---  Admin Configuration

    #[test_only]
    public fun init_module_for_test(caller: &signer) {
        init_module(caller);
    }
}
