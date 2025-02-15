/// Module: machine_staking
module machine_staking::machine_staking {

    use sui::balance::{Self, Balance};
    use sui::coin::{
        Self,
        Coin,
        CoinMetadata,
        TreasuryCap
    };
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use std::string::{ String };

    use reward_coin::reward_coin::{ REWARD_COIN };
    use staking_permission_nft::staking_permission_nft::{ STAKING_PERMISSION_NFT };

    use machine_staking::events::{
        user_stake_event,
        claimed_event,
        unstake_event,
        reward_start_event,
    };

    const VERSION: u64 = 1;

    const ONE_DAY: u64 = 60 * 60 * 24;
    const REWARD_DURATION: u64 = ONE_DAY * 60; // 60 days
    const MAX_NFTS_PER_MACHINE: u64 = 20;
    const LOCK_DURATION: u64 = ONE_DAY * 180; // 180 days

    const BASE_RESERVE_AMOUT: u64 = 10000;

    // Error
    const MACHINE_STAKED_ERR: u64 = 0;
    const MACHINE_NOT_STAKED_ERR: u64 = 1;
    const DECIMALS_NOT_DEFINED_ERR: u64 = 2;
    const CAN_NOT_UNSTAKE: u64 = 3;
    const TOO_MANY_NFT: u64 = 4;

    public struct RootCap has key {
        id: UID,
    }

    public struct Config has key {
        id: UID,
        reward_start_time: u64,
        reward_end_time: u64,
        reward_start_machine_count_threshold: u64,
        total_distributed_reward_amount: u64,
        init_reward_amount: u64,
        total_machine_calc_point: u64,
        total_machine_count: u64,
        total_reserve_coin_amount: u64,
        stake_holder_machines: Table<address, Table<String, bool>>,
        machine_2_calc_point: Table<String, u64>,
        reward_coin_decimals: u8,
        version: u64
    }

    public struct RewardPool has key {
        id: UID,
        treasury_cap: TreasuryCap<REWARD_COIN>,
        balance: Balance<REWARD_COIN>
    }

    public struct UserStakeInfo has key {
        id: UID,
        machine_id: String,
        staked_coin_balance: Balance<REWARD_COIN>,
        staked_nft_balance: Balance<STAKING_PERMISSION_NFT>,
    }

    public struct RewardInfo has key, store {
        id: UID,
        machine_id: String,
        claimed_reward: u64,
        locked_reward_balance: Balance<REWARD_COIN>,
        locked_time: u64,
        unlocked_time: u64,

        last_claimed_time: u64,
        start_time: u64,
        end_time: u64
    }

    fun init(ctx: &mut TxContext) {
        let config = Config {
            id: object::new(ctx),
            reward_start_time: 0,
            reward_end_time: 0,
            reward_start_machine_count_threshold: 10,
            total_distributed_reward_amount: 0,
            init_reward_amount: 0,
            total_machine_calc_point: 0,
            total_machine_count: 0,
            total_reserve_coin_amount: 0,
            reward_coin_decimals: 0,
            stake_holder_machines: table::new<address, Table<String, bool>>(ctx),
            machine_2_calc_point: table::new<String, u64>(ctx),
            version: VERSION

        };
        transfer::share_object(config);

        transfer::transfer(
            RootCap {id: object::new(ctx)},
            ctx.sender()
        )
    }

    public entry fun set_config(
        _: &RootCap,
        config: &mut Config,
        reward_start_machine_count_threshold: u64,
    ) {
        config.reward_start_machine_count_threshold = reward_start_machine_count_threshold;
    }

    public entry fun create_reward_pool(
        _: &RootCap,
        reward_coin: Coin<REWARD_COIN>,
        treasury_cap: TreasuryCap<REWARD_COIN>,
        coin_metadata: &CoinMetadata<REWARD_COIN>,
        stake_config: &mut Config,
        ctx: &mut TxContext
    ) {

        let pool = RewardPool {
            id: object::new(ctx),
            treasury_cap: treasury_cap,
            balance: coin::into_balance(reward_coin)
        };
        stake_config.reward_coin_decimals = coin::get_decimals(coin_metadata);
        transfer::share_object(pool)
    }

    public entry fun stake(
        machine_id: String,
        origin_calc_point: u64,
        stake_config: &mut Config,
        staked_coin: Coin<REWARD_COIN>,
        stake_for_seconds: u64,
        staked_nft: Coin<STAKING_PERMISSION_NFT>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {

        assert!(
            staked_nft.value() <= MAX_NFTS_PER_MACHINE,
            TOO_MANY_NFT
        );
        let calc_point = get_full_calc_point(
            origin_calc_point,
            coin::value(&staked_coin),
            coin::value(&staked_nft),
            stake_config,
        );

        stake_config.total_machine_calc_point = stake_config.total_machine_calc_point + calc_point;
        stake_config.total_machine_count = stake_config.total_machine_count + 1;
        add_staking_machine(
            machine_id,
            stake_config,
            calc_point,
            ctx
        );

        let user_stake_info = new_user_stake_info(
            machine_id,
            staked_coin,
            staked_nft,
            ctx
        );

        transfer::transfer(user_stake_info, ctx.sender());

        let reward_info = new_reward_info(
            machine_id,
            stake_for_seconds,
            clock,
            ctx
        );
        transfer::transfer(reward_info, ctx.sender());
        user_stake_event(ctx.sender(), machine_id,);

        if (stake_config.total_machine_count >= stake_config.reward_start_machine_count_threshold) {
            let now = clock::timestamp_ms(clock);
            stake_config.reward_start_time = now;
            stake_config.reward_end_time = now + REWARD_DURATION;
            reward_start_event();
        };
    }

    public entry fun claim(
        stake_config: &mut Config,
        mut reward_info: RewardInfo,
        reward_pool: &mut RewardPool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let reward = get_reward(stake_config, &reward_info);
        let (rateA, rateB) = release_reward_right_now_rate();
        let released_reward = reward * rateA / rateB;

        let locked_reward = reward - released_reward;
        let locked_reward_balance = reward_pool.balance.split(locked_reward);

        let _ = reward_info.locked_reward_balance.join(locked_reward_balance);

        let mut released_reward_balance = reward_pool.balance.split(released_reward);
        reward_info.claimed_reward = reward_info.claimed_reward + released_reward_balance.
            value();
        stake_config.total_distributed_reward_amount = stake_config.total_distributed_reward_amount
            + released_reward_balance.value();

        reward_info.last_claimed_time = clock::timestamp_ms(clock);
        let (
            release_before_locked_reward,
            withdrawed_all
        ) = withdraw_locked_reward(&mut reward_info, clock);
        let _ = released_reward_balance.join(release_before_locked_reward);
        let machine_id = reward_info.machine_id;
        if (withdrawed_all) {
            delete_reward_info(reward_info);
        } else {
            transfer::public_transfer(reward_info, ctx.sender());
        };

        let total_released = released_reward_balance.value();
        transfer::public_transfer(
            released_reward_balance.into_coin(ctx),
            ctx.sender()
        );

        claimed_event(machine_id, total_released);
    }

    public entry fun unstake(
        stake_config: &mut Config,
        mut user_stake_info: UserStakeInfo,
        reward_info: RewardInfo,
        reward_pool: &mut RewardPool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {

        let now = clock::timestamp_ms(clock);
        assert!(
            reward_info.end_time <= now,
            CAN_NOT_UNSTAKE
        );

        let machine_id = reward_info.machine_id;
        let machine_calc_point = table::borrow(
            &stake_config.machine_2_calc_point,
            machine_id
        );

        stake_config.total_machine_calc_point = stake_config.total_machine_calc_point - *machine_calc_point;
        stake_config.total_machine_count = stake_config.total_machine_count - 1;
        stake_config.total_reserve_coin_amount = stake_config.total_reserve_coin_amount - user_stake_info
            .staked_coin_balance.value();
        claim(
            stake_config,
            reward_info,
            reward_pool,
            clock,
            ctx
        );

        table::remove(
            &mut stake_config.machine_2_calc_point,
            machine_id
        );

        if (user_stake_info.staked_coin_balance.value() > 0) {
            let reserved_coin = user_stake_info.staked_coin_balance.withdraw_all().into_coin(
                ctx
            );
            transfer::public_transfer(reserved_coin, ctx.sender())
        };

        let reserved_nft = user_stake_info.staked_nft_balance.withdraw_all().into_coin(ctx);
        transfer::public_transfer(reserved_nft, ctx.sender());

        remove_staking_machine(
            user_stake_info.machine_id,
            stake_config,
            ctx
        );

        unstake_event(user_stake_info.machine_id);
        delete_user_stake_info(user_stake_info)
    }

    fun get_reward(
        stake_config: &Config,
        reward_info: &RewardInfo,
    ): u64 {
        assert!(reward_started(stake_config));

        let end_time = reward_info.end_time.min(stake_config.reward_end_time);

        let mut start_time = reward_info.last_claimed_time.max(
            stake_config.reward_start_time
        );

        start_time = start_time.min(end_time);

        let total_duration_reward = stake_config.init_reward_amount * (end_time - start_time)
            / REWARD_DURATION;

        let machine_calc_point = table::borrow(
            &stake_config.machine_2_calc_point,
            reward_info.machine_id
        );
        total_duration_reward *(*machine_calc_point) / stake_config.total_machine_calc_point
    }

    fun get_full_calc_point(
        origin_calc_point: u64,
        staked_coin_value: u64,
        staked_nft_value: u64,
        stake_config: &Config
    ): u64 {
        assert!(
            stake_config.reward_coin_decimals > 0,
            DECIMALS_NOT_DEFINED_ERR
        );
        let staked_coin_value = staked_coin_value.max(
            BASE_RESERVE_AMOUT * (
                stake_config.reward_coin_decimals as u64
            )
        );

        origin_calc_point * (
            staked_nft_value + staked_coin_value / BASE_RESERVE_AMOUT
        )
    }

    fun new_user_stake_info(
        machine_id: String,
        staked_coin: Coin<REWARD_COIN>,
        staked_nft: Coin<STAKING_PERMISSION_NFT>,
        ctx: &mut TxContext
    ): UserStakeInfo {
        UserStakeInfo {
            id: object::new(ctx),
            machine_id: machine_id,
            staked_coin_balance: coin::into_balance(staked_coin),
            staked_nft_balance: coin::into_balance(staked_nft),
        }
    }

    fun new_reward_info(
        machine_id: String,
        stake_for_seconds: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): RewardInfo {
        let now = clock::timestamp_ms(clock);
        RewardInfo {
            id: object::new(ctx),
            machine_id: machine_id,
            claimed_reward: 0,
            locked_reward_balance: coin::into_balance(coin::zero(ctx)),
            locked_time: now,
            unlocked_time: now + LOCK_DURATION,
            last_claimed_time: now,
            start_time: now,
            end_time: now + stake_for_seconds
        }
    }

    fun add_staking_machine(
        machine_id: String,
        stake_config: &mut Config,
        calc_point: u64,
        ctx: &TxContext
    ) {
        let machines = table::borrow_mut<address, Table<String, bool>>(
            &mut stake_config.stake_holder_machines,
            ctx.sender()
        );

        assert!(
            !table::contains(machines, machine_id),
            MACHINE_STAKED_ERR
        );

        table::add(machines, machine_id, true);
        table::add(
            &mut stake_config.machine_2_calc_point,
            machine_id,
            calc_point
        );
    }

    fun remove_staking_machine(
        machine_id: String,
        stake_config: &mut Config,
        ctx: &TxContext
    ) {
        let machines = table::borrow_mut<address, Table<String, bool>>(
            &mut stake_config.stake_holder_machines,
            ctx.sender()
        );

        assert!(
            table::contains(machines, machine_id),
            MACHINE_NOT_STAKED_ERR
        );

        table::remove(machines, machine_id);
    }

    fun reward_started(stake_config: &Config): bool {
        stake_config.reward_start_time > 0
    }

    fun release_reward_right_now_rate(): (u64, u64) {
        (1, 10)
    }

    fun withdraw_locked_reward(
        reward_info: &mut RewardInfo,
        clock: &Clock
    ): (Balance<REWARD_COIN>, bool) {
        let now = clock::timestamp_ms(clock);
        if (reward_info.unlocked_time >= now) {
            let balance = reward_info.locked_reward_balance.withdraw_all();
            return(balance, true)
        };
        let release_amount = reward_info.locked_reward_balance.value() * (
            now - reward_info.locked_time
        ) / LOCK_DURATION;
        (
            reward_info.locked_reward_balance.split(release_amount),
            false
        )
    }

    fun delete_reward_info(reward_info: RewardInfo) {
        let RewardInfo {
            id: id,
            machine_id: _,
            claimed_reward: _,
            locked_reward_balance: locked_reward_balance,
            locked_time: _,
            unlocked_time: _,
            last_claimed_time: _,
            start_time: _,
            end_time: _,
        } = reward_info;
        object::delete(id);
        balance::destroy_zero(locked_reward_balance)
    }

    fun delete_user_stake_info(user_stake_info: UserStakeInfo) {
        let UserStakeInfo {
            id: id,
            machine_id: _,
            staked_coin_balance: staked_coin_balance,
            staked_nft_balance: staked_nft_balance
        } = user_stake_info;
        object::delete(id);
        balance::destroy_zero(staked_coin_balance);
        balance::destroy_zero(staked_nft_balance)
    }

    public fun update_calc_point_on_renting(
        config: &mut Config,
        machine_id: String
    ) {
        let calc_point = table::borrow_mut(
            &mut config.machine_2_calc_point,
            machine_id
        );
        *calc_point = *calc_point * 13 / 10;
    }

    public fun update_calc_point_on_end_renting(
        config: &mut Config,
        machine_id: String
    ) {
        let calc_point = table::borrow_mut(
            &mut config.machine_2_calc_point,
            machine_id
        );
        *calc_point = *calc_point * 10 / 13;
    }

    public fun burn(
        reward_pool: &mut RewardPool,
        coin: Coin<REWARD_COIN>
    ) {
        coin::burn(&mut reward_pool.treasury_cap, coin);
    }
}
