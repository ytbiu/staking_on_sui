// module machine_staking::interface {
//     use sui::coin::{Coin, CoinMetadata, TreasuryCap};
//     use sui::clock::{ Clock };
//     use std::string::{ String };

//     use reward_coin::reward_coin::{ REWARD_COIN };
//     use staking_permission_nft::staking_permission_nft::{ STAKING_PERMISSION_NFT };
//     use machine_staking::machine_staking::{
//         Self,
//         Config,
//         UserStakeInfo,
//         RewardInfo,
//         RewardPool,
//         RootCap
//     };

//     use machine_staking::machine_rent::{Self, RentInfo};

//     public entry fun set_config(
//         _: &RootCap,
//         config: &mut Config,
//         reward_start_machine_count_threshold: u64,
//     ) {
//         machine_staking::set_config(
//             config,
//             reward_start_machine_count_threshold
//         );
//     }

//     public entry fun create_reward_pool(
//         _: &RootCap,
//         reward_coin: Coin<REWARD_COIN>,
//         treasury_cap: TreasuryCap<REWARD_COIN>,
//         coin_metadata: &CoinMetadata<REWARD_COIN>,
//         stake_config: &mut Config,
//         ctx: &mut TxContext
//     ) {
//         machine_staking::create_reward_pool(
//             reward_coin,
//             treasury_cap,
//             coin_metadata,
//             stake_config,
//             ctx
//         );
//     }

//     public entry fun stake(
//         machine_id: String,
//         origin_calc_point: u64,
//         stake_config: &mut Config,
//         staked_coin: Coin<REWARD_COIN>,
//         stake_for_seconds: u64,
//         staked_nft: Coin<STAKING_PERMISSION_NFT>,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         let (reward_info, user_stake_info) = machine_staking::stake(
//             machine_id,
//             origin_calc_point,
//             stake_config,
//             staked_coin,
//             stake_for_seconds,
//             staked_nft,
//             clock,
//             ctx
//         );

//         transfer::public_transfer(user_stake_info, ctx.sender());
//         transfer::public_transfer(reward_info, ctx.sender());
//     }

//     public entry fun claim(
//         stake_config: &mut Config,
//         reward_info: RewardInfo,
//         reward_pool: &mut RewardPool,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         let (
//             released_reward, // Coin<REWARD_COIN>
//             reward_info_result, // RewardInfo
//             withdrawed_all // bool
//         ) = machine_staking::claim(
//             stake_config,
//             reward_info,
//             reward_pool,
//             clock,
//             ctx
//         );

//         if (withdrawed_all) {
//             machine_staking::delete_reward_info(reward_info_result);
//         } else {
//             transfer::public_transfer(reward_info_result, ctx.sender());
//         };
//         transfer::public_transfer(released_reward, ctx.sender());

//     }

//     public entry fun unstake(
//         stake_config: &mut Config,
//         user_stake_info: UserStakeInfo,
//         reward_info: RewardInfo,
//         reward_pool: &mut RewardPool,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         machine_staking::unstake(
//             stake_config,
//             user_stake_info,
//             reward_info,
//             reward_pool,
//             clock,
//             ctx
//         );
//     }

//     public entry fun rent_machine(
//         reward_pool: &mut RewardPool,
//         config: &mut Config,
//         machine_id: String,
//         rent_duration_seconds: u64,
//         renter: address,
//         rent_fee: Coin<REWARD_COIN>,
//         fee_token_metadata: &CoinMetadata<REWARD_COIN>,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         machine_rent::rent_machine(
//             reward_pool,
//             config,
//             machine_id,
//             rent_duration_seconds,
//             renter,
//             rent_fee,
//             fee_token_metadata,
//             clock,
//             ctx
//         );
//     }

//     public entry fun end_rent_machine(
//         config: &mut Config,
//         machine_id: String,
//         rent_info: RentInfo,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         machine_rent::end_rent_machine(
//             config,
//             machine_id,
//             rent_info,
//             clock,
//             ctx
//         );
//     }
// }
