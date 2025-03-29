module only4fans::error_config {
    const ENOT_ADMIN: u64 = 0;
    const ENOT_ALREADY_PERMISSION: u64 = 1;
    const EIDOL_NOT_EXISTS: u64 = 2;
    const ECOLLECTION_NOT_EXISTS: u64 = 3;
    const EUSER_ALREADY_PAYED: u64 = 4;

    public fun get_enot_admin(): u64 {
        ENOT_ADMIN
    }

    public fun get_enot_already_permission(): u64 {
        ENOT_ALREADY_PERMISSION
    }

    public fun get_eidol_not_exists(): u64 {
        EIDOL_NOT_EXISTS
    }

    public fun get_ecollection_not_exists(): u64 {
        ECOLLECTION_NOT_EXISTS
    }

    public fun get_euser_already_payed(): u64 {
        EUSER_ALREADY_PAYED
    }
}
