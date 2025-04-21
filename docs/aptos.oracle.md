
## Oracles

Oracles supply offchain data to the blockchain, enabling smart contracts to access a diverse range of information.

Pyth Network
The Pyth Network is one of the largest first-party Oracle network, delivering real-time data across a vast number of chains.

### Pyth Network Integration

#### Setup
Add to Move.toml:
```toml
[dependencies]
Pyth = { git = "https://github.com/pyth-network/pyth-crosschain.git", subdir = "target_chains/aptos/contracts", rev = "main" }

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

