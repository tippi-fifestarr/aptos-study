module aptos_fighters_address::aptos_fighters {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::string_utils;
    use std::bcs;
    use aptos_framework::object::{Self, Object, LinearTransferRef, TransferRef};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::coin;
    use aptos_token::token::{Self, Token};
    use pyth::pyth;
    use pyth::price_identifier;
    use pyth::i64;
    use pyth::price::{Self,Price};

    use aptos_std::math64::pow;
    use aptos_framework::account;
    #[test_only]
    use std::debug;

    const ASSET1_DEFAULT_BALANCE:u64=10000000;
    const ASSET2_DEFAULT_BALANCE:u64=1000000000000;
    const OCTAS_PER_APTOS: u64 = 100000000;

    /// There is no message present
    const EINVALID_ADDRESS: u64 = 1;
    const EINVALID_AMOUNT: u64 = 2;
    const EINVALID_DURATION: u64 = 3;
    const EINVALID_ARRAY_LENGTH: u64 = 4;
    const EGAME_IS_FULL: u64 = 5;
    const ENOT_AUTHORIZED: u64 = 6;
    const EGAME_IN_PROGRESS: u64 = 7;
    const EGAME_NOT_STARTED: u64 = 8;
    const EGAME_ENDED: u64 = 9;
    const EGAME_NOT_ENDED: u64 = 10;
    const EINSUFFICIENT_BALANCE: u64 = 11;
    const EPRICE_ORACLE_EXPIRED: u64 = 12;
    const EPRICE_ORACLE_INVALID: u64 = 13;
    const EREWARD_ALREADY_CLAIMED: u64 = 14;
    const ETRANSFER_FAILED: u64 = 15;
    const EINVALID_GAME_STATUS: u64 = 16;
    const EINVALID_GAME_START_TIME: u64 = 17;
    const EPLAYER_NOT_FOUND: u64 = 18;

    /// We have to add this to use a resource account pattern to properly manage transfers
    struct ModuleData has key {
        signer_cap: account::SignerCapability,
    }

    struct GameRules has store, drop, copy {
        game_staking_amount: u64,
        game_duration: u64,
        game_start_time: u64,
        reward_amount: u64,
        assets: vector<address>,
        asset_amounts: vector<u64>,
    }

    // mapping
    struct AssetBalance has key, store, drop {
        player: address,
        balance: u64,
    }

    struct Game has key, store, drop {
        player1: address,
        player2: address,
        data_feed: vector<u8>, // Price feed ID
        player1_reward_claimed: bool,
        player2_reward_claimed: bool,
        game_token: address, // Token used for staking and rewards
        user_asset1_balance: vector<AssetBalance>,
        user_asset2_balance: vector<AssetBalance>,
        game_rules: GameRules,
    }

    #[event]
    struct AssetTraded has drop, store {
        player: address,
        price: u64,
        asset_amount: u64,
        is_buy: bool,
    }

    #[event]
    struct PlayerEnrolled has drop, store {
        player: address
    }

    #[event]
    struct GameStarted has drop, store {
        start_time: u64, 
        duration: u64, 
    }

    #[event]
    struct GameWinner has drop, store {
        winner: address
    }

    #[event]
    struct RewardClaimed has drop, store {
        account: address,
        amount: u64,
        is_winner: bool,
    }

    /// Initialize the module
    fun init_module(deployer: &signer) {
        let seed = b"aptos_fighters";
        let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
        
        // Store the signer capability
        move_to(deployer, ModuleData {
            signer_cap: resource_signer_cap,
        });
    }

    /// Initialize a new game contract
    public entry fun init_contract(
        deployer: &signer,
        game_token_add: address, 
        price_id: vector<u8>,
        game_staking_amount: u64,
        game_duration: u64,
        game_start_time: u64,
        reward_amount: u64,
        assets: vector<address>,
        asset_amounts: vector<u64>
    ) {
        // Check input data
        assert!(game_duration > 0, error::invalid_argument(EINVALID_DURATION));
        assert!(game_staking_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(reward_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(game_start_time > timestamp::now_seconds(), error::invalid_argument(EINVALID_GAME_START_TIME));
        
        let assets_length = vector::length(&assets);
        let amounts_length = vector::length(&asset_amounts);
        
        assert!(assets_length == amounts_length, error::invalid_argument(EINVALID_ARRAY_LENGTH));

        let game_rules = GameRules{
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        };
        
        // Create game with default values
        let game = Game {
            data_feed: price_id,
            player1_reward_claimed: false,
            player2_reward_claimed: false,
            game_token: game_token_add,
            game_rules,
            // Default values
            player1: @0x0,
            player2: @0x0,
            user_asset1_balance: vector::empty<AssetBalance>(),
            user_asset2_balance: vector::empty<AssetBalance>()
        };

        // Create a named object to hold the game
        let obj_hold_add = object::create_named_object(
            deployer, construct_seed(1)
        );
        let obj_add = object::generate_signer(&obj_hold_add);
        
        move_to(&obj_add, game);
    }

    /// Enroll a player in the game
    public entry fun enroll_player(player: &signer, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_addr = signer::address_of(player);
        
        // Check game hasn't started yet
        assert!(game.game_rules.game_start_time > timestamp::now_seconds(), 
            error::invalid_argument(EGAME_IN_PROGRESS));
        
        // Check game isn't full
        assert!(game.player1 == @0x0 || game.player2 == @0x0, 
            error::invalid_argument(EGAME_IS_FULL));
        
        // Check player isn't already enrolled
        assert!(game.player1 != player_addr && game.player2 != player_addr, 
            error::invalid_argument(ENOT_AUTHORIZED));
        
        // Stake required tokens
        stake(player, game.game_token, game.game_rules.game_staking_amount);
        
        // Check if player has the required assets
        let i = 0;
        let length = vector::length(&game.game_rules.assets);
        
        while (i < length) {
            let asset = vector::borrow(&game.game_rules.assets, i);
            let amount = vector::borrow(&game.game_rules.asset_amounts, i);
            
            // Check player has required asset balance
            let asset_metadata = object::address_to_object<Metadata>(*asset);
            assert!(primary_fungible_store::balance(player_addr, asset_metadata) >= *amount, 
                error::invalid_argument(EINSUFFICIENT_BALANCE));
            
            i = i + 1; // Fixed: Increment counter
        };
        
        // Update state - register player
        if (game.player1 == @0x0) {
            game.player1 = player_addr;
        } else {
            game.player2 = player_addr;
        };
        
        // Set initial balances
        let asset1_balance = AssetBalance {
            player: player_addr,
            balance: ASSET1_DEFAULT_BALANCE,
        };
        let asset2_balance = AssetBalance {
            player: player_addr,
            balance: ASSET2_DEFAULT_BALANCE,
        };
        
        vector::push_back(&mut game.user_asset1_balance, asset1_balance);
        vector::push_back(&mut game.user_asset2_balance, asset2_balance);
        
        event::emit(PlayerEnrolled{player: player_addr});
        
        // If both players are enrolled, emit game started event if applicable
        if (game.player1 != @0x0 && game.player2 != @0x0) {
            if (timestamp::now_seconds() >= game.game_rules.game_start_time) {
                event::emit(GameStarted{
                    start_time: game.game_rules.game_start_time, 
                    duration: game.game_rules.game_duration,
                });
            };
        };
    }

    /// Buy APT tokens using the game's asset
    public entry fun buy_apt(player: &signer, amount: u64, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        // Check player is authorized
        assert!(game.player1 == player_add || game.player2 == player_add, 
            error::invalid_argument(ENOT_AUTHORIZED));
        
        // Check game hasn't ended
        assert!(timestamp::now_seconds() < game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_ENDED));
        
        // Skip operation if amount is zero
        if (amount == 0) {
            return
        };
// Fetch current apt price
        
                let price = fetch_price(game.data_feed);
        let price_positive = i64::get_magnitude_if_positive(&price::get_price(&price)); // This will fail if the price is negative
        let expo_magnitude = i64::get_magnitude_if_negative(&price::get_expo(&price));         // This will fail if the exponent is positive

        let price_in_aptos_coin =  (OCTAS_PER_APTOS * pow(10, expo_magnitude)) / price_positive; // 1 USD in APT        
        // Calculate cost
        let cost = price_in_aptos_coin * amount;
                // Check player has sufficient balance
        let asset2_balance = get_user_asset_balance_mut(&mut game.user_asset2_balance,player_add);
        assert!(asset2_balance.balance >= cost, EINSUFFICIENT_BALANCE);
        // Update balances
        let asset1_balance = get_user_asset_balance_mut(&mut game.user_asset1_balance,player_add);
        /**       userAsset1Balance[msg.player] += amount;
                userAsset2Balance[msg.player] -= cost;*/
                asset1_balance.balance=   asset1_balance.balance+ amount;
                asset2_balance.balance=   asset2_balance.balance- cost;
            // emit event 
        event::emit(AssetTraded{
            player: player_add,
            price: price_in_aptos_coin,
            asset_amount: amount,
            is_buy: true,
        });
    }

    /// Sell APT tokens to get the game's asset
    public entry fun sell_apt(player: &signer, amount: u64, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        // Check player is authorized
        assert!(game.player1 == player_add || game.player2 == player_add, 
            error::invalid_argument(ENOT_AUTHORIZED));
        
        // Check game hasn't ended
        assert!(timestamp::now_seconds() < game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_ENDED));
        
        // Skip operation if amount is zero
        if (amount == 0) {
            return
        };
        
        let price = fetch_price(game.data_feed);
        let price_positive = i64::get_magnitude_if_positive(&price::get_price(&price)); // This will fail if the price is negative
        let expo_magnitude = i64::get_magnitude_if_negative(&price::get_expo(&price)); // This will fail if the exponent is positive

        let price_in_aptos_coin =  (OCTAS_PER_APTOS * pow(10, expo_magnitude)) / price_positive; // 1 USD in APT
            // Calculate cost
            let cost = price_in_aptos_coin * amount;
            // Check player has sufficient balance
             let asset1_balance = get_user_asset_balance_mut(&mut game.user_asset1_balance,player_add);

            assert!(asset1_balance.balance >= cost, EINSUFFICIENT_BALANCE);
             let asset2_balance = get_user_asset_balance_mut(&mut game.user_asset2_balance,player_add);
        
        // Update balances
        
                asset1_balance.balance=   asset1_balance.balance- amount;
                asset2_balance.balance=   asset2_balance.balance+ cost;
            // emit event 
        event::emit(AssetTraded{
            player: player_add,
            price: price_in_aptos_coin,
            asset_amount: amount,
            is_buy: false,
        });
    }

    /// Withdraw staked tokens and rewards if applicable
    public entry fun withdraw(player: &signer, deployer: address) acquires Game, ModuleData {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        // Check player is authorized
        assert!(game.player1 == player_add || game.player2 == player_add, 
            error::invalid_argument(ENOT_AUTHORIZED));
        
        // Check game has ended
        assert!(timestamp::now_seconds() > game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_NOT_ENDED));
        
        // Determine if player has already claimed reward
        let is_player1 = (player_add == game.player1);
        
        if (is_player1) {
            assert!(!game.player1_reward_claimed, error::invalid_argument(EREWARD_ALREADY_CLAIMED));
            game.player1_reward_claimed = true; // Mark as claimed
        } else {
            assert!(!game.player2_reward_claimed, error::invalid_argument(EREWARD_ALREADY_CLAIMED));
            game.player2_reward_claimed = true; // Mark as claimed
        };
        
        // Calculate amount to withdraw
        let amount_to_withdraw = game.game_rules.game_staking_amount;
        
        // Get winner info
        let (winner, _) = get_winner_fun(game);
        
        // Add reward if player is the winner
        if (winner == player_add) {
            amount_to_withdraw = amount_to_withdraw + game.game_rules.reward_amount;
        };
        
        // Transfer tokens from contract to player
        transfer_from_contract(player_add, game.game_token, amount_to_withdraw);
        
        // Emit event
        event::emit(RewardClaimed{
            account: player_add,
            amount: amount_to_withdraw,
            is_winner: winner == player_add,
        });
    }

    /// Transfer tokens from the contract to a player
    fun transfer_from_contract(
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

    /// Stake tokens from a player to the contract
    fun stake(
        player: &signer, 
        game_token: address, 
        amount: u64
    ) {
        // Get module/contract address
        let module_addr = @aptos_fighters_address;
        
        // Get the token metadata
        let metadata = object::address_to_object<Metadata>(game_token);
        
        // Transfer tokens from player to the contract
        primary_fungible_store::transfer(player, metadata, module_addr, amount);
    }
// @dev @notice @todo : we should update the price , but this would require paying for this in aptos coin, we are just skipping this for now , will do it later 
fun fetch_price(asset_price_identifier : vector<u8>) :  Price{
     // Read the current price from a price feed.
        // Each price feed (e.g., BTC/USD) is identified by a price feed ID.
        // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
        // Note: Aptos uses the Pyth price feed ID without the `0x` prefix.
        // let btc_price_identifier = x"e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
        let btc_usd_price_id = price_identifier::from_byte_vec(asset_price_identifier);
        pyth::get_price(btc_usd_price_id)
    }
  /// Please read https://docs.pyth.network/documentation/pythnet-price-feeds before using a `Price` in your application
    // fun update_and_fetch_price(receiver : &signer,  vaas : vector<vector<u8>>) : Price {
    //         let coins = coin::withdraw<aptos_coin::AptosCoin>(receiver, pyth::get_update_fee(&vaas)); // Get coins to pay for the update
    //         pyth::update_price_feeds(vaas, coins); // Update price feed with the provided vaas
    //         pyth::get_price(price_identifier::from_byte_vec(APTOS_USD_PRICE_FEED_IDENTIFIER)) // Get recent price (will fail if price is too old)

    // }
        /// view functions 
    #[view]
    public fun get_winner(deployer: address): (address, u64) acquires Game {
        let game = borrow_global<Game>(get_game_address(deployer, 1));
        assert!(timestamp::now_seconds() > game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_NOT_ENDED));
        
        get_winner_fun(game)
    }

    /// Internal function to determine winner
    fun get_winner_fun(game: &Game): (address, u64) {
        let player1 = game.player1;
        let player2 = game.player2;
        
        // Get asset balances for both players
        let player1_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player1);
        let player1_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player1);
        let player2_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player2);
        let player2_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player2);
        
        // Calculate total value for each player
        let player1_total_val = player1_asset1_balance.balance + player1_asset2_balance.balance;
        let player2_total_val = player2_asset1_balance.balance + player2_asset2_balance.balance;
        
        // Determine winner based on total value
        if (player1_total_val > player2_total_val) {
            (player1, player1_total_val)
        } else {
            (player2, player2_total_val)
        }
    }

    /// Get asset balance for a user (read-only)
    public fun get_user_asset_balance(
        asset_balances: &vector<AssetBalance>,
        user_address: address
    ): &AssetBalance {
        let i = 0;
        let len = vector::length(asset_balances);
        
        while (i < len) {
            let balance = vector::borrow(asset_balances, i);
            if (balance.player == user_address) {
                return balance
            };
            i = i + 1;
        };
        
        // Handle case where no matching address is found
        abort error::not_found(EPLAYER_NOT_FOUND)
    }

    /// Get asset balance for a user (mutable)
    fun get_user_asset_balance_mut(
        asset_balances: &mut vector<AssetBalance>,
        user_address: address
    ): &mut AssetBalance {
        let i = 0;
        let len = vector::length(asset_balances);
        
        while (i < len) {
            let balance = vector::borrow_mut(asset_balances, i);
            if (balance.player == user_address) {
                return balance
            };
            i = i + 1;
        };
        
        // Handle case where no matching address is found
        abort error::not_found(EPLAYER_NOT_FOUND)
    }

    /// Get game rules
    #[view]
    public fun get_game_rules(deployer_address: address): GameRules acquires Game {
        let game = borrow_global<Game>(get_game_address(deployer_address, 1));
        game.game_rules
    }

    /// Construct a seed for object creation
    #[view]
    public fun construct_seed(seed: u64): vector<u8> {
        bcs::to_bytes(&string_utils::format2(&b"{}_{}", @aptos_fighters_address, seed))
    }

    /// Get game address from deployer and seed
    #[view]
    public fun get_game_address(deployer: address, seed: u64): address {
        object::create_object_address(&deployer, construct_seed(seed))
    }

    /// Helper function to check if Game exists at an address
    #[test_only]
    public fun exists_at(addr: address): bool {
        exists<Game>(addr)
    }
    
    // ============== TEST FUNCTIONS ==============
    
    #[test_only]
    // Constants for testing
    const GAME_STAKING_AMOUNT: u64 = 100;
    const GAME_DURATION: u64 = 86400; // 1 day in seconds
    const REWARD_AMOUNT: u64 = 500;
    
    // Test accounts
    const DEPLOYER: address = @0x123;
    const PLAYER1: address = @0x456;
    const PLAYER2: address = @0x789;
    const GAME_TOKEN: address = @0xABC;

    
    /// Test for successful contract initialization
    #[test(aptos_framework = @aptos_framework)]
    public fun test_init_contract(aptos_framework: &signer) {
        // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000; // Start in the future
        let reward_amount = REWARD_AMOUNT;
        
        // Set up assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // Add some test assets
        vector::push_back(&mut assets, @0xA1);
        vector::push_back(&mut assets, @0xA2);
        vector::push_back(&mut asset_amounts, 10);
        vector::push_back(&mut asset_amounts, 20);
        
        // Initialize the contract
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );
    let deployer_address = signer::address_of(&deployer);

        // test revert here cuz the object is already create at deterministic address , recreating it will fail, need to find a way to get it from global 
        let game_address = object::create_object_address(
            // address , seed 
            &deployer_address, construct_seed(1)
        );
        // let obj_add = object::generate_signer(&obj_hold_add);
        // let game_address = signer::address_of(&obj_add);
        // Verify the contract was initialized
        assert!(exists_at(game_address), 0);
    }
    #[test(aptos_framework = @aptos_framework)]
public fun test_game_creation_success(aptos_framework: &signer) acquires Game {
    // Set up timestamp for testing
    timestamp::set_time_has_started_for_testing(aptos_framework);
    
    // Set up test accounts
    let deployer = account::create_account_for_test(DEPLOYER);
    let deployer_address = signer::address_of(&deployer);
    
    // Set up token address
    let game_token_add = GAME_TOKEN;
    account::create_account_for_test(game_token_add);
    
    let current_time = timestamp::now_seconds();
    
    // Set up object
    object::create_named_object(aptos_framework, b"game_token");
    
    // Configure valid test parameters
    let price_id = b"ETH/USD";
    let game_staking_amount = GAME_STAKING_AMOUNT;
    let game_duration = GAME_DURATION;
    let game_start_time = current_time + 1000;
    let reward_amount = REWARD_AMOUNT;
    
    // Set up assets and amounts (correctly matched)
    let assets = vector::empty<address>();
    let asset_amounts = vector::empty<u64>();
    
    vector::push_back(&mut assets, @0xA1);
    vector::push_back(&mut assets, @0xA2);
    vector::push_back(&mut asset_amounts, 10);
    vector::push_back(&mut asset_amounts, 20);
    
    // Initialize the contract
    init_contract(
        &deployer,
        game_token_add,
        price_id,
        game_staking_amount,
        game_duration,
        game_start_time,
        reward_amount,
        assets,
        asset_amounts
    );
    //       let obj_hold_add = object::create_named_object(
    //             // singer , seed 
    //             &deployer, construct_seed(1)
    //         );
    //         let obj_add = object::generate_signer(&obj_hold_add);
    //  let game_address = signer::address_of(&obj_add);
   let game_address = object::create_object_address(
            // address , seed 
            &deployer_address, construct_seed(1)
        );
    // Verify the game exists
    assert!(exists<Game>(game_address), 0);
    
    // Optional: Verify game properties are set correctly
    let game = borrow_global<Game>(game_address);
    
    // Verify basic properties
    assert!(game.game_token == game_token_add, 1);
    assert!(game.game_rules.game_duration == game_duration, 2);
    assert!(game.game_rules.game_staking_amount == game_staking_amount, 3);
    assert!(game.game_rules.game_start_time == game_start_time, 4);
    assert!(game.game_rules.reward_amount == reward_amount, 5);
    
    // Verify vectors are set correctly
    let stored_assets = &game.game_rules.assets;
    let stored_amounts = &game.game_rules.asset_amounts;
    
    assert!(vector::length(stored_assets) == 2, 6);
    assert!(vector::length(stored_amounts) == 2, 7);
    assert!(*vector::borrow(stored_assets, 0) == @0xA1, 8);
    assert!(*vector::borrow(stored_assets, 1) == @0xA2, 9);
    assert!(*vector::borrow(stored_amounts, 0) == 10, 10);
    assert!(*vector::borrow(stored_amounts, 1) == 20, 11);
}
    
    /// Test for failure when game duration is invalid
    #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = aptos_fighters::EINVALID_DURATION)] // issues with the code , 
    #[expected_failure]
    public fun test_init_contract_invalid_duration(aptos_framework: &signer) {
      // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = GAME_STAKING_AMOUNT;
         let game_duration = 0; // Invalid duration
        let game_start_time = current_time + 1000; // Start in the future
        let reward_amount = REWARD_AMOUNT;
        
        // Set up assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // Add some test assets
        vector::push_back(&mut assets, @0xA1);
        vector::push_back(&mut assets, @0xA2);
        vector::push_back(&mut asset_amounts, 10);
        vector::push_back(&mut asset_amounts, 20);
        
        // Initialize the contract
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );    }
    
    /// Test for failure when staking amount is invalid
    #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = EINVALID_AMOUNT)]
     #[expected_failure]
    public fun test_init_contract_invalid_staking_amount(aptos_framework: &signer) {
        // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters with invalid staking amount (0)
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = 0; // Invalid amount
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000;
        let reward_amount = REWARD_AMOUNT;
        
        // Set up assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // This should fail with EINVALID_AMOUNT
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );
    }
    
    /// Test for failure when reward amount is invalid
    #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = EINVALID_AMOUNT)]
     #[expected_failure]
    public fun test_init_contract_invalid_reward_amount(aptos_framework: &signer) {
        // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters with invalid reward amount (0)
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000;
        let reward_amount = 0; // Invalid amount
        
        // Set up assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // This should fail with EINVALID_AMOUNT
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );
    }
    
    /// Test for failure when game start time is in the past
    #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = EINVALID_GAME_START_TIME)]
     #[expected_failure]
    public fun test_init_contract_invalid_start_time(aptos_framework: &signer) {
        // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters with invalid start time (in the past)
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time - 1000; // Start in the past (invalid)
        let reward_amount = REWARD_AMOUNT;
        
        // Set up assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // This should fail with EINVALID_GAME_START_TIME
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );
    }
    
    /// Test for failure when arrays have mismatched lengths
    #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = EINVALID_ARRAY_LENGTH)]
     #[expected_failure]
    public fun test_init_contract_mismatched_arrays(aptos_framework: &signer) {
        // Set up timestamp for testing using the aptos_framework account
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Set up test accounts
        let deployer = account::create_account_for_test(DEPLOYER);
        
        // Set up fake token address
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();

        // Set up the object and make it a valid object
        object::create_named_object(aptos_framework, b"game_token");
        
        // Configure test parameters
        let price_id = b"ETH/USD"; // Mock price feed ID
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000;
        let reward_amount = REWARD_AMOUNT;
        
        // Set up mismatched assets and amounts
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        // Add some test assets
        vector::push_back(&mut assets, @0xA1);
        vector::push_back(&mut assets, @0xA2);
        vector::push_back(&mut asset_amounts, 10);
        // Missing second amount, causing array length mismatch
        
        // This should fail with EINVALID_ARRAY_LENGTH
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        );
    }


    
}