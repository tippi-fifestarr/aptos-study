# About 
This document should have list of questions i have during my learning journey 

## Double check my understanding 
```move 
entry public fun start_auction(
    owner: &signer,
    token_name: String,
    token_description: String,
    token_uri: String,
    buy_token: Object<Metadata>,
    max_price: u64,
    min_price: u64,
    duration: u64
) {
    only_owner(owner);

    assert!(max_price >= min_price, error::invalid_argument(EINVALID_PRICES));
    assert!(duration > 0, error::invalid_argument(EINVALID_DURATION));

    let collection_name = string::utf8(DUTCH_AUCTION_COLLECTION_NAME);

    let sell_token_ctor = token::create_named_token(
        owner,
        collection_name,
        token_description,
        token_name,
        option::none(),
        token_uri,
    );
    let transfer_ref = object::generate_transfer_ref(&sell_token_ctor);
    let sell_token = object::object_from_constructor_ref<Token>(&sell_token_ctor);

    let auction = Auction {
        sell_token,
        buy_token,
        max_price,
        min_price,
        duration,
        started_at: timestamp::now_seconds()
    };

    let auction_seed = get_auction_seed(token_name);
    let auction_ctor = object::create_named_object(owner, auction_seed);
    let auction_signer = object::generate_signer(&auction_ctor); // @Q : this will create new address for the object ? or will retrieve it from create_name_object ? which is 

    move_to(&auction_signer, auction);
    move_to(&auction_signer, TokenConfig { transfer_ref });

    let auction = object::object_from_constructor_ref<Auction>(&auction_ctor);

    event::emit(AuctionCreated { auction });
}

fun get_collection_seed(): vector<u8> {
    DUTCH_AUCTION_COLLECTION_NAME
}

fun get_token_seed(token_name: String): vector<u8> {
    let collection_name = string::utf8(DUTCH_AUCTION_COLLECTION_NAME);

    /// concatinates collection_name::token_name
    token::create_token_seed(&collection_name, &token_name)
}

fun get_auction_seed(token_name: String): vector<u8> {
    let token_seed = get_token_seed(token_name);

    let seed = DUTCH_AUCTION_SEED_PREFIX;
    vector::append(&mut seed, b"::");
    vector::append(&mut seed, token_seed);

    seed
}

inline fun only_owner(owner: &signer) {
    assert!(
        signer::address_of(owner) == @dutch_auction_address,
        error::permission_denied(ENOT_OWNER)
    );
}

```
## Security related 
## Wondering why/how
- transfer from contract address 
here's what i get from ai 

``text
The issue here is that you're trying to transfer tokens from the contract address back to a player, but you don't have a signer for the contract address.

For tokens that are owned by a contract address, you need to use a resource account pattern to properly manage transfers. Here's how to accomplish this:

1. First, set up a resource account during module initialization:

```rust
struct ModuleData has key {
    signer_cap: account::SignerCapability,
    // other module data
}

fun init_module(deployer: &signer) {
    let seed = b"aptos_fighters";
    let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
    
    // Store the signer capability
    move_to(deployer, ModuleData {
        signer_cap: resource_signer_cap,
        // other fields
    });
}
```

2. Then create a function to transfer tokens from the contract to a player:

```rust
public fun transfer_reward_to_player(
    player_add: address, 
    game_token: address, 
    amount_to_withdraw: u64
) acquires ModuleData {
    // Get module address - this should be the same as @aptos_fighters_address
    let module_addr = @aptos_fighters_address;
    
    // Get the resource signer using the stored capability
    let module_data = borrow_global<ModuleData>(module_addr);
    let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
    
    // Get the token metadata
    let metadata = object::address_to_object<Metadata>(game_token);
    
    // Transfer tokens from the contract to the player
    primary_fungible_store::transfer(&resource_signer, metadata, player_add, amount_to_withdraw);
}
```

3. Use this function in your reward distribution logic:

```rust
public entry fun claim_reward(
    player: &signer,
    game_address: address
) acquires Game, ModuleData {
    let player_add = signer::address_of(player);
    let game = borrow_global_mut<Game>(game_address);
    
    // Game logic to verify the player is eligible for reward
    assert!(player_add == game.player1 || player_add == game.player2, ENOT_A_PLAYER);
    
    let amount_reward = game.game_rules.reward_amount;
    
    // Transfer the reward from contract to player
    transfer_reward_to_player(player_add, game.game_token, amount_reward);
    
    // Update game state
    if (player_add == game.player1) {
        game.player1_reward_claimed = true;
    } else {
        game.player2_reward_claimed = true;
    };
}
```

This approach uses a resource account pattern which is a common approach in Aptos for modules that need to manage assets. The resource account acts as a separate account controlled by your module, and the SignerCapability allows your module to authorize transactions on behalf of that account.

```