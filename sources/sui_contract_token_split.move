module sui_contract_token_split::sui_contract_token_split {

use std::address;
use std::option::none;
use std::u64;
use sui::balance;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::object::{new, UID};
use sui::transfer::{public_transfer};
use sui::tx_context::{TxContext, sender};
use sui::sui::SUI;

const E_INSUFFICIENT_BALANCE: u64 = 0;
const E_INVALID_RATIO: u64 = 1;

public struct SUI_CONTRACT_TOKEN_SPLIT has drop {}

public struct MinterCap has key, store {
    id: UID,
    treasury_cap: TreasuryCap<SUI_CONTRACT_TOKEN_SPLIT>,
}

public struct LiquidityPool has key, store {
    id: UID,
    sui_reserve: Coin<SUI>,
    happy_reserve: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
}

fun init(witness: SUI_CONTRACT_TOKEN_SPLIT, ctx: &mut TxContext) {
    let initial_supply = 100000000000000;

    let (treasury_cap, metadata) = coin::create_currency(
        witness,
        9,
        b"HAPPY",
        b"HAPPY token",
        b"just a test token",
        none(),
        ctx,
    );

    // Freeze metadata and mint initial tokens to sender
    let mut minter_cap = MinterCap {
        id: new(ctx),
        treasury_cap,
    };

    let new_coin = coin::mint(&mut minter_cap.treasury_cap, initial_supply, ctx);
    public_transfer(new_coin, sender(ctx));
    public_transfer(minter_cap, sender(ctx));
    public_transfer(metadata, sender(ctx));
}

public entry fun mint(
    minter_cap: &mut MinterCap,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
) {
    let new_coin = coin::mint(&mut minter_cap.treasury_cap, amount, ctx);
    public_transfer(new_coin, recipient)
}

public entry fun provide_liquidity(
    mut sui: Coin<SUI>,
    mut happy: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    ctx: &mut TxContext
) {
    let sui_amt = coin::value(&sui);
    let happy_amt = coin::value(&happy);

    // Require the user to send at least 1 SUI and 100 HAPPY
    if (sui_amt < 1000000000 || happy_amt < 10000) {
        abort E_INVALID_RATIO;
    };

    // Split out 1 SUI and 100 HAPPY
    let one_sui = coin::split(&mut sui, 1000000000, ctx);
    let hundred_happy = coin::split(&mut happy, 100000000000, ctx);

    // Create the pool
    let pool = LiquidityPool {
        id: new(ctx),
        sui_reserve: one_sui,
        happy_reserve: hundred_happy,
    };

    // Return the remaining SUI and HAPPY to user
    public_transfer(sui, sender(ctx));
    public_transfer(happy, sender(ctx));
    public_transfer(pool, sender(ctx));
}



public entry fun swap_sui_to_happy(
    pool: &mut LiquidityPool,
    mut sui_in: Coin<SUI>,
    ctx: &mut TxContext
) {
    let sui_amt = coin::value<SUI>(&sui_in);
    let happy_amt = sui_amt * 100;

    let happy_out = coin::split(&mut pool.happy_reserve, happy_amt, ctx);
    coin::join(&mut pool.sui_reserve, sui_in);
    public_transfer(happy_out, sender(ctx));
}

public entry fun swap_happy_to_sui(
    pool: &mut LiquidityPool,
    mut happy_in: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    ctx: &mut TxContext
) {
    let happy_amt = coin::value(&happy_in);
    let sui_amt = happy_amt / 100;

    if (sui_amt == 0) {
        abort E_INSUFFICIENT_BALANCE;
    };

    let sui_out = coin::split(&mut pool.sui_reserve, sui_amt, ctx);
    coin::join(&mut pool.happy_reserve, happy_in);
    public_transfer(sui_out, sender(ctx));
}

public entry fun burn(
    minter_cap: &mut MinterCap,
    coin: Coin<SUI_CONTRACT_TOKEN_SPLIT>
) {
    coin::burn(&mut minter_cap.treasury_cap, coin);
}
}
