module only4fans::error_config {
    const ENOT_ADMIN: u64 = 0;
    const ENOT_ALREADY_PERMISSION: u64 = 1;

    public fun get_enot_admin(): u64 {
        ENOT_ADMIN
    }

    public fun get_enot_already_permission(): u64 {
        ENOT_ALREADY_PERMISSION
    }
}
