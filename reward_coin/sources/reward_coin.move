module reward_coin::reward_coin {
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::event;

    public struct REWARD_COIN has drop {}

    public struct MintEvent has copy, drop {
        amount: u64,
        recipient: address
    }

    public struct BurnEvent has copy, drop {
        amount: u64,
    }

    fun init(
        witness: REWARD_COIN,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"RWDC",
            b"reward coin",
            b"reward coin for staking",
            option::none(),
            ctx,
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun mint(
        treasury_cap: &mut TreasuryCap<REWARD_COIN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let minted_coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
        event::emit(MintEvent {amount, recipient});

    }

    public fun burn(
        treasury_cap: &mut TreasuryCap<REWARD_COIN>,
        coin: Coin<REWARD_COIN>
    ) {
        let burned_coin = coin::burn(treasury_cap, coin);
        event::emit(BurnEvent {amount: burned_coin});
    }
}
