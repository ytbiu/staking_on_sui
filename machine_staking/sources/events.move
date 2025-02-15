module machine_staking::events {
    use std::string::String;
    use sui::event::{ Self };

    public struct UserStakeEvent has copy, drop {
        user: address,
        machine_id: String,
    }

    public struct RewardStartEvent has copy, drop {}

    public struct ClaimedEvent has copy, drop {
        machine_id: String,
        total_claimed_reward: u64,
    }

    public struct UnstakeEvent has copy, drop {
        machine_id: String,
    }

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

    public fun rent_machine_event(
        machine_id: String,
        rent_duration_seconds: u64,
        rent_fee_value: u64,
        renter: address,

    ) {
        event::emit(
            RentMachineEvent {
                machine_id,
                rent_duration_seconds,
                rent_fee: rent_fee_value,
                renter,
            }
        );
    }

    public fun end_rent_machine_event(machine_id: String, renter: address) {
        event::emit(
            EndRentMachineEvent {machine_id, renter: renter,}
        );
    }

    public fun user_stake_event(user: address, machine_id: String) {
        event::emit(
            UserStakeEvent {
                user: user,
                machine_id: machine_id
            }
        );
    }

    public fun claimed_event(
        machine_id: String,
        total_claimed_reward: u64
    ) {
        event::emit(
            ClaimedEvent {
                machine_id: machine_id,
                total_claimed_reward: total_claimed_reward,
            }
        );
    }

    public fun unstake_event(machine_id: String) {
        event::emit(
            UnstakeEvent {machine_id: machine_id}
        );
    }

    public fun reward_start_event() {
        event::emit(RewardStartEvent {});
    }
}
