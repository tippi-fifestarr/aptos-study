# Aptos Fighters

This project is a Move implementation of the Ethereum Fighters contract, originally implemented in Solidity with FHEVM (Fully Homomorphic Encryption Virtual Machine) capabilities. The original project was an ETHGlobal Taipei winner.

## Concept Overview

Aptos Fighters is a trading simulation game where two players compete by managing their asset portfolios. Each player starts with an initial allocation of assets and can buy or sell based on real-time price data. At the end of the game period, the player with the highest combined portfolio value wins.

## Key Implementation Differences

### Ethereum Version:
- Uses FHEVM for encrypted balance management
- Relies on Chainlink for price oracles
- Implements a gateway caller for FHE decryption
- Uses OpenZeppelin ERC20 for token handling

### Aptos Version:
- Uses Move resources for balance tracking with appropriate access controls
- Integrates with Pyth Network for price oracle data
- Implements game logic using Move's resource model
- Leverages Aptos's token standard for staking and rewards

## Core Features to Implement

1. **Player Enrollment**
   - Players stake tokens to join the game
   - Initial asset allocation (ETH and stablecoin equivalents)
   - Time-based game progression

2. **Trading Logic**
   - Buy and sell functions for assets
   - Price fetching from Pyth oracle
   - Balance updates with proper access controls

3. **Game Conclusion**
   - Score calculation based on final portfolio values
   - Winner determination
   - Reward distribution mechanism

4. **Security Features**
   - Parameter validation
   - Time-based constraints
   - Oracle data validation

## Implementation Plan

```move
module aptos_fighters_address::aptos_fighter {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::event;
    use pyth::pyth;
    use pyth::price;
    use pyth::price_identifier;
    
    // Game rules configuration
    struct GameRules has key {
        game_staking_amount: u64,
        game_duration: u64,
        game_start_time: u64,
        reward_amount: u64,
        assets: vector<address>,
        asset_amounts: vector<u64>
    }
    
    // Player state
    struct PlayerState has key, store {
        asset1_balance: u64,
        asset2_balance: u64,
        rewards_claimed: bool
    }
    
    // Game state
    struct GameState has key {
        player1: address,
        player2: address,
        scores_calculated: bool,
        player1_final_score: u64,
        player2_final_score: u64
    }
    
    // Events
    #[event]
    struct PlayerEnrolled has drop, store {
        player: address
    }
    
    #[event]
    struct AssetTraded has drop, store {
        player: address,
        is_buy: bool,
        timestamp: u64
    }
    
    #[event]
    struct ScoresCalculated has drop, store {
        player1_score: u64,
        player2_score: u64
    }
    
    #[event]
    struct GameWinner has drop, store {
        winner: address
    }
    
    #[event]
    struct RewardClaimed has drop, store {
        player: address,
        amount: u64,
        is_winner: bool
    }
    
    // Error codes
    const ENOT_OWNER: u64 = 1;
    const EZERO_ADDRESS: u64 = 2;
    const EZERO_DURATION: u64 = 3;
    const EZERO_AMOUNT: u64 = 4;
    const EINVALID_ORACLE_THRESHOLD: u64 = 5;
    const EGAME_IS_FULL: u64 = 6;
    const EARRAY_LENGTH_MISMATCH: u64 = 7;
    const EPLAYER_NOT_ENROLLED: u64 = 8;
    const EPLAYER_ALREADY_ENROLLED: u64 = 9;
    const EGAME_NOT_STARTED: u64 = 10;
    const EGAME_STARTED: u64 = 11;
    const EGAME_NOT_ENDED: u64 = 12;
    const ENOT_A_PLAYER: u64 = 13;
    const ESCORES_NOT_CALCULATED: u64 = 14;
    const EPRICE_ORACLE_EXPIRED: u64 = 15;
    const EPRICE_ORACLE_INVALID: u64 = 16;
    const EMISSING_GAME_RULES: u64 = 17;
    const EREWARD_ALREADY_CLAIMED: u64 = 18;
    
    // Implementation of key functions would go here:
    // - init_module
    // - enroll_player
    // - buy_eth
    // - sell_eth
    // - fetch_price
    // - calculate_scores
    // - get_winner
    // - claim_reward
}
```

## Testing Strategy

1. **Unit Tests**
   - Test each function in isolation with different inputs
   - Verify error conditions are properly checked

2. **Integration Tests**
   - Test complete game flow with two players
   - Verify winner determination logic
   - Test reward distribution

3. **Mock Oracle Tests**
   - Create mock price data for testing
   - Verify price fetching and calculation logic

## Setup Instructions

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/aptos-study-notes.git
   cd demos/AptosFighters
   ```

2. Compile the Move code
   ```bash
   aptos move compile
   ```

3. Run tests
   ```bash
   aptos move test
   ```

4. Deploy to testnet (ensure you have testnet tokens)
   ```bash
   aptos move publish --named-addresses aptos_fighters=YOUR_ADDRESS
   ```

## Usage Example

```bash
# Initialize a new game with parameters
aptos move run --function-id $ADDRESS::aptos_fighter::initialize_game \
  --args u64:1000000 u64:3600 u64:100000

# Player 1 enrolls
aptos move run --function-id $ADDRESS::aptos_fighter::enroll_player

# Player 1 buys ETH
aptos move run --function-id $ADDRESS::aptos_fighter::buy_eth \
  --args u64:10

# Player 1 sells ETH
aptos move run --function-id $ADDRESS::aptos_fighter::sell_eth \
  --args u64:5

# Calculate final scores
aptos move run --function-id $ADDRESS::aptos_fighter::calculate_scores

# Player 1 claims reward
aptos move run --function-id $ADDRESS::aptos_fighter::claim_reward
```