module only4fans::only4fans {
    use std::signer;
    use std::vector;
    use std::bcs;
    use aptos_framework::timestamp;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::object;
    use aptos_framework::account::{Self, SignerCapability};
    use std::string::String;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_token_objects::aptos_token::{Self, AptosCollection};

    // Max royalty is 10% (1000 basis points)
    const MAX_ROYALTY_NUMERATOR: u64 = 1000;
    const ROYALTY_DENOMINATOR: u64 = 10000;

    const MAX_TOKEN_NAME_LENGTH: u64 = 128;
    const MAX_URI_LENGTH: u64 = 512;
    const MAX_U64: u64 = 18446744073709551615;

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

    struct IdolInfo has key, copy {
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
        all_collections: vector<address>,
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
            all_collections: vector::empty<address>()
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

    public entry fun create_collection(
        caller: &signer,
        name: String,
        description: String,
        uri: String,
        price: u64
    ) acquires IdolInfo {
        let idol_addr = signer::address_of(caller);
        assert!(exists<IdolInfo>(idol_addr), error_config::get_eidol_not_exists());

        let seed = generate_random_seed(idol_addr, &name);
        let (resource_signer, resource_cap) = account::create_resource_account(caller, seed);

        let collection = aptos_token::create_collection_object(
            &resource_signer,
            description,
            MAX_U64,
            name,
            uri,
            true, //mutable_description
            true, //mutable_royalty
            true, //mutable_uri
            true, //mutable_token_description
            true, //mutable_token_name
            true, //mutable_token_properties
            true, //mutable_token_uri
            false, //tokens_burnable_by_creator
            false, //tokens_freezable_by_creator
            0, //royalty_numerator
            ROYALTY_DENOMINATOR //royalty_denominator
        );

        let collection_address = object::object_address(&collection);

        move_to(&resource_signer,
            CollectionInfo {
                signer_cap: resource_cap,
                collection,
                idol_addr,
                collection_address,
                price,
                post_minted: vector::empty<address>(),
                users_payed: smart_table::new<address, u64>()
            }
        );

        let idols = borrow_global_mut<IdolInfo>(idol_addr);
        vector::push_back(&mut idols.all_collections, signer::address_of(&resource_signer));

        idols.total_collections = idols.total_collections + 1;
    }

    struct CollectionInfo has key {
        signer_cap: account::SignerCapability,
        collection: object::Object<AptosCollection>,
        idol_addr: address,
        collection_address: address,
        price: u64,
        post_minted: vector<address>,
        users_payed: SmartTable<address, u64>
    }

    // <<<-- Region:: END    <<<---  Idols

    // -->>> Region:: START  --->>>  Users
    public entry fun buy_collection(
        caller: &signer,
        collection_address: address
    ) acquires CollectionInfo {
        assert!(exists<CollectionInfo>(collection_address), error_config::get_ecollection_not_exists());
        let collection_info = borrow_global_mut<CollectionInfo>(collection_address);
        coin::transfer<AptosCoin>(caller, collection_info.idol_addr, collection_info.price);

        let user_addr = signer::address_of(caller);

        let payed = smart_table::contains<address, u64>(&mut collection_info.users_payed, user_addr);
        if (payed) {
            let valid_time = smart_table::borrow<address, u64>(&mut collection_info.users_payed, user_addr);
            assert!(check_valid_time(*valid_time), error_config::get_euser_already_payed());
        } else {
            smart_table::upsert(&mut collection_info.users_payed, user_addr, timestamp::now_seconds() + 1_000_000_000);
        }
    }

    #[view]
    public fun check_collection_permission(collection_addr: address, user_addr: address): bool acquires CollectionInfo {
        let collection_info = borrow_global_mut<CollectionInfo>(collection_addr);
        if (smart_table::contains<address, u64>(&mut collection_info.users_payed, user_addr)) {
            let valid_time = smart_table::borrow<address, u64>(&mut collection_info.users_payed, user_addr);
            return check_valid_time(*valid_time)
        } else {
            return false
        }
    }
    // <<<-- Region:: END    <<<---  Users

    // -->>> Region:: START  --->>>  Helper Function
    fun check_valid_time(time: u64): bool {
        let now = timestamp::now_seconds();
        if (time < now) {
            false
        } else {
            true
        }
    }

    fun generate_random_seed(admin_address: address, name: &String): vector<u8> {
        let seed = vector::empty<u8>();

        // Add admin address bytes
        let addr_bytes = bcs::to_bytes(&admin_address);
        vector::append(&mut seed, addr_bytes);

        // Add collection name bytes
        let name_bytes = *std::string::bytes(name);
        vector::append(&mut seed, name_bytes);

        seed
    }
    // <<<-- Region:: END    <<<---  Helper Function

    // -->>> Region:: START  --->>>  Admin Configuration
    public entry fun change_fee(caller: &signer, new_fee: u256) acquires Only4FansAdmin {
        let addr = signer::address_of(caller);
        assert!(exists<Only4FansAdmin>(addr), error_config::get_enot_admin());
        let admin_info = borrow_global_mut<Only4FansAdmin>(addr);

        admin_info.fee = new_fee;
    }

    #[view]
    public fun get_fee(admin: address): u256 acquires Only4FansAdmin {
        let info = borrow_global<Only4FansAdmin>(admin);
        info.fee
    }

    #[view]
    public fun get_my_collections(idol_addr: address): vector<address> acquires IdolInfo {
        borrow_global<IdolInfo>(idol_addr).all_collections
    }

    #[view]
    public fun get_profile(idol: address): IdolInfo acquires IdolInfo {
        *borrow_global<IdolInfo>(idol)
    }

    #[view]
    public fun get_owner_object(collection_address: address): address {
        let obj = object::address_to_object<CollectionInfo>(collection_address);
        object::owner<CollectionInfo>(obj)
    }

    #[view]
    public fun get_machine_address(admin: address): address acquires Only4FansAdmin {
        borrow_global<Only4FansAdmin>(admin).machine_address
    }

    fun get_object_info_from_collection_address(collection_addr: address): object::Object<CollectionInfo> {
        object::address_to_object<CollectionInfo>(collection_addr)
    }
    // <<<-- Region:: END    <<<---  Admin Configuration

    #[test_only]
    public fun init_module_for_test(caller: &signer) {
        init_module(caller);
    }
}
