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
    use aptos_token::token::{Self, Token};
    use pyth::pyth;
    use pyth::price::Price;
    use pyth::price_identifier;
    use aptos_framework::coin;
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
    struct AssetBalance has key,store, drop {
         player: address,
         balance: u64,
        
    }

    //:!:>resource
    struct Game has key,store, drop {
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
    // Check input data
    assert!(game_duration > 0, error::invalid_argument(EINVALID_DURATION));
    assert!(game_staking_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
    assert!(reward_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
    assert!(game_start_time > timestamp::now_seconds(), error::invalid_argument(EINVALID_GAME_START_TIME));
    
    let assets_length = vector::length(&assets);
    let amounts_length = vector::length(&asset_amounts);
    
    // Changed != to == (you want them to be equal, not unequal)
    assert!(assets_length == amounts_length, error::invalid_argument(EINVALID_ARRAY_LENGTH));
    
    // I wanted to use  object::exists_at instead or exists<Token> but it's not working , let's use this generic way for now
    assert!(object::is_object(game_token_add), error::not_found(EINVALID_ADDRESS));

    let game_rules =GameRules{
         game_staking_amount,
         game_duration,
         game_start_time,
         reward_amount,
         assets,
         asset_amounts };
         // setting default values for uninitialized items
      let game = Game {
            data_feed: price_id,
            player1_reward_claimed: false,
            player2_reward_claimed: false,
            game_token:game_token_add,
            game_rules: game_rules,
            // Default values for missing fields
            player1: @0x0,
            player2: @0x0,
            user_asset1_balance: vector::empty<AssetBalance>(),
            user_asset2_balance: vector::empty<AssetBalance>()
};
move_to(deployer,game);
}



/// functions 





/// view functions 


    // #[view]
    // public fun get_message(addr: address): string::String acquires MessageHolder {
    //     assert!(exists<MessageHolder>(addr), error::not_found(ENO_MESSAGE));
    //     borrow_global<MessageHolder>(addr).message
    // }

    // public entry fun set_message(account: signer, message: string::String)
    // acquires MessageHolder {
    //     let account_addr = signer::address_of(&account);
    //     if (!exists<MessageHolder>(account_addr)) {
    //         move_to(&account, MessageHolder {
    //             message,
    //         })
    //     } else {
    //         let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
    //         let from_message = old_message_holder.message;
    //         event::emit(MessageChange {
    //             account: account_addr,
    //             from_message,
    //             to_message: copy message,
    //         });
    //         old_message_holder.message = message;
    //     }
    // }

    #[test(account = @0x1)]
    public entry fun sender_can_set_message(account: signer) acquires Game {
        let msg: string::String = string::utf8(b"Running test for sender_can_set_message...");
        debug::print(&msg);

        let addr = signer::address_of(&account);
        aptos_framework::account::create_account_for_test(addr);
        //init_module(account, string::utf8(b"Hello, Blockchain"));

        // assert!(
        //     get_message(addr) == string::utf8(b"Hello, Blockchain"),
        //     ENO_MESSAGE
        // );
    }
}