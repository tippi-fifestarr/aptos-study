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
    use aptos_token::token::{Self, Token, Collection};
    #[test_only]
    use std::debug;
/*    /* ========== STATE VARIABLES ========== */

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

    /* ========== GAME CONFIGURATION ========== */

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
        assets: vec<address>,
         asset_amounts : vec<u64>,
        
    }
    //:!:>resource
    struct Game has key {
        player1:address,
        player2:address,
        oracle_expiration_threshold:u64, // how can we make it immutable?????
        data_feed: address,// TODO, get the object type
        player1_reward_claimed:bool,
        player2_reward_claimed:bool,
        game_token:  Object<Token>,
        user_asset1_balance: vec<address,u64>,
        user_asset2_balance: vec<address,u64>,
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


    /// There is no message present
    const ENO_MESSAGE: u64 = 0;

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

    // #[test(account = @0x1)]
    // public entry fun sender_can_set_message(account: signer) acquires MessageHolder {
    //     let msg: string::String = string::utf8(b"Running test for sender_can_set_message...");
    //     debug::print(&msg);

    //     let addr = signer::address_of(&account);
    //     aptos_framework::account::create_account_for_test(addr);
    //     set_message(account, string::utf8(b"Hello, Blockchain"));

    //     assert!(
    //         get_message(addr) == string::utf8(b"Hello, Blockchain"),
    //         ENO_MESSAGE
    //     );
    // }
}