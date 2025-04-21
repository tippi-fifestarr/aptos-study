
# Oracles
## Pyth Price Feeds on Aptos - Study Notes

## Overview
Pyth Network provides oracle price feeds for Aptos smart contracts. Unlike traditional oracles, Pyth uses a "pull updates" model where users need to:
1. Update the on-chain price (from off-chain)
2. Read the updated price in their on-chain contract

## Setup Instructions

### Add Pyth to Dependencies
In your `Move.toml` file:

```toml
[dependencies]
Pyth = { git = "https://github.com/pyth-network/pyth-crosschain.git", subdir = "target_chains/aptos/contracts", rev = "main" }
```

### Configure Addresses
Add these named addresses to the `[addresses]` section of your `Move.toml`:

```toml
[addresses]
pyth = "0x7e783b349d3e89cf5931af376ebeadbfab855b3fa239b7ada8f5a92fbea6b387"
deployer = "0xb31e712b26fd295357355f6845e77c888298636609e93bc9b05f0f604049f434"
wormhole = "0x5bc11445584a763c1fa7ed39081f1b920954da14e04b32440cba863d03e19625"
```
#### Using Price Feeds
```move
module example::example {
    use pyth::pyth;
    use pyth::price::Price;
    use pyth::price_identifier;
    use aptos_framework::coin;
 
    public fun get_btc_usd_price(user: &signer, pyth_price_update: vector<vector<u8>>): Price {
        // Update price feeds
        let coins = coin::withdraw(user, pyth::get_update_fee(&pyth_price_update));
        pyth::update_price_feeds(pyth_price_update, coins);
 
        // Get price from feed
        let btc_price_identifier = x"e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
        let btc_usd_price_id = price_identifier::from_byte_vec(btc_price_identifier);
        pyth::get_price(btc_usd_price_id)
    }
}
```

### Sponsored Price Feeds
Common price feeds include:
- BTC/USD: `e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43`
- ETH/USD: `ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace`
- APT/USD: `03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5`
- USDC/USD: `eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a`

#### Understanding These Addresses:

- **pyth**: This is the main contract address your code will interact with directly. All price feed data is stored at this address, and all Pyth modules you import are published here. This same address is used on both Aptos mainnet and testnet.

- **wormhole**: Pyth uses Wormhole as its cross-chain messaging protocol. This address is needed because price updates are verified through Wormhole's infrastructure. You won't directly interact with this address, but it's required for proper dependency resolution.

- **deployer**: Represents the account that deployed the Pyth contract on Aptos. Used for certain administrative functions and permissions within the protocol. Like wormhole, this is needed for compilation but not direct interaction.

### Import Pyth in Your Code
```move
use pyth::pyth;
use pyth::price_identifier;
```

## Core Functions

### Reading Price Data

#### 1. Standard Price Getter
```move
// Gets price, reverts if price is stale
pyth::get_price(price_identifier::from_byte_vec(x"<price_identifier>"));
```

#### 2. Unsafe Price Getter
```move
// Gets price regardless of age (can be old)
pyth::get_price_unsafe(price_identifier::from_byte_vec(x"<price_identifier>"));
```

#### 3. Custom Age Threshold
```move
// Gets price only if newer than specified age
pyth::get_price_no_older_than(
  price_identifier::from_byte_vec(x"<price_identifier>"),
  <max_age_secs>
);
```

### Reading EMA Price Data (Exponentially-Weighted Moving Average)

#### 1. Standard EMA Price Getter
```move
// Gets EMA price, reverts if price is stale
pyth::get_ema_price(price_identifier::from_byte_vec(x"<price_identifier>"));
```

#### 2. Unsafe EMA Price Getter
```move
// Gets EMA price regardless of age (can be old)
pyth::get_ema_price_unsafe(price_identifier::from_byte_vec(x"<price_identifier>"));
```

#### 3. Custom Age Threshold for EMA
```move
// Gets EMA price only if newer than specified age
pyth::get_ema_price_no_older_than(
  price_identifier::from_byte_vec(x"<price_identifier>"),
  <max_age_secs>
);
```

### Updating Price Feeds

#### 1. Calculate Update Fee
```move
// Get required fee before updating
pyth::get_update_fee(vec![<update_data>]);
```

#### 2. Update Price with Separate Fee Payment
```move
// Caller withdraws and pays fee separately
let coins = coin::withdraw<AptosCoin>(payer, <fee>);
pyth::update_price_feeds(
  vec![<update_data>],
  coins
);
```

#### 3. Update Price with Automatic Fee Payment
```move
// Fee automatically withdrawn from signer account
pyth::update_price_feeds_with_funder(
  funder,
  vec![<update_data>]
);
```

### Utility Functions

#### Check if Price Feed Exists
```move
// Returns true if the feed has been updated at least once
pyth::price_feed_exists(price_identifier::from_byte_vec(x"<price_identifier>"));
```

#### Get Default Staleness Threshold
```move
// Returns default staleness threshold in seconds
pyth::get_stale_price_threshold_secs();
```

## Price Feed Format Details

- **Price Feed ID**: 32-byte identifier (in hex) for each trading pair
  - You must look up the specific ID for each asset you want to use (BTC/USD, ETH/USD, etc.)
  - These IDs uniquely identify which asset price you're fetching
  - Example: `pyth::get_price(price_identifier::from_byte_vec(x"ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace"))`
- **Price Format**: Represented as `a * 10^e` where `e` is the exponent
  - Example: Price of 1234 with exponent -2 = 12.34
- **Returned Data**: Includes price, confidence interval, and timestamp

## Important Notes

1. **Update Before Read**: Always call `update_price_feeds` before reading prices to ensure freshness
2. **Update Data Source**: Get update data from Hermes API (deserialize from base64)
3. **Fees**: Updates require payment in Aptos Coins (Octa)
4. **Age Verification**: Use appropriate getter depending on your staleness requirements
5. **Same Address**: Pyth contract has the same address on both mainnet and testnet
6. **Asset Selection**: You need to specify which asset price you want by using its Price Feed ID
   - The documentation doesn't pre-select any specific asset for you
   - You must choose which assets your application needs (BTC/USD, ETH/USD, etc.)
   - Find the Price Feed ID for your chosen asset in the Pyth documentation

## Typical Usage Pattern

1. Fetch price update data from Hermes API (off-chain)
2. Call `update_price_feeds` with update data and fee
3. Call one of the price getter functions in your contract
4. Use returned price and confidence interval in your logic