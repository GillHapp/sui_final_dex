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
const E_DIVISION_BY_ZERO: u64 = 2;

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

    // Require the user to send at least 1 SUI and 200 HAPPY
    if (sui_amt < 1_000_000_000 || happy_amt < 200_000_000_000) {
        abort E_INVALID_RATIO;
    };

    // Spli  t out exactly 1 SUI and 200 HAPPY
    let one_sui = coin::split(&mut sui, 1_000_000_000, ctx);
    let two_hundred_happy = coin::split(&mut happy, 200_000_000_000, ctx);

    // Create the pool
    let pool = LiquidityPool {
        id: new(ctx),
        sui_reserve: one_sui,
        happy_reserve: two_hundred_happy,
    };

    // Return the remaining SUI and HAPPY back to the user
    public_transfer(sui, sender(ctx));
    public_transfer(happy, sender(ctx));
    public_transfer(pool, sender(ctx));
}



public entry fun calculate_price(
    pool: &LiquidityPool,
    sui_amount: u64
): u64 {
    let happy_reserve = coin::value(&pool.happy_reserve);
    let sui_reserve = coin::value(&pool.sui_reserve);

    // Check pool not empty
    if (sui_reserve == 0) {
        abort E_DIVISION_BY_ZERO;
    };

    let price_per_sui = happy_reserve / sui_reserve;
    sui_amount * price_per_sui
}


public entry fun swap_sui_to_happy(
    pool: &mut LiquidityPool,
    mut sui_payment: Coin<SUI>,
    value: u64,
    ctx: &mut TxContext
) {
    // Split the amount user wants to swap
    let new_sui = coin::split(&mut sui_payment, value, ctx);

    // Calculate how much HAPPY to give
    let happy_amt = calculate_price(pool, value);

    // Check if the pool has enough HAPPY tokens
    if (happy_amt > coin::value(&pool.happy_reserve)) {
        abort E_INSUFFICIENT_BALANCE;
    };

    // Split the required amount of HAPPY tokens from the pool
    let new_happy = coin::split(&mut pool.happy_reserve, happy_amt, ctx);

    // ✅ Only `new_sui` should be joined into the pool
    coin::join(&mut pool.sui_reserve, new_sui);

    // ✅ Transfer HAPPY tokens to the sender
    public_transfer(new_happy, sender(ctx));

    // ✅ Return leftover SUI (if any) back to the sender
    public_transfer(sui_payment, sender(ctx));
}

public entry fun burn(
    minter_cap: &mut MinterCap,
    coin: Coin<SUI_CONTRACT_TOKEN_SPLIT>
) {
    coin::burn(&mut minter_cap.treasury_cap, coin);
}

public fun calculate_sui_price(
    pool: &LiquidityPool,
    happy_amount: u64
): u64 {
    let happy_reserve = coin::value(&pool.happy_reserve);
    let sui_reserve = coin::value(&pool.sui_reserve);

    if (happy_reserve == 0) {
        abort E_DIVISION_BY_ZERO;
    };

    let price_per_happy = sui_reserve * 1_000_000_000 / happy_reserve; // * scaled up
    (happy_amount * price_per_happy) / 1_000_000_000 // then scale back
}


public entry fun swap_happy_to_sui(
    pool: &mut LiquidityPool,
    mut happy_payment: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    value: u64,
    ctx: &mut TxContext
) {
    // Step 1: Split the user's payment
    let new_happy = coin::split(&mut happy_payment, value, ctx);

    // Step 2: Calculate how much SUI the user should receive
    let sui_amt = calculate_sui_price(pool, value);

    // Step 3: Check if the pool has enough SUI to pay
    if (sui_amt > coin::value(&pool.sui_reserve)) {
        abort E_INSUFFICIENT_BALANCE;
    };

    // Step 4: Split the required SUI from the pool
    let new_sui = coin::split(&mut pool.sui_reserve, sui_amt, ctx);

    // Step 5: Join the user's HAPPY into the pool
    coin::join(&mut pool.happy_reserve, new_happy);

    // Step 6: Transfer the SUI to the user
    public_transfer(new_sui, sender(ctx));

    // Step 7: Return leftover HAPPY (if any)
    public_transfer(happy_payment, sender(ctx));
}



}



// now we want that when user come to the marketplace, 
// this function is realated to user can swap there native sui token to happy token
// I want this function is like user come and depoite there n ative sui token  into the pool and get back the equivalent happy token according to the ratio
// public entry fun swap(
//     pool: &mut LiquidityPool,
//     sui_amt: u64,
//     ctx: &mut TxContext
// ) {
//     let happy_amt = sui_amt * coin::value(&pool.happy_reserve) / coin::value(&pool.sui_reserve);

//     // Check if the pool has enough HAPPY to swap
//     if (happy_amt > coin::value(&pool.happy_reserve)) {
//         abort E_INSUFFICIENT_BALANCE;
//     };

//     // Split the SUI and HAPPY coins
//     let new_sui = coin::split(&mut pool.sui_reserve, sui_amt, ctx);
//     let new_happy = coin::split(&mut pool.happy_reserve, happy_amt, ctx);

//     // Transfer the new coins to the user
//     public_transfer(new_sui, sender(ctx));
//     public_transfer(new_happy, sender(ctx));
// }


// public entry fun swap(
//     pool: &mut LiquidityPool,
//     mut sui_payment: Coin<SUI>,
//     value: u64,
//     ctx: &mut TxContext
// ) {
//    // split the sui payment in to value
//     let new_sui = coin::split(&mut sui_payment, value, ctx);

//     // Calculate the amount of HAPPY to swap
//     let happy_amt = value * coin::value(&pool.happy_reserve) / coin::value(&pool.sui_reserve);

//     // Check if the pool has enough HAPPY to swap
//     if (happy_amt > coin::value(&pool.happy_reserve)) {
//         abort E_INSUFFICIENT_BALANCE;
//     };

//     // Split the HAPPY coins
//     let new_happy = coin::split(&mut pool.happy_reserve, happy_amt, ctx);

//     // transfer new coins to the user 
//     public_transfer(new_sui, sender(ctx));
//     // join the payment to the pool's reserve
//     coin::join(&mut pool.sui_reserve, sui_payment);
//     // transfer happy tokens to the user
//     public_transfer(new_happy, sender(ctx));
// }


