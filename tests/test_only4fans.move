#[test_only]
module only4fans::test_only4fans {
    use only4fans::only4fans;
    use std::signer;

    #[test(account = @0x1)]
    fun test_change_fee(account: &signer) {
        only4fans::init_module_for_test(account);
        only4fans::change_fee(account, 200_000_000);
        assert!(only4fans::get_fee(signer::address_of(account)) == (200_000_000 as u256), 1);
    }
}
