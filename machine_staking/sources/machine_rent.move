module machine_staking::machine_rent {
    use reward_coin::reward_coin::{ REWARD_COIN };

    use sui::coin::{Self, Coin, CoinMetadata,};
    use sui::clock::{Self, Clock};
    use std::string::{ String };
    use sui::event::{ Self };

    use machine_staking::machine_staking::{
        RewardPool,
        Config,
        update_calc_point_on_renting,
        update_calc_point_on_end_renting,
        burn,

    };

    const ONE_DAY: u64 = 60 * 60 * 24;
    const ONE_DAY_RENT_FEE: u64 = 10000;

    // Error
    const INVALID_RENT_FEE: u64 = 4;
    const NOT_RENTER_ERR: u64 = 5;
    const CAN_NOT_END_RENT: u64 = 6;

    // Event
    public struct RentMachineEvent has copy, drop {
        machine_id: String,
        rent_duration_seconds: u64,
        rent_fee: u64,
        renter: address,
    }

    public struct EndRentMachineEvent has copy, drop {
        machine_id: String,
        renter: address,
    }

    public struct RentInfo has key {
        id: UID,
        machine_id: String,
        start_time: u64,
        end_time: u64,
        renter: address,
    }

    public entry fun rent_machine(
        reward_pool: &mut RewardPool,
        config: &mut Config,
        machine_id: String,
        rent_duration_seconds: u64,
        renter: address,
        rent_fee: Coin<REWARD_COIN>,
        fee_token_metadata: &CoinMetadata<REWARD_COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(rent_duration_seconds > ONE_DAY);
        let rent_days = rent_duration_seconds / ONE_DAY;
        let expect_rent_fee = rent_days * ONE_DAY_RENT_FEE * (
            coin::get_decimals(fee_token_metadata) as u64
        );
        assert!(
            rent_fee.value() == expect_rent_fee,
            INVALID_RENT_FEE
        );
        let now = clock::timestamp_ms(clock);

        let rent_info = RentInfo {
            id: object::new(ctx),
            machine_id,
            start_time: now,
            end_time: now + rent_duration_seconds,
            renter,
        };

        transfer::transfer(rent_info, ctx.sender());

        update_calc_point_on_end_renting(config, machine_id);

        event::emit(
            RentMachineEvent {
                machine_id,
                rent_duration_seconds,
                rent_fee: rent_fee.value(),
                renter,
            }
        );
        burn(reward_pool, rent_fee);

    }

    public entry fun end_rent_machine(
        config: &mut Config,
        machine_id: String,
        rent_info: RentInfo,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let now = clock::timestamp_ms(clock);
        assert!(
            rent_info.end_time <= now,
            CAN_NOT_END_RENT
        );
        assert!(
            rent_info.renter == ctx.sender(),
            NOT_RENTER_ERR
        );
        let RentInfo {
            id: id,
            machine_id: _,
            start_time: _,
            end_time: _,
            renter: _,
        } = rent_info;
        object::delete(id);

        update_calc_point_on_renting(config, machine_id);
        event::emit(
            EndRentMachineEvent {
                machine_id,
                renter: ctx.sender(),
            }
        );
    }
}
