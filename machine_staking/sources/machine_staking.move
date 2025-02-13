/// Module: machine_staking
module machine_staking::machine_staking {

    use sui::balance::{ Balance };
    use sui::coin::{Self, Coin};
    use reward_coin::reward_coin::{ REWARD_COIN };
    use sui::clock::{Self, Clock};
    use staking_permission_nft::staking_permission_nft::{ STAKING_PERMISSION_NFT };
    const ONE_DAY: u64 = 60 * 60 * 24;
    // const REWARD_DURATION: u64 = ONE_DAY * 60; // 60 days
    // const MAX_NFTS_PER_MACHINE: u64 = 20;
    const LOCK_DURATION: u64 = ONE_DAY * 180; // 180 days

    public struct RootCap has key {
        id: UID,
    }

    public struct Config has key {
        id: UID,
        reward_start_time: u64,
        reward_end_time: u64,
        reward_start_machine_count_threshold: u64,
        base_reserve_amount: u64,
        total_distributed_reward_amount: u64,
        init_reward_amount: u64,
        total_machine_calc_point: u64,
        total_machine_count: u64,
        // version: u64
    }

    public struct RewardPool has key {
        id: UID,
        balance: Balance<REWARD_COIN>
    }

    public struct UserStakeInfo has key {
        id: UID,
        start_time: u64,
        end_time: u64,
        staked_coin_balance: Balance<REWARD_COIN>,
        staked_nft_balance: Balance<STAKING_PERMISSION_NFT>,
        locked_reward: LockedReward
    }

    public struct LockedReward has store {
        locked_reward_balance: Balance<REWARD_COIN>,
        locked_time: u64,
        unlocked_time: u64,
    }

    fun init(ctx: &mut TxContext) {
        let config = Config {
            id: object::new(ctx),
            reward_start_time: 0,
            reward_end_time: 0,
            reward_start_machine_count_threshold: 10,
            base_reserve_amount: 10_000_000_000_000,
            total_distributed_reward_amount: 0,
            init_reward_amount: 0,
            total_machine_calc_point: 0,
            total_machine_count: 0
        };
        transfer::share_object(config);

        transfer::transfer(
            RootCap {id: object::new(ctx)},
            ctx.sender()
        )
    }

    entry fun set_config(
        _: &RootCap,
        config: &mut Config,
        reward_start_machine_count_threshold: u64,
        base_reserve_amount: u64
    ) {
        config.reward_start_machine_count_threshold = reward_start_machine_count_threshold;
        config.base_reserve_amount = base_reserve_amount
    }

    public entry fun create_reward_pool(
        _: &RootCap,
        reward_coin: Coin<REWARD_COIN>,
        ctx: &mut TxContext
    ) {

        let pool = RewardPool {
            id: object::new(ctx),
            balance: coin::into_balance(reward_coin)
        };
        transfer::share_object(pool)
    }

    public entry fun stake(
        staked_coin: Coin<REWARD_COIN>,
        stake_for_seconds: u64,
        staked_nft: Coin<STAKING_PERMISSION_NFT>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let now = clock::timestamp_ms(clock);
        let user_stake_info = UserStakeInfo {
            id: object::new(ctx),
            start_time: now,
            end_time: now + stake_for_seconds,
            staked_coin_balance: coin::into_balance(staked_coin),
            staked_nft_balance: coin::into_balance(staked_nft),
            locked_reward: LockedReward {
                locked_reward_balance: coin::into_balance(coin::zero(ctx)),
                locked_time: now,
                unlocked_time: now + LOCK_DURATION,
            }
        };

        transfer::transfer(user_stake_info, ctx.sender())
    }

}
