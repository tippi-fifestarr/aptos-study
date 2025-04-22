# Aptos Fungible Asset (FA) Standard - Study Notes

## Overview

The Aptos Fungible Asset (FA) standard provides a type-safe, flexible way to represent fungible assets in the Move ecosystem. Built on the foundation of AIP-73 (Dispatchable Token Standard), it offers significant advantages over the legacy coin module through enhanced customization capabilities and Move object integration.

## Key Concepts

### Foundation: AIP-73 Dispatchable Token Standard

- **Purpose**: Enables token creators to inject custom logic during token operations
- **Technical Approach**: Uses dispatch functions to customize token behavior
- **Innovation**: Simulates runtime function pointers via `function_info.move`
- **Security**: Runtime checks prevent re-entrancy while enabling custom behavior

### Core Components (Move Objects)

1. **Object\<Metadata>**
   - Represents asset details (name, symbol, decimals)
   - Owned by the FA creator

2. **Object\<FungibleStore>**
   - Stores token balances owned by an account
   - References the Metadata Object 
   - Accounts can have multiple stores per FA (advanced cases)

### Advantages Over Coin Standard

- More customizable via smart contract hooks
- Automatic tracking of asset ownership
- Recipients don't need to register separate stores

## Creating a Fungible Asset

### Step 1: Create Non-deletable Object

```move
// Create a named object
let constructor_ref = &object::create_named_object(caller_address, b"TOKEN_NAME");
// Alternatively: object::create_sticky_object(caller_address)
```

### Step 2: Generate Metadata

```move
// Create with primary store enabled for automatic store creation
primary_fungible_store::create_primary_store_enabled_fungible_asset(
    constructor_ref,
    option::some(1000000000),    // Optional maximum supply
    string::utf8(b"My Token"),   // Name
    string::utf8(b"MTK"),        // Symbol
    8,                           // Decimals
    string::utf8(b"https://example.com/icon.png"), // Icon URI
    string::utf8(b"https://example.com")           // Project URI
);
```

### Step 3: Generate Capability References

```move
// Generate capability references during object creation
let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

// Store refs in a resource
move_to(creator, TokenAdmin { mint_ref, burn_ref, transfer_ref });
```

## Basic Operations

### For Token Holders

#### 1. Withdraw
```move
// Extract tokens from your account
public entry fun withdraw<T: key>(
    owner: &signer,
    metadata_address: address,
    amount: u64
) {
    let metadata = object::address_to_object<T>(metadata_address);
    let fa = primary_fungible_store::withdraw(owner, metadata, amount);
    // Do something with the withdrawn FA...
}
```

#### 2. Deposit
```move
// Add tokens to an account
public entry fun deposit_fa(recipient: address, fa: FungibleAsset) {
    primary_fungible_store::deposit(recipient, fa);
}
```

#### 3. Transfer
```move
// Move tokens between accounts
public entry fun transfer<T: key>(
    sender: &signer,
    metadata_address: address,
    recipient: address,
    amount: u64
) {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::transfer(sender, metadata, recipient, amount);
}
```

#### 4. Check Balance
```move
// View function to get account balance
#[view]
public fun get_balance<T: key>(account: address, metadata_address: address): u64 {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::balance(account, metadata)
}
```

#### 5. Check Frozen Status
```move
// Check if account is frozen
#[view]
public fun check_frozen<T: key>(account: address, metadata_address: address): bool {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::is_frozen(account, metadata)
}
```

### For Token Creators

#### Reading Metadata
```move
// Get basic token information
#[view]
public fun get_metadata_info<T: key>(metadata_address: address): (String, String, u8) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}

// Get supply information
#[view]
public fun get_supply_info<T: key>(metadata_address: address): (u128, u128, Option<u128>) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    let supply = fungible_asset::supply(metadata);
    let current_supply = option::none();
    
    if (fungible_asset::has_supply_info(metadata)) {
        current_supply = option::some(fungible_asset::current_supply(metadata));
    }
    
    let maximum_supply = fungible_asset::maximum_supply(metadata);
    
    (supply, option::get_with_default(current_supply, 0), maximum_supply)
}
```

## Implementing Approvals

Unlike ERC-20, Aptos FA doesn't have built-in approvals. There are three implementation approaches:

### 1. Signature-Based Approvals (Recommended)

```move
// Define approval structure
struct Approval has drop {
    owner: address,      // Token owner
    to: address,         // Destination address
    nonce: u64,          // Prevents replay attacks
    chain_id: u8,        // Prevents cross-chain replay
    spender: address,    // Authorized spender
    amount: u64          // Spending amount
}

// Implement transfer_from with signatures
public fun transfer_from(
    spender: &signer,             // Who is spending
    proof: vector<u8>,            // Owner's signature
    from: address,                // Owner's address
    from_account_scheme: u8,      // Signing scheme
    from_public_key: vector<u8>,  // Owner's public key
    to: address,                  // Recipient
    amount: u64                   // Amount to send
) {
    // Create the message that owner should have signed
    let expected_message = Approval {
        owner: from,
        to,
        nonce: account::get_sequence_number(from),
        chain_id: chain_id::get(),
        spender: signer::address_of(spender),
        amount,
    };
    
    // Verify signature matches
    account::verify_signed_message(
        from, 
        from_account_scheme, 
        from_public_key, 
        proof, 
        expected_message
    );
    
    // Perform the transfer
    let transfer_ref = &borrow_global<Management>(token_address()).transfer_ref;
    primary_fungible_store::transfer_with_ref(transfer_ref, from, to, amount);
}
```

### 2. Resource-Based Approvals

```move
// Resource to track allowances
struct Allowances has key {
    values: Table<address, u64>  // spender -> amount
}

// Approve a spender
public entry fun approve(
    owner: &signer,
    spender: address,
    amount: u64
) {
    let owner_addr = signer::address_of(owner);
    
    // Initialize allowances if needed
    if (!exists<Allowances>(owner_addr)) {
        move_to(owner, Allowances { values: table::new() });
    };
    
    // Update allowance
    let allowances = borrow_global_mut<Allowances>(owner_addr);
    if (table::contains(&allowances.values, spender)) {
        *table::borrow_mut(&mut allowances.values, spender) = amount;
    } else {
        table::add(&mut allowances.values, spender, amount);
    }
}

// Transfer on behalf of another account
public entry fun transfer_from(
    spender: &signer,
    owner: address,
    recipient: address,
    amount: u64
) acquires Allowances, Management {
    let spender_addr = signer::address_of(spender);
    
    // Check and update allowance
    assert!(exists<Allowances>(owner), ERROR_NO_ALLOWANCE);
    let allowances = borrow_global_mut<Allowances>(owner);
    assert!(table::contains(&allowances.values, spender_addr), ERROR_NOT_APPROVED);
    
    let allowance = table::borrow_mut(&mut allowances.values, spender_addr);
    assert!(*allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
    *allowance = *allowance - amount;
    
    // Perform transfer
    let transfer_ref = &borrow_global<Management>(token_address()).transfer_ref;
    primary_fungible_store::transfer_with_ref(transfer_ref, owner, recipient, amount);
}
```

### 3. Dispatchable Function Approvals

```move
// Resource to track approvals
struct TokenApprovals has key {
    token_address: address,
    approvals: Table<address, Table<address, u64>> // owner -> (spender -> amount)
}

// Custom withdraw that checks approvals
public fun withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef,
): FungibleAsset {
    let owner = object::owner(store);
    let caller = tx_context::sender();
    
    // Normal withdrawal (owner withdrawing their own tokens)
    if (owner == caller) {
        return fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
    };
    
    // Check approvals for delegated withdrawal
    if (exists<TokenApprovals>(@token_module)) {
        let approvals = borrow_global<TokenApprovals>(@token_module);
        
        if (table::contains(&approvals.approvals, owner) && 
            table::contains(table::borrow(&approvals.approvals, owner), caller)) {
            
            let allowance = table::borrow_mut(
                table::borrow_mut(&mut approvals.approvals, owner),
                caller
            );
            
            assert!(*allowance >= amount, EINSUFFICIENT_ALLOWANCE);
            *allowance = *allowance - amount;
            
            return fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
        };
    };
    
    abort EUNAUTHORIZED
}
```

## Implementing Custom Token Logic (AIP-73)

### Create Custom Hook Functions

```move
// Example: Deflation token with 1% fee on withdrawals
public fun withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef,
): FungibleAsset {
    // Calculate burn amount (1% fee)
    let burn_amount = amount / 100;
    
    // Withdraw the full amount
    let total_fa = fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
    
    // Apply fee logic
    if (burn_amount > 0) {
        let burn_ref = get_burn_ref();
        let burn_fa = fungible_asset::extract(&mut total_fa, burn_amount);
        fungible_asset::burn(burn_ref, burn_fa);
    }
    
    // Return remaining tokens
    total_fa
}
```

### Register Hook Functions

```move
public fun create_token_with_hooks(creator: &signer) {
    // Create token metadata object
    let constructor_ref = &object::create_named_object(creator, b"MY_TOKEN");
    
    // Set up token with standard parameters
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(),                  // No supply limit
        string::utf8(b"My Custom Token"),
        string::utf8(b"MCT"),
        8,
        string::utf8(b"https://example.com/logo.png"),
        string::utf8(b"https://example.com")
    );
    
    // Create FunctionInfo for custom functions
    let withdraw_func = function_info::new_function_info(
        creator,
        string::utf8(b"my_token_module"),
        string::utf8(b"withdraw")
    );
    
    let deposit_func = function_info::new_function_info(
        creator,
        string::utf8(b"my_token_module"),
        string::utf8(b"deposit")
    );
    
    // Register custom functions with the token
    dispatchable_fungible_asset::register_dispatch_functions(
        constructor_ref,
        option::some(withdraw_func),    // Custom withdraw
        option::some(deposit_func),     // Custom deposit
        option::none()                  // Default balance calculation
    );
    
    // Generate and store capability references
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    
    move_to(creator, TokenAuthority { mint_ref, burn_ref, transfer_ref });
}
```

## Store Management

### Primary vs Secondary Stores

**Primary Store**
- One non-deletable store per FA type per account
- Deterministic address derived from account and metadata
- Created automatically when FA is deposited
- Lookup: `primary_store<T: key>(owner, metadata)`

**Secondary Store**
- Non-deterministic addresses, deletable when empty
- Unlimited number can be created
- Used mainly for assets managed by smart contracts
- Creation: `create_store<T: key>(constructor_ref, metadata)`

## Migration from Coin to FA

- No modifications needed for contracts using coin module
- Automatic creation of paired FA when required
- Use `paired_metadata<CoinType>()` to get metadata for paired FA

```move
// Check total balance across coin and FA
#[view]
public fun get_total_balance<CoinType>(user: address): u64 {
    // Get coin balance
    let coin_balance = coin::balance<CoinType>(user);
    
    // Get paired FA balance if exists
    let fa_balance = if (coin::paired_metadata<CoinType>().is_some()) {
        let metadata = option::extract(&mut coin::paired_metadata<CoinType>());
        primary_fungible_store::balance(user, metadata)
    } else {
        0
    };
    
    coin_balance + fa_balance
}
```

## Security Best Practices

### 1. Preventing Re-entrancy

```move
// SAFE pattern: Complete all local computation first
public fun secure_withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef
): FungibleAsset {
    // Do all state checking before making calls
    let is_valid = check_some_condition();
    assert!(is_valid, EINVALID_CONDITION);
    
    // Then perform external calls
    fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
}
```

### 2. Token Creator Best Practices

- Store sensitive Refs (MintRef, BurnRef) in secure resources
- Use non-deletable objects for Metadata
- Set maximum_supply when appropriate
- Implement proper access control for admin operations

### 3. Dispatchable Token Developer Best Practices

- Use only `with_ref` APIs in custom hooks
- Never create cycles in the call graph
- Always check frozen status in custom withdraw logic
- Handle potential arithmetic overflows/underflows

### 4. DApp Developer Integration Best Practices

- Check if a token uses dispatchable functionality
- Be aware that tokens may implement custom transfer logic
- Always check frozen status before transfers
- Test with edge cases (zero amount, very large amount)

I understand the confusion. Let me rewrite the explanation with clearer, side-by-side code examples to show exactly when and how to use each module.

# `fungible_asset` vs `primary_fungible_store`

## Core Differences

| `fungible_asset` | `primary_fungible_store` |
|------------------|--------------------------|
| Works directly with token objects and stores | Works with accounts and automates store management |
| Lower-level, more control | Higher-level, more convenience |
| Requires explicit store references | Automatically finds/creates stores |
| Used for token creation and advanced operations | Used for everyday token operations |

## Side-by-Side Examples

Let me show you concrete examples of the same operations using both modules:

### 1. Reading Token Metadata

Both modules can access metadata, but in different ways:

```move
// Using fungible_asset (requires metadata object)
public fun get_metadata_info_1(metadata: Object<Metadata>): (String, String, u8) {
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}

// Using primary_fungible_store (same approach, it doesn't add abstraction for metadata)
public fun get_metadata_info_2<T: key>(metadata_address: address): (String, String, u8) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    // Still uses fungible_asset for metadata access
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}
```

### 2. Transferring Tokens

This is where we see a major difference in how the modules operate:

```move
// Using fungible_asset (requires explicit store objects and transfer_ref)
public fun transfer_tokens_1(
    from_store: Object<FungibleStore>,
    to_store: Object<FungibleStore>,
    amount: u64,
    transfer_ref: &TransferRef
) {
    // First withdraw from source store
    let fa = fungible_asset::withdraw_with_ref(
        transfer_ref,
        from_store,
        amount
    );
    
    // Then deposit to destination store
    fungible_asset::deposit_with_ref(
        transfer_ref,
        to_store,
        fa
    );
}

// Using primary_fungible_store (just need accounts and metadata)
public fun transfer_tokens_2(
    sender: &signer,
    metadata: Object<Metadata>,
    recipient: address,
    amount: u64
) {
    // One simple call handles everything:
    // - Finding sender's store
    // - Creating recipient's store if needed
    // - Withdrawing tokens
    // - Depositing tokens
    primary_fungible_store::transfer(
        sender,
        metadata,
        recipient,
        amount
    );
}
```

### 3. Checking a Balance

```move
// Using fungible_asset (requires store object)
public fun check_balance_1(store: Object<FungibleStore>): u64 {
    fungible_asset::balance(store)
}

// Using primary_fungible_store (just need account and metadata)
public fun check_balance_2(account: address, metadata: Object<Metadata>): u64 {
    primary_fungible_store::balance(account, metadata)
}
```

### 4. Withdrawing Tokens

```move
// Using fungible_asset (needs store and transfer_ref)
public fun withdraw_tokens_1(
    store: Object<FungibleStore>,
    amount: u64,
    transfer_ref: &TransferRef
): FungibleAsset {
    fungible_asset::withdraw_with_ref(
        transfer_ref,
        store,
        amount
    )
}

// Using primary_fungible_store (just needs owner and metadata)
public fun withdraw_tokens_2(
    owner: &signer,
    metadata: Object<Metadata>,
    amount: u64
): FungibleAsset {
    primary_fungible_store::withdraw(
        owner,
        metadata,
        amount
    )
}
```

### 5. Creating a Token (Only with fungible_asset)

This operation can only be done with `fungible_asset`:

```move
public fun create_token(
    creator: &signer,
    maximum_supply: Option<u128>,
    name: String,
    symbol: String,
    decimals: u8,
    icon_uri: String,
    project_uri: String
): (Object<Metadata>, MintRef, TransferRef, BurnRef) {
    // Create object
    let constructor_ref = object::create_named_object(creator, b"MY_TOKEN");
    
    // Initialize metadata
    fungible_asset::create_metadata(
        &constructor_ref,
        name,
        symbol,
        decimals,
        icon_uri,
        project_uri
    );
    
    // Configure for primary store usage
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        &constructor_ref,
        maximum_supply,
        name,
        symbol,
        decimals,
        icon_uri,
        project_uri
    );
    
    // Generate capability references
    let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
    
    // Return metadata object and capability references
    (object::object_from_constructor_ref<Metadata>(&constructor_ref), 
     mint_ref, transfer_ref, burn_ref)
}
```

## When to Use Each Module

### Use `fungible_asset` when:
1. **Creating tokens**: Initial setup, generating capability references
2. **Advanced use cases**: Working with multiple stores per user
3. **Direct store manipulation**: When you have store objects directly
4. **Custom token logic**: Implementing hooks via AIP-73

### Use `primary_fungible_store` when:
1. **Standard user operations**: Transfers, deposits, withdrawals
2. **DApp integration**: Simpler interfaces for common operations
3. **Account-level operations**: Working with user addresses, not stores
4. **Automatic store management**: Want stores to be created as needed

## Practical Example: Creating and Using a Token

```move
// Module that creates and manages a token
module example::my_token {
    use std::string;
    use std::signer;
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset, MintRef, TransferRef, BurnRef};
    use aptos_framework::primary_fungible_store;
    
    // Resources to store capability references
    struct TokenAdmin has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }
    
    // Store metadata object address for easy reference
    struct TokenInfo has key {
        metadata: Object<Metadata>,
    }
    
    // Initialize the token (using fungible_asset)
    public entry fun initialize(admin: &signer) {
        let constructor_ref = object::create_named_object(admin, b"MY_TOKEN");
        
        // Create metadata and enable primary store
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::some(1000000000), // 1 billion max supply
            string::utf8(b"My Token"),
            string::utf8(b"MTK"),
            8, // 8 decimals
            string::utf8(b"https://example.com/icon.png"),
            string::utf8(b"https://example.com")
        );
        
        // Generate references using fungible_asset
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        
        let metadata = object::object_from_constructor_ref<Metadata>(&constructor_ref);
        
        // Store references for admin use
        move_to(admin, TokenAdmin { 
            mint_ref, 
            burn_ref, 
            transfer_ref 
        });
        
        // Store metadata info for easy access
        move_to(admin, TokenInfo {
            metadata
        });
    }
    
    // Mint tokens (admin only, using fungible_asset)
    public entry fun mint(
        admin: &signer,
        recipient: address,
        amount: u64
    ) acquires TokenAdmin {
        // Get mint reference
        let admin_addr = signer::address_of(admin);
        let token_admin = borrow_global<TokenAdmin>(admin_addr);
        
        // Mint tokens using fungible_asset
        let tokens = fungible_asset::mint(&token_admin.mint_ref, amount);
        
        // Deposit to recipient using primary_fungible_store
        primary_fungible_store::deposit(recipient, tokens);
    }
    
    // Transfer tokens (user operation, using primary_fungible_store)
    public entry fun transfer(
        sender: &signer,
        recipient: address,
        amount: u64
    ) acquires TokenInfo {
        // Get metadata
        let token_info = borrow_global<TokenInfo>(@example);
        
        // Transfer using primary_fungible_store (simpler API)
        primary_fungible_store::transfer(
            sender,
            token_info.metadata,
            recipient,
            amount
        );
    }
    
    // Freeze an account (admin only, direct use of transfer_ref)
    public entry fun freeze_account(
        admin: &signer,
        account: address
    ) acquires TokenAdmin, TokenInfo {
        let admin_addr = signer::address_of(admin);
        let token_admin = borrow_global<TokenAdmin>(admin_addr);
        let token_info = borrow_global<TokenInfo>(@example);
        
        // Get the user's store
        let store = primary_fungible_store::ensure_primary_store_exists(
            account,
            token_info.metadata
        );
        
        // Freeze using fungible_asset (requires store and transfer_ref)
        fungible_asset::set_frozen_flag(&token_admin.transfer_ref, store, true);
    }
}
```

This distinction is crucial for building applications on Aptos:
- `fungible_asset` gives you direct control but requires more parameters
- `primary_fungible_store` simplifies common operations by handling store management automatically

