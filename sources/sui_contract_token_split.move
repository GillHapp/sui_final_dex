module sui_contract_token_split::sui_contract_token_split;

use std::address;
use std::option::none;
use std::u64;
use sui::balance;
use sui::coin::{Self, TreasuryCap, Coin};
use sui::dynamic_object_field::id;
use sui::object::{new, UID};
use sui::token::{amount, recipient};
use sui::transfer::{public_freeze_object, public_transfer, transfer};
use sui::tx_context::{TxContext, sender};
use sui_system::validator::metadata;
use sui::sui::SUI;

const E_INSUFFICIENT_BALANCE: u64 = 0;

public struct SUI_CONTRACT_TOKEN_SPLIT has drop {}

public struct MinterCap has key {
    id: UID,
    treasury_cap: TreasuryCap<SUI_CONTRACT_TOKEN_SPLIT>,
}

fun init(witness: SUI_CONTRACT_TOKEN_SPLIT, ctx: &mut TxContext) {
    let initial_supply = 1000;

    let (treasury_cap, metadata) = coin::create_currency(
        witness,
        2,
        b"HAPPY",
        b"HAPPY token",
        b"just a test token",
        none(),
        ctx,
    );
    public_freeze_object(metadata);
    let mut minter_cap = MinterCap {
        id: new(ctx),
        treasury_cap,
    };
    let new_coin = coin::mint(&mut minter_cap.treasury_cap, initial_supply, ctx);
    public_transfer(new_coin, sender(ctx));
    transfer(minter_cap, sender(ctx));
}

public fun mint(minter_cap: &mut MinterCap, amount: u64, recipient: address, ctx: &mut TxContext) {
    let new_coin = coin::mint(&mut minter_cap.treasury_cap, amount, ctx);
    public_transfer(new_coin, recipient)
}

public entry fun transfer_token(
    mut my_coin: coin::Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    recipient: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    let total = coin::value(&my_coin);
    if (total < amount) {
        abort E_INSUFFICIENT_BALANCE;
    };
    if (total == amount) {
        public_transfer(my_coin, recipient);
        return;
    };

    let to_send = coin::split(&mut my_coin, amount, ctx);
    public_transfer(to_send, recipient);
    public_transfer(my_coin, tx_context::sender(ctx));
}

public entry fun mint_custom(
    minter_cap: &mut MinterCap,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let new_coin = coin::mint(&mut minter_cap.treasury_cap, amount, ctx);
    public_transfer(new_coin, recipient)
}

public entry fun burn(minter_cap: &mut MinterCap, coin: coin::Coin<SUI_CONTRACT_TOKEN_SPLIT>) {
    coin::burn(&mut minter_cap.treasury_cap, coin);
}

public entry fun transfer_sui_coin(
    mut sui_coin: coin::Coin<SUI>,
    recipient: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    let total = coin::value<SUI>(&sui_coin);

    if (total < amount) {
        abort E_INSUFFICIENT_BALANCE;
    };

    if (total == amount) {
        public_transfer(sui_coin, recipient);
        return;
    };

    let to_send = coin::split<SUI>(&mut sui_coin, amount, ctx);
    public_transfer(to_send, recipient);
    public_transfer(sui_coin, sender(ctx));
}


