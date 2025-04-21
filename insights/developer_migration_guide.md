# Developer Migration Guide

This guide captures key insights from Eman's study notes about the transition from other blockchain ecosystems to Aptos.

## Effective Learning Approach

Based on Eman's follow-up interview, we've identified an effective learning process for experienced blockchain developers:

### 1. Theory-First, Implementation-Second Approach

**Quote from Eman**:
> "I'm kind of person who love to understand the theory, the theoretical part. So whenever I'm stuck, I know exactly what I'm doing. I cannot like kind of having a black box."

This approach involves:
- First understanding Move's core concepts and type system
- Learning about Aptos's account-centric model
- Understanding resource abilities and storage operations
- Then implementing practical examples

### 2. Contract Migration as a Learning Tool

**Learning Pattern**:
Eman found it effective to:
1. Take an existing Solidity contract she was familiar with
2. Identify the core components (state variables, events, functions)
3. Systematically translate each component to Move
4. Use AI assistance when encountering errors, but verify solutions

**Example Migration Workflow**:
```
1. Identify contract state variables → Map to Move resources
2. Convert events → Create Move event structs
3. Map constructor → Create init_module function
4. Convert functions → Create entry and public functions
5. Test and debug incrementally
```

### 3. Debugging with AI Assistance

When encountering errors:
1. First try to understand the root cause based on theoretical knowledge
2. If stuck, copy the error and code to an AI assistant
3. Evaluate the suggested solution against your understanding
4. Apply the fix and verify it works
5. Learn from the pattern for future reference

## For EVM (Ethereum) Developers

### Mental Model Shifts

| Concept | Ethereum (Solidity) | Aptos (Move) | Key Insight |
|---------|----------|------|-------------|
| **Storage Paradigm** | Contract-based storage | Account-centric storage | Data lives in user accounts, not contracts |
| **Ownership Model** | Tracked via mappings | Direct resource placement | NFTs stored directly in user accounts |
| **Caller Identity** | `msg.sender` | `&signer` parameter | Explicit authorization via signer reference |
| **Visibility Default** | Public by default | Private by default | More secure by requiring explicit exposure |
| **Function Calls** | Dynamic dispatch | Static dispatch | More predictable behavior and security |
| **Upgradeability** | Proxy patterns | Direct module upgrades | Simpler upgradeability without proxies |
| **Token Standards** | Each token is its own contract | Typed `Coin` or `FungibleAsset` | Uniform interface for all tokens |

### Code Pattern Translations

#### Contract Structure
```solidity
// Solidity
contract MyContract {
    // Contract code...
}
```

```move
// Move
module my_address::my_module {
    // Module code...
}
```

#### Data Storage
```solidity
// Solidity
contract NFTContract {
    mapping(uint256 => address) private _owners;
    
    function ownerOf(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }
}
```

```move
// Move
module my_address::nft {
    struct NFT has key {
        id: u64,
        // other fields
    }
    
    // NFT is stored directly in user's account
    // No need for ownership mapping
}
```

#### Event Emission
```solidity
// Solidity
event Transfer(address indexed from, address indexed to, uint256 value);

function transfer(address to, uint256 amount) external {
    // ... logic
    emit Transfer(msg.sender, to, amount);
}
```

```move
// Move
#[event]
struct Transfer has drop, store {
    from: address,
    to: address,
    amount: u64,
}

public fun transfer(from: &signer, to: address, amount: u64) {
    // ... logic
    event::emit(Transfer {
        from: signer::address_of(from),
        to,
        amount,
    });
}
```

## For Solana Developers

### Mental Model Shifts

| Concept | Solana (Rust) | Aptos (Move) | Key Insight |
|---------|----------|------|-------------|
| **Account Model** | Account-based | Account-based | Similar model but different programming paradigm |
| **Programming Paradigm** | Instruction-based | Resource-oriented | Emphasis on resources with ownership semantics |
| **Authentication** | Program-derived addresses (PDAs) | Resources with abilities | Type-based security rather than address derivation |
| **State Management** | Account data serialization | Typed resources | More explicit type safety in Move |
| **Transaction Handling** | Single-instruction transactions | Flexible transaction scripts | More composable transaction model |

### Code Pattern Translations

#### Account Creation
```rust
// Solana
let (pda, bump_seed) = Pubkey::find_program_address(
    &[b"my_seed", authority.key().as_ref()],
    program_id
);
```

```move
// Move
// Resources are stored directly in accounts
// No need for PDA derivation in the same way
struct MyResource has key {
    data: u64,
}

public fun create_resource(account: &signer, data: u64) {
    move_to(account, MyResource { data });
}
```

#### Data Access
```rust
// Solana
let account_info = next_account_info(account_info_iter)?;
let data = MyAccount::try_from_slice(&account_info.data.borrow())?;
```

```move
// Move
public fun get_data(addr: address): u64 acquires MyResource {
    borrow_global<MyResource>(addr).data
}
```

## Common Development Challenges

Based on Eman's feedback, be aware of these common challenges when developing on Aptos:

### 1. CLI Ambiguities

**Issue**: CLI output can be ambiguous with empty result arrays:
```
BUILDING aptos_fighters { "Result": [] }
```

This doesn't clearly indicate success or failure.

**Workaround**: Check for error messages, and verify file structure manually when in doubt.

### 2. Dependency Management

**Issue**: Dependency conflicts between packages and Aptos Framework versions:
```
"Error": "Move compilation failed: Unable to resolve packages for package 'aptos_fighters':
While resolving dependency 'Pyth' in package 'aptos_fighters':
Unable to resolve package dependency 'Pyth':
While resolving dependency 'AptosFramework' in package 'Pyth':
Failed to fetch to latest Git state for package 'AptosFramework'
```

**Workaround**: 
- Use the exact commit hash from dependency projects
- Consider removing duplicate framework imports
- When integrating Pyth Oracle, use their specified Aptos Framework version

### 3. Testing Behavior

**Issue**: Tests may appear to pass despite syntax errors.

**Workaround**: Verify compilation success separately from test outcomes.

## Tips For All Developers

1. **Understand Resources**: The most important concept in Move is resources with abilities (key, store, drop, copy)

2. **Think Account-First**: Design your application with resources stored in accounts, not contract storage

3. **Use Aptos SDK**: Leverage the TypeScript SDK for frontend integration

4. **Leverage Native Features**: Take advantage of protocol-level features like multisig and randomness

5. **Test with Move Test Framework**: Use the built-in testing capabilities rather than external test frameworks

6. **Adapt to Different Error Handling**: Move uses error codes instead of strings for more efficient error handling

7. **Learn Storage Operations**: Understand the five key storage operations: `move_to`, `move_from`, `borrow_global`, `borrow_global_mut`, and `exists`

8. **Start with Migration**: If you're experienced with other chains, start by migrating a familiar contract to learn Move patterns