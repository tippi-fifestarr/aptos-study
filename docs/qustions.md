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