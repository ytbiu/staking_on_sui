module staking_permission_nft::staking_permission_nft {
    use sui::coin::{Self, TreasuryCap};
    use sui::event::{ Self };

    public struct STAKING_PERMISSION_NFT has drop {}

    public struct MintEvent has copy, drop {
        recipient: address,
        amount: u64
    }

    fun init(
        witness: STAKING_PERMISSION_NFT,
        ctx: &mut TxContext
    ) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            1,
            b"SPN",
            b"staking permission nft",
            b"for staking",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, ctx.sender())
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<STAKING_PERMISSION_NFT>,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {

        let minted_nft = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(minted_nft, recipient);
        event::emit(MintEvent {recipient, amount})
    }

}
