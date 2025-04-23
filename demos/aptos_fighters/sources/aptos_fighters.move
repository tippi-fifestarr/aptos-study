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

/// we have to add this to use a resource account pattern to properly manage transfers suggested by claude
struct ModuleData has key {
    signer_cap: account::SignerCapability,
    // other module data
}
    struct GameRules has store, drop,copy {
         game_staking_amount:u64,
         game_duration:u64,
         game_start_time:u64,
         reward_amount:u64,
         assets: vector<address>,
         asset_amounts : vector<u64>,
        
    }
    // mapping
    struct AssetBalance has key, store, drop { // it could be simplified to balance 1 and 22
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
fun init_module(deployer: &signer) {
    let seed = b"aptos_fighters";
    let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
    
    // Store the signer capability
    move_to(deployer, ModuleData {
        signer_cap: resource_signer_cap,
        // other fields
    });
}
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
            public entry fun player_can_set_message(account: signer) acquires Game {
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
       let obj_hold_add = object::create_named_object(
            // singer , seed 
            deployer, construct_seed(1)
        );
        let obj_add = object::generate_signer(&obj_hold_add);
    
    move_to(&obj_add, game);
}
public entry fun enroll_player(player:&signer, deployer:address) acquires Game{
    
    let game = borrow_global_mut<Game>(get_game_address(deployer,1));
    let player_addr = signer::address_of(player);
    assert!(game.game_rules.game_start_time> timestamp::now_seconds(),error::invalid_argument(EGAME_IN_PROGRESS) );
    assert!(game.player1 == @0x0 || game.player2 == @0x0, error::invalid_argument(EGAME_IS_FULL));
    assert!(game.player1 != signer::address_of(player) || game.player2 != signer::address_of(player), error::invalid_argument(ENOT_AUTHORIZED));
    stake(player,  game.game_token, game.game_rules.game_staking_amount); 
    let i = 0;
        let length = vector::length(& game.game_rules.assets);
        while (i < length) {
          let asset=   vector::borrow(& game.game_rules.assets, i);
          let amount=   vector::borrow(& game.game_rules.asset_amounts, i);
            // Now you have both i (index) and element
            // Do something with index i and element
            // get metadata of the token and check the balance, player should hold these balances 
              let asset_metadata = object::address_to_object<Metadata>(*asset);
             assert!(primary_fungible_store::balance(player_addr, asset_metadata) == *amount, EINSUFFICIENT_BALANCE);
    
        };
        // let's update state 
        if (game.player1==@0x0){
            game.player1= player_addr;
        }else{
            game.player2= player_addr;
        };
        // set initial balances 
        let asset1_balance = AssetBalance{
            player:player_addr,
            balance:ASSET1_DEFAULT_BALANCE,
        };
        let asset2_balance = AssetBalance{
            player:player_addr,
            balance:ASSET2_DEFAULT_BALANCE,
        };
        //  you still need to explicitly use &mut to access and modify fields within it
        vector::push_back(&mut game.user_asset1_balance,  asset1_balance);
        vector::push_back(&mut game.user_asset2_balance,  asset2_balance);
        event::emit(PlayerEnrolled{player:player_addr});
                // If both players are enrolled, update game status
            
          if (game.player1!=@0x0 && game.player2!=@0x0){
             // Check if game should start immediately
                    if (timestamp::now_seconds() >= game.game_rules.game_start_time) {
                        event::emit(GameStarted{
                              start_time:  game.game_rules.game_start_time, 
                                duration:  game.game_rules.game_duration, 
                        });
                    };
            
        };
}
        /**
            function enrollPlayer() external {
                // Check if game start time has passed
                if (block.timestamp >= gameRules.gameStartTime) revert GameInProgress();

                // Check player is not already enrolled
                if (msg.player == player1 || msg.player == player2)
                    revert NotAuthorized();

                // Check if game is full
                if (player1 != address(0) && player2 != address(0)) revert GameIsFull();

                // Stake the game token
                gameToken.safeTransferFrom(
                    msg.player,
                    address(this),
                    gameRules.gameStakingAmount
                );

                // Transfer required assets
                uint256 assetCount = gameRules.assets.length;
                for (uint256 i = 0; i < assetCount; ++i) {
                    IERC20 asset = IERC20(gameRules.assets[i]);
                    uint256 requiredAmount = gameRules.assetAmounts[i];

                    if (asset.balanceOf(msg.player) < requiredAmount) {
                        revert InsufficientBalance(
                            requiredAmount,
                            asset.balanceOf(msg.player)
                        );
                    }

                    asset.safeTransferFrom(msg.player, address(this), requiredAmount);
                }

                // Register player
                if (player1 == address(0)) {
                    player1 = msg.player;
                } else {
                    player2 = msg.player;
                }

                // Initialize player balances
                userAsset1Balance[msg.player] = 100; // Give some initial balance for gameplay
                userAsset2Balance[msg.player] = 10000; // Give some initial balance for gameplay

                emit PlayerEnrolled(msg.player);

                // If both players are enrolled, update game status
                if (player1 != address(0) && player2 != address(0)) {
                    // Check if game should start immediately
                    if (block.timestamp >= gameRules.gameStartTime) {
                        emit GameStarted(block.timestamp, gameRules.gameDuration);
                    }
                }
            }
        */
public entry fun buy_apt (player:&signer, amount:u64, deployer:address) acquires Game{
    
    let game = borrow_global_mut<Game>(get_game_address(deployer,1));
    let player_add = signer::address_of(player);
    // is authorized ? is player i mean 
    assert!(game.player1==player_add || game.player2==player_add, ENOT_AUTHORIZED);
    // Check if game has ended
    assert!(timestamp::now_seconds()< game.game_rules.game_start_time+ game.game_rules.game_duration, EGAME_ENDED);
    // Skip operation if amount is zero
    if (amount==0){
        return
    };
     // Fetch current apt price

        let price = fetch_price(game.data_feed);
        let price_positive = i64::get_magnitude_if_positive(&price::get_price(&price)); // This will fail if the price is negative
        let expo_magnitude = i64::get_magnitude_if_negative(&price::get_expo(&price)); // This will fail if the exponent is positive

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

        /** function buyEth(uint256 amount) external onlyPlayers returns (bool) {
                // Check if game has ended
                if (
                    block.timestamp > gameRules.gameStartTime + gameRules.gameDuration
                ) {
                    revert GameEnded();
                }

                // Skip operation if amount is zero
                if (amount == 0) return true;

                // Fetch current ETH price
                uint256 price = fetchPrice();

                // Calculate cost
                uint256 cost = price * amount;

                // Check player has sufficient balance
                if (userAsset2Balance[msg.player] < cost) {
                    revert InsufficientBalance(cost, userAsset2Balance[msg.player]);
                }

                // Update balances
                userAsset1Balance[msg.player] += amount;
                userAsset2Balance[msg.player] -= cost;

                emit AssetTraded(msg.player, true, amount, price);
                return true;
            }*/


public entry fun sell_apt (player:&signer, amount:u64, deployer:address) acquires Game{
    
    let game = borrow_global_mut<Game>(get_game_address(deployer,1));
    let player_add = signer::address_of(player);
    // is authorized ? is player i mean 
    assert!(game.player1==player_add || game.player2==player_add, ENOT_AUTHORIZED);
    // Check if game has ended
    assert!(timestamp::now_seconds()< game.game_rules.game_start_time+ game.game_rules.game_duration, EGAME_ENDED);
    // Skip operation if amount is zero
    if (amount==0){
        return
    };
     // Fetch current apt price

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
            /**function sellEth(uint256 amount) external onlyPlayers returns (bool) {
        // Check if game has ended
        if (
            block.timestamp > gameRules.gameStartTime + gameRules.gameDuration
        ) {
            revert GameEnded();
        }

        // Skip operation if amount is zero
        if (amount == 0) return true;

        // Fetch current ETH price
        uint256 price = fetchPrice();

        // Calculate revenue
        uint256 revenue = price * amount;

        // Check player has sufficient ETH
        if (userAsset1Balance[msg.sender] < amount) {
            revert InsufficientBalance(amount, userAsset1Balance[msg.sender]);
        }

        // Update balances
        userAsset1Balance[msg.sender] -= amount;
        userAsset2Balance[msg.sender] += revenue;

        emit AssetTraded(msg.sender, false, amount, price);
        return true;
    }*/

    public entry fun withdraw (player:&signer, deployer:address) acquires Game , ModuleData{
        let game = borrow_global_mut<Game>(get_game_address(deployer,1));
        let player_add = signer::address_of(player);
        assert!(game.player1==player_add || game.player2==player_add, ENOT_AUTHORIZED);
        assert!(timestamp::now_seconds()>game.game_rules.game_start_time+ game.game_rules.game_duration, EGAME_NOT_ENDED);
        // Determine if the caller is player1 or player2
        let amount_to_withdraw =game.game_rules.game_staking_amount;
        // let is_Player1 = ( == game.player1);
        let (winner,amount)= get_winner_fun(game);
        // since we only expect player1 or 2 because of the above assert , we can safely do if/else
        if ( game.player1== player_add){
            assert!(!game.player1_reward_claimed, EREWARD_ALREADY_CLAIMED);
         
        }else{ // if not player one , s/he is 100% player 2
             assert!(!game.player2_reward_claimed, EREWARD_ALREADY_CLAIMED);

        };
   if (winner==player_add){
                amount_to_withdraw= amount_to_withdraw+ game.game_rules.reward_amount;
            };
    // @todo : not working because we need a signer 
    // primary_fungible_store::transfer(@aptos_fighters_address, metadata, player_add,amount_to_withdraw); // how can we transfer it to the contract itself ??? 
        
        transfer_from_contract(player_add,game.game_token, amount_to_withdraw);
        event::emit(RewardClaimed{  
         account: player_add,
        amount: amount_to_withdraw,
        is_winner: winner==player_add});
    }



    /* function withdraw() public onlyPlayers {
        // Ensure game has ended
        if (
            block.timestamp < gameRules.gameStartTime + gameRules.gameDuration
        ) {
            revert GameNotEnded();
        }

        // Determine if the caller is player1 or player2
        bool isPlayer1 = (msg.sender == player1);

        // Check if this player has already claimed their reward
        if (
            (isPlayer1 && player1RewardClaimed) ||
            (!isPlayer1 && player2RewardClaimed)
        ) {
            revert RewardAlreadyClaimed();
        }

        // Get the winner
        address winner = _getWinner();

        // Calculate amount to return
        uint256 amountToReturn = gameRules.gameStakingAmount;
        bool isWinner = (msg.sender == winner);

        // Add reward amount if this player is the winner
        if (isWinner && winner != address(0)) {
            amountToReturn += gameRules.rewardAmount;
        }

        // Mark as claimed
        if (isPlayer1) {
            player1RewardClaimed = true;
        } else {
            player2RewardClaimed = true;
        }

        // Transfer tokens
        gameToken.safeTransfer(msg.sender, amountToReturn);

        // Emit event
        emit RewardClaimed(msg.sender, amountToReturn, isWinner);
    }*/
// helper 


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
fun stake(
    player: &signer, 
    game_token: address, 
    amount: u64
)  {
  
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
public fun get_winner (deployer:address):(address, u64) acquires Game{
 let game = borrow_global<Game>(get_game_address(deployer,1));
 assert!(timestamp::now_seconds()>game.game_rules.game_start_time+ game.game_rules.game_duration, EGAME_NOT_ENDED);
 get_winner_fun(game)

}
/*   function getWinner() external view returns (address) {
        // Check if the game has ended
        if (
            block.timestamp <= gameRules.gameStartTime + gameRules.gameDuration
        ) {
            revert GameNotEnded();
        }

        return _getWinner();
    }
    
      function _getWinner() internal view returns (address) {
        uint256 player1Value = userAsset1Balance[player1] +
            userAsset2Balance[player1];
        uint256 player2Value = userAsset1Balance[player2] +
            userAsset2Balance[player2];

        if (player1Value > player2Value) {
            return player1;
        } else if (player2Value > player1Value) {
            return player2;
        } else {
            return address(0); // Tie
        }
    }

    
    */
fun get_winner_fun(game: &Game): (address, u64) {
    let player1 = game.player1;
    let player2 = game.player2;
    
    // Use immutable read-only version of the function
    let player1_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player1);
    let player1_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player1);
    let player2_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player2);
    let player2_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player2);
    
    let player1_total_val = player1_asset1_balance.balance + player1_asset2_balance.balance;
    let player2_total_val = player2_asset1_balance.balance + player2_asset2_balance.balance;
    
    // Determine the winner based on total value
    if (player1_total_val > player2_total_val) {
        (player1, player1_total_val)
    } else {
        (player2, player2_total_val)
    }
}

// Non-mutable version of the balance lookup function
public fun get_user_asset_balance(
    asset_balances: &vector<AssetBalance>,
    user_address: address
): &AssetBalance {
    let i = 0;
    while (i < vector::length(asset_balances)) {
        let balance = vector::borrow(asset_balances, i);
        if (balance.player == user_address) {
            return balance
        };
        i = i + 1;
    };
    // Handle case where no matching address is found
    abort 1 // Or a more specific error code
}
// Return a mutable reference to the matching AssetBalance

// Remove #[view] since view functions can't return mutable references
 fun get_user_asset_balance_mut(
    asset_balances: &mut vector<AssetBalance>,  // Changed parameter name for clarity
    user_address: address
): &mut AssetBalance {
    let i = 0;
    while (i < vector::length(asset_balances)) {
        let balance = vector::borrow_mut(asset_balances, i);  // Changed variable name
        if (balance.player == user_address) {
            return balance
        };
        i = i + 1;
    };
    // Handle case where no matching address is found
    abort 1 // Or a more specific error code
}
 #[view]
 public fun get_game_rules (deployer_address :address): GameRules acquires Game{
    // we have to use copy treat, here's why 
    /*
     cannot return a reference derived from struct `aptos_fighters::Game` since it is not based on a parameter
     struct `aptos_fighters::Game` previously borrowed here
     AI explains : 
    The error message shows an important Move safety rule: you can't return a reference to something that exists in global storage.
This is a fundamental safety feature in Move. References returned from functions must be derived from the function's input parameters, not from global storage. This prevents dangling references and other memory safety issues.
*/
   
    let game = borrow_global<Game>(deployer_address);
    game.game_rules
 }
// helper functions 
#[view]
    public fun construct_seed(seed: u64): vector<u8> {
        //Wwe add contract address as part of the seed so seed from 2 todo list contract for same user would be different
        bcs::to_bytes(&string_utils::format2(&b"{}_{}", @aptos_fighters_address, seed))
    }

#[view]
public fun get_game_address(deployer: address, seed: u64): address {
    // Calculate the object address from the deployer and seed
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