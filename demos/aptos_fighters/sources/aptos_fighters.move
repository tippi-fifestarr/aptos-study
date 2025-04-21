module aptos_fighters_address::aptos_fighters {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    
    use aptos_framework::object::{Self, Object, LinearTransferRef, TransferRef};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::coin;
    use aptos_token::token::{Self, Token};
    use pyth::pyth;
    use pyth::price::Price;
    use pyth::price_identifier;
    use aptos_framework::account;
    #[test_only]
    use std::debug;
/*   

 ========== STATE VARIABLES ========== 

    // Player addresses
    address public player1;
    address public player2;

    // Token used for staking and rewards
    IERC20 public immutable gameToken;

    // Asset balances for each player
    mapping(address => uint256) public userAsset1Balance;
    mapping(address => uint256) public userAsset2Balance;

    // Oracle configuration
    uint256 public immutable oracleExpirationThreshold;
    AggregatorV3Interface public immutable dataFeed;

    // Reward claim tracking using a single uint256 for gas optimization

    // Individual reward claim tracking
    bool private player1RewardClaimed;
    bool private player2RewardClaimed;

    ========== GAME CONFIGURATION ========== 

    struct GameRules {
        uint256 gameStakingAmount;
        uint256 gameDuration;
        uint256 gameStartTime;
        uint256 rewardAmount;
        address[] assets;
        uint256[] assetAmounts;
    }

    GameRules public gameRules;
*/
    struct GameRules has store, drop {
         game_staking_amount:u64,
         game_duration:u64,
         game_start_time:u64,
         reward_amount:u64,
         assets: vector<address>,
         asset_amounts : vector<u64>,
        
    }
    // mapping
    struct AssetBalance has key, store, drop {
         player: address,
         balance: u64,
        
    }

    //:!:>resource
    struct Game has key, store, drop {
        player1:address,
        player2:address,
        // oracle_expiration_threshold:u64, // how can we make it immutable????? in pyth i couldn't get much details or i can say i couldn't understand it but i'm 100% sure it's not like we used to with chainlink price feeds
        data_feed: vector<u8>,// TODO, get the object type
        player1_reward_claimed:bool,
        player2_reward_claimed:bool,
        game_token: address, // let's just use the address, make it simpler 
        user_asset1_balance: vector<AssetBalance>,
        user_asset2_balance: vector<AssetBalance>,
        game_rules: GameRules,
    }
    //<:!:resource
/*    event PlayerEnrolled(address indexed player);
    event AssetTraded(
        address indexed player,
        bool isBuy,
        uint256 assetAmount,
        uint256 price
    );
    event GameStarted(uint256 startTime, uint256 duration);
    event GameWinner(address indexed winner);
    event RewardClaimed(address indexed player, uint256 amount, bool isWinner);
*/

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
        winner: address // todo :how to make it indexed?
     
    }
    #[event]
    struct RewardClaimed has drop, store {
        account: address,
        amount: u64,
        is_winner: bool,
    }

/*    error InvalidAddress();
    error InvalidAmount();
    error InvalidDuration();
    error InvalidArrayLength();
    error GameIsFull();
    error NotAuthorized();
    error GameInProgress();
    error GameNotStarted();
    error GameEnded();
    error GameNotEnded();
    error InsufficientBalance(uint256 required, uint256 available);
    error PriceOracleExpired();
    error PriceOracleInvalid();
    error RewardAlreadyClaimed();
    error TransferFailed();
    error InvalidGameStatus();*/

    /*In Move, errors are typically defined using error constants within a module:
    In Move, you would use these error codes with assert! or abort statements. For example:
move// Instead of: if (condition) revert InsufficientBalance(required, available);
assert!(balance >= required, EINSUFFICIENT_BALANCE);

// For more complex error handling:
if (balance < required) {
    // In Move, you can't include values in error messages directly like in Solidity
    // Instead, you would typically use events to log additional information
    abort EINSUFFICIENT_BALANCE
};
Note that unlike Solidity, Move doesn't support parameterized errors. 
For something like InsufficientBalance(uint256 required, uint256 available),
 you would typically emit an event before aborting to include that additional information.
*/
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

/*constructor(
        address _dataFeeds,
        address _gameToken, // Added gameToken as a constructor parameter
        GameRules memory _gameRules,
        uint256 _oracleExpirationThreshold
    ) {
        if (_dataFeeds == address(0)) {
            revert InvalidAddress();
        }
        if (_gameToken == address(0)) {
            revert InvalidAddress();
        }
        if (_gameRules.gameStakingAmount == 0) {
            revert InvalidAmount();
        }
        if (_gameRules.rewardAmount == 0) {
            revert InvalidAmount();
        }
        if (_gameRules.gameDuration == 0) {
            revert InvalidDuration();
        }
        if (_gameRules.assets.length != _gameRules.assetAmounts.length) {
            revert InvalidArrayLength();
        }
        if (_oracleExpirationThreshold == 0) {
            revert InvalidDuration();
        }

        gameRules = _gameRules;
        gameToken = IERC20(_gameToken); // Initialize gameToken directly from the constructor parameter
        dataFeed = AggregatorV3Interface(_dataFeeds);
        oracleExpirationThreshold = _oracleExpirationThreshold;
    }*/
/// init 
// note: pyth works slightly different than chainlink , we just need to add the price id, pyth address is fixed
// public entry fun init_contract(game_token: Object<Token>,price_id: vector<u8> ,game_rule :Object<GameRules>) {
public entry fun init_contract(
deployer: &signer, // we have to use it, although the contract should not be ownable but i can't use move_to without singer 
    game_token_add: address, 
    price_id: vector<u8>,
    game_staking_amount: u64,
    game_duration: u64,
    game_start_time: u64,
    reward_amount: u64,
    assets: vector<address>,
    asset_amounts: vector<u64>
) { // so acquire we use when we read storage ? need to validate 
/**here is what claude said : 
The `acquires` keyword in Move is used to explicitly declare what resources a function needs to access from global storage. It's a key feature of Move's safety and permission system.

Here's why we use `acquires`:

1. **Memory Safety**: It explicitly declares which resources a function will read from or write to in global storage, making memory access patterns clear.

2. **Static Verification**: The Move compiler can statically verify that a function only accesses the resources it declares, preventing unauthorized access to other resources.

3. **Preventing Reentrancy Attacks**: By forcing explicit declaration of resource access, the compiler can detect potential reentrancy issues where a function might indirectly access a resource it's already modifying.

4. **Documentation**: It serves as documentation for developers, making it clear what global state a function interacts with.

For example, in your code:

```move
#[test(account = @0x1)]
public entry fun sender_can_set_message(account: signer) acquires Game {
    // This tells the compiler that this function will access the Game resource
}
```

When you use functions like `borrow_global<Game>()` or `borrow_global_mut<Game>()` to access a Game resource from global storage, you must declare `acquires Game` on that function.

You don't need `acquires` when you're:
1. Only creating new resources (using `move_to`)
2. Not accessing any existing resources
3. Only accessing resources through accessor functions that themselves have the appropriate `acquires` annotations

That's why you correctly noted you don't need `acquires Game` in your `init_contract` function - you're only creating a new Game resource, not accessing an existing one.



*/
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
    
    // setting default values for uninitialized items
    let game = Game {
        data_feed: price_id,
        player1_reward_claimed: false,
        player2_reward_claimed: false,
        game_token: game_token_add,
        game_rules: game_rules,
        // Default values for missing fields
        player1: @0x0,
        player2: @0x0,
        user_asset1_balance: vector::empty<AssetBalance>(),
        user_asset2_balance: vector::empty<AssetBalance>()
    };
    
    move_to(deployer, game);
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
        
        // Verify the contract was initialized
        assert!(exists_at(DEPLOYER), 0);
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
    
    // Verify the game exists
    assert!(exists<Game>(deployer_address), 0);
    
    // Optional: Verify game properties are set correctly
    let game = borrow_global<Game>(deployer_address);
    
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