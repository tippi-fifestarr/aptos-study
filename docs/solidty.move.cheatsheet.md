# Solidity to Move Cheatsheet

## Core Concepts Comparison

| Concept | Solidity | Move | Notes |
|---------|----------|------|-------|
| Project Structure | Contract | Module | Move modules are owned by accounts |
| Project Config | foundry.toml/hardhat.config.ts | Move.toml | Defines dependencies and named addresses |
| Development Setup | Foundry, Hardhat | Aptos CLI | Aptos CLI offers similar features to Foundry/Hardhat |
| Storage | Contract state variables | Resources & Objects | Resources are tied to accounts directly |
| Ownership | Owned by contract | Owned by account or object | Move uses account-centric storage |
| Initialization | Constructor | init_module | Move doesn't have constructors |
| Visibility | public by default | private by default | Move requires explicit public declarations |
| Interfaces | Interface contracts | friend modules | Less inheritance, more composition in Move |
| Caller Identity | msg.sender | &signer parameter | Signer provides authorization |
| Events | event keyword | #[event] struct | Events are structs in Move |
| Error Handling | require, assert, revert | assert! macro | Move uses error codes, not strings |
| Testing | Foundry/Hardhat tests | Built-in testing | Move has inline test functions |
| Gas Management | Careful loops | Resource separation | Store user data in individual accounts |
| Upgradeability | Proxy patterns | Manual migration | Move doesn't have built-in upgradeability |

## Syntax Comparison

### Project Structure

**Solidity**
```solidity
pragma solidity ^0.8.20;

contract Billboard {
    // Contract code...
}
```

**Move**
```rust
module billboard_address::billboard {
    // Module code...
}
```

### Configuration

**Solidity - Hardhat** (hardhat.config.ts)
```typescript
export default {
  solidity: "0.8.20",
  networks: {
    hardhat: {},
    mainnet: {
      url: process.env.MAINNET_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
```

**Solidity - Foundry** (foundry.toml)
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.20"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

**Move** (Move.toml)
```toml
[package]
name = "billboard"
version = "1.0.0"

[addresses]
billboard_address = "0x894baff8a384e27b60bcc7aa7dd2135111626c217f516899c64f41357f5b3d39"

[dependencies.AptosFramework]
git = "https://github.com/aptos-labs/aptos-framework"
rev = "mainnet"
subdir = "aptos-move/framework/aptos-framework"
```

### Initialization

**Solidity**
```solidity
constructor(address owner_) {
    transferOwnership(owner_);
}
```

**Move**
```rust
fun init_module(owner: &signer) {
    move_to(owner, Billboard { messages: vector[], oldest_index: 0 })
}
```
> notes about using acquires in move from Claude 
```txt
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


```
### Functions

**Solidity**
```solidity
// External function
function addMessage(string memory messageText_) external {
    // Function code...
}

// View function
function getMessages() external view returns (Message[] memory) {
    // Function code...
}
```

**Move**
```rust
// Entry function (callable via transactions)
public entry fun add_message(sender: &signer, message: String) acquires Billboard {
    // Function code...
}

// View function
#[view]
public fun get_messages(): vector<Message> acquires Billboard {
    // Function code...
}
```

### Data Types

**Solidity**
```solidity
address public owner;
uint256 public counter;
string public message;
bool public flag;
bytes public data;
```

**Move**
```rust
// These would be in resource structs, not global variables
address: address;  // 256-bit value prefixed with @ when used as literals
counter: u64;      // Move has u8, u16, u32, u64, u128, u256
message: String;   // From std::string module
flag: bool;
data: vector<u8>;  // Byte arrays
```

### Structs & Resources

**Solidity**
```solidity
struct Message {
    address sender;
    string message;
    uint256 addedAt;
}

mapping(uint256 => Message) private messages;
```

**Move**
```rust
struct Message has store, drop {
    sender: address,
    message: String,
    added_at: u64
}

// Resource (stored on-chain)
struct Billboard has key {
    messages: vector<Message>,
    oldest_index: u64
}
```

### Events

**Solidity**
```solidity
event MessageAdded(address sender, string message, uint256 addedAt);

function addMessage(string memory message_) external {
    // ...
    emit MessageAdded(msg.sender, message_, block.timestamp);
}
```

**Move**
```rust
#[event]
struct AddedMessage has drop, store {
    sender: address,
    message: String,
    added_at: u64
}

public entry fun add_message(sender: &signer, message: String) acquires Billboard {
    // ...
    event::emit(AddedMessage {
        sender: signer::address_of(sender),
        message,
        added_at: timestamp::now_seconds()
    });
}
```

### Error Handling

**Solidity**
```solidity
function onlyOwner() external {
    require(msg.sender == owner, "Not owner");
    // ...
}
```

**Move**
```rust
const ENOT_OWNER: u64 = 1;

public entry fun only_owner(owner: &signer) {
    assert!(signer::address_of(owner) == @owner_address, 
            error::permission_denied(ENOT_OWNER));
    // ...
}
```

### Owner Checks

**Solidity**
```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
}

function sensitiveFunction() external onlyOwner {
    // ...
}
```

**Move**
```rust
fun only_owner(owner: &signer) {
    assert!(signer::address_of(owner) == @module_address, 1);
}

public entry fun sensitive_function(owner: &signer) {
    only_owner(owner);
    // ...
}
```

## Object System in Move

### Object Creation

**Solidity** (ERC-721 NFT)
```solidity
function mintNFT(address recipient) public {
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _mint(recipient, newItemId);
    // ...
}
```

**Move** (Token Object)
```rust
public fun mint_token(
    owner: &signer,
    token_name: String,
    token_description: String,
    token_uri: String
) {
    let sell_token_ctor = token::create_named_token(
        owner,
        collection_name,
        token_description,
        token_name,
        option::none(),
        token_uri,
    );
    // ...
}
```

### Accessing Objects

**Solidity**
```solidity
function getAuction(uint256 nftId_) external view returns (Auction memory) {
    return _auctions[nftId_];
}
```

**Move**
```rust
#[view]
public fun get_auction(auction_object: Object<Auction>): Auction acquires Auction {
    let auction_address = object::object_address(&auction_object);
    let auction = borrow_global<Auction>(auction_address);
    // ...
}
```

## Global Storage Operations

### Move Storage Operations

| Operation | Description | Usage |
|-----------|-------------|-------|
| `move_to<T>(&signer, T)` | Publish a resource under signer's address | Create resources |
| `move_from<T>(address)` | Remove and return a resource | Remove resources |
| `borrow_global_mut<T>(address)` | Get mutable reference to a resource | Modify resources |
| `borrow_global<T>(address)` | Get immutable reference to a resource | Read resources |
| `exists<T>(address)` | Check if a resource exists | Verify existence |

### Solidity Storage Access (Foundry Cheatcodes)

In Foundry, you can directly manipulate storage for testing using cheatcodes:

```solidity
// Access and modify contract storage in tests
contract StorageTest is Test {
    MyContract target;
    
    function setUp() public {
        target = new MyContract();
    }
    
    function testStorage() public {
        // Read a storage slot
        uint256 value = uint256(vm.load(address(target), bytes32(uint256(0))));
        
        // Write to a storage slot
        vm.store(address(target), bytes32(uint256(0)), bytes32(uint256(123)));
        
        // For mappings, compute the slot
        bytes32 mappingSlot = keccak256(abi.encode(address(0x123), uint256(1)));
        vm.store(address(target), mappingSlot, bytes32(uint256(456)));
    }
}
```

## Resource/Object Abilities

| Ability | Purpose | Example Use Case |
|---------|---------|-----------------|
| `key` | Allow storage in global space | Basic requirement for resources |
| `store` | Allow storing inside other resources | For nested data structures |
| `drop` | Allow implicit deletion | For temporary data |
| `copy` | Allow implicit copying | For data that needs duplication |

## Working with Objects

1. **Create an Object**:
   ```rust
   let constructor_ref = object::create_named_object(owner, seed);
   let object_signer = object::generate_signer(&constructor_ref);
   ```

2. **Store Resources in an Object**:
   ```rust
   move_to(&object_signer, MyResource { /* fields */ });
   ```

3. **Create Permission References**:
   ```rust
   let transfer_ref = object::generate_transfer_ref(&constructor_ref);
   ```

4. **Access Resources from an Object**:
   ```rust
   let resource_address = object::object_address(&my_object);
   let resource = borrow_global<MyResource>(resource_address);
   ```

5. **Transfer an Object**:
   ```rust
   let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
   object::transfer_with_ref(linear_transfer_ref, recipient_address);
   ```

## Development Workflow Comparison

| Task | Solidity (Hardhat) | Solidity (Foundry) | Move (Aptos CLI) |
|------|-------------------|-------------------|-----------------|
| Create Project | `npx hardhat init` | `forge init my_project` | `aptos move init --name my_project` |
| Build | `npx hardhat compile` | `forge build` | `aptos move compile` |
| Test | `npx hardhat test` | `forge test` | `aptos move test` |
| Deploy | `npx hardhat run scripts/deploy.js` | `forge script Deploy --rpc-url $RPC --private-key $PK` | `aptos move publish --named-addresses my_addr=$ADDR` |
| Interact | `npx hardhat run scripts/interact.js` | `cast send $CONTRACT "func()" --rpc-url $RPC --private-key $PK` | `aptos move run --function-id $ADDR::module::function` |
| Local Node | `npx hardhat node` | `anvil` | `aptos node run-local-testnet` |
| Documentation | Natspec comments | Natspec comments | /// doc comments |
| Gas Optimization | `npx hardhat test --gas-report` | `forge snapshot` | Manual resource management |
| Contract Verification | `npx hardhat verify` | `forge verify-contract` | No direct equivalent (on-chain bytecode is source) |
| Console Output | `console.log()` | `emit log` cheatcode | N/A (use events instead) |

## Billboard

### Solidity Implementation
```solidity 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Billboard is Ownable {
    uint256 public constant MAX_MESSAGES = 5;

    struct BillboardStorage {
        Message[] messages;
        uint256 oldestIndex;
    }

    struct Message {
        address sender;
        string message;
        uint256 addedAt;
    }

    BillboardStorage private _billboard;

    event MessageAdded(address sender, string message, uint256 addedAt);

    constructor(address owner_) {
        transferOwnership(owner_);
    }

    function addMessage(string memory messageText_) external {
        Message memory message_ = Message({
            sender: msg.sender,
            message: messageText_,
            addedAt: block.timestamp
        });

        emit MessageAdded(message_.sender, message_.message, message_.addedAt);

        if (_billboard.messages.length < MAX_MESSAGES) {
            _billboard.messages.push(message_);
            return;
        }

        _billboard.messages[_billboard.oldestIndex] = message_;
        _billboard.oldestIndex = (_billboard.oldestIndex + 1) % MAX_MESSAGES;
    }

    function clear() external onlyOwner {
        delete _billboard;
    }

    function getMessages() external view returns (Message[] memory) {
        Message[] memory messages_ = _billboard.messages;

        _sort(messages_, _billboard.oldestIndex);

        return messages_;
    }

    function _sort(Message[] memory messages_, uint256 oldestIndex_) private pure {
        _reverseSlice(messages_, 0, oldestIndex_);
        _reverseSlice(messages_, oldestIndex_, messages_.length);
        _reverseSlice(messages_, 0, messages_.length);
    }

    function _reverseSlice(Message[] memory messages_, uint256 left_, uint256 right_) private pure {
        while (left_ + 1 < right_) {
            (messages_[left_], messages_[right_ - 1]) = (messages_[right_ - 1], messages_[left_]);
            ++left_;
            --right_;
        }
    }
}
```
### Move Implementation

```rust
module billboard_address::billboard {
    use std::error;
    use std::signer;
    use std::string::{String};
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    const ENOT_OWNER: u64 = 1;

    const MAX_MESSAGES: u64 = 5;

    struct Billboard has key {
        messages: vector<Message>,
        oldest_index: u64
    }

    struct Message has store, copy, drop {
        sender: address,
        message: String,
        added_at: u64
    }

    #[event]
    struct AddedMessage has drop, store {
        sender: address,
        message: String,
        added_at: u64
    }

    fun init_module(owner: &signer) {
        move_to(owner, Billboard { messages: vector[], oldest_index: 0 })
    }

    public entry fun add_message(sender: &signer, message: String) acquires Billboard {
        let message = Message {
            sender: signer::address_of(sender),
            message,
            added_at: timestamp::now_seconds()
        };

        event::emit(AddedMessage {
            sender: message.sender,
            message: message.message,
            added_at: message.added_at
        });

        let billboard = borrow_global_mut<Billboard>(@billboard_address);

        if (vector::length(&billboard.messages) < MAX_MESSAGES) {
            vector::push_back(&mut billboard.messages, message);
            return
        };

        *vector::borrow_mut(&mut billboard.messages, billboard.oldest_index) = message;
        billboard.oldest_index = (billboard.oldest_index + 1) % MAX_MESSAGES;
    }

    public entry fun clear(owner: &signer) acquires Billboard {
        only_owner(owner);

        let billboard = borrow_global_mut<Billboard>(@billboard_address);

        billboard.messages = vector[];
        billboard.oldest_index = 0;
    }

    inline fun only_owner(owner: &signer) {
        assert!(signer::address_of(owner) == @billboard_address, error::permission_denied(ENOT_OWNER));
    }

    #[view]
    public fun get_messages(): vector<Message> acquires Billboard {
        let billboard = borrow_global<Billboard>(@billboard_address);

        let messages = vector[];
        vector::for_each(billboard.messages, |m| vector::push_back(&mut messages, m));

        vector::rotate(&mut messages, billboard.oldest_index);

        messages
    }

    #[test(aptos_framework = @std, owner = @billboard_address, alice = @0x1234, bob = @0xb0b)]
    fun test_billboard_happy_path(
        aptos_framework: &signer,
        owner: &signer,
        alice: &signer,
        bob: &signer
    ) acquires Billboard {
        use std::string;

        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(1000);

        init_module(owner);

        let msgs = get_messages();

        assert!(vector::length(&msgs) == 0, 1);

        let alice_message = string::utf8(b"alice's message");
        let bob_message = string::utf8(b"bob's message");

        add_message(alice, alice_message);
        add_message(bob, bob_message);

        msgs = get_messages();

        assert!(vector::length(&msgs) == 2, 1);

        assert!(vector::borrow(&msgs, 0).message == alice_message, 1);
        assert!(vector::borrow(&msgs, 0).sender == signer::address_of(alice), 1);

        assert!(vector::borrow(&msgs, 1).message == bob_message, 1);
        assert!(vector::borrow(&msgs, 1).sender == signer::address_of(bob), 1);

        add_message(alice, alice_message);
        add_message(alice, alice_message);
        add_message(alice, alice_message);
        add_message(alice, alice_message);

        msgs = get_messages();

        assert!(vector::length(&msgs) == 5, 1);

        assert!(vector::borrow(&msgs, 0).message == bob_message, 1);
        assert!(vector::borrow(&msgs, 0).sender == signer::address_of(bob), 1);

        msgs = get_messages();

        assert!(vector::length(&msgs) == 5, 1);

        assert!(vector::borrow(&msgs, 0).message == bob_message, 1);
        assert!(vector::borrow(&msgs, 0).sender == signer::address_of(bob), 1);

        clear(owner);

        msgs = get_messages();

        assert!(vector::length(&msgs) == 0, 1);
    }
}
```

## Dutch Auction 

### Solidity Implementation

```solidity
contract DutchAuction is ERC721, Ownable {
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DutchAuction is ERC721, Ownable {
    // Constants
    string private constant DUTCH_AUCTION_COLLECTION_NAME = "Dutch Auction Collection";
    string private constant DUTCH_AUCTION_COLLECTION_SYMBOL = "DAC";
    string private constant DUTCH_AUCTION_COLLECTION_URI = "https://example.com/api/token/";

    // Auction data structure
    struct Auction {
        IERC20 buyToken;     // ERC20 token used for bidding
        uint256 maxPrice;    // Starting price
        uint256 minPrice;    // Minimum price if auction ends without bids
        uint256 duration;    // Duration in seconds
        uint256 startedAt;   // Timestamp when auction started
    }

    // Maps NFT IDs to auctions
    mapping(uint256 => Auction) private _auctions;

    // Events
    event AuctionCreated(uint256 nftId);
    event AuctionBid(uint256 nftId, address bidder, uint256 price);

    constructor() ERC721(DUTCH_AUCTION_COLLECTION_NAME, DUTCH_AUCTION_COLLECTION_SYMBOL) Ownable(msg.sender) {}

    /**
     * @dev Start a new auction for an NFT
     * @param nftId_ ID of the NFT to auction
     * @param buyToken_ ERC20 token used for bidding
     * @param maxPrice_ Starting price
     * @param minPrice_ Ending price (if no bids)
     * @param duration_ Duration in seconds
     */
    function startAuction(
        uint256 nftId_,
        IERC20 buyToken_,
        uint256 maxPrice_,
        uint256 minPrice_,
        uint256 duration_
    ) external onlyOwner {
        require(maxPrice_ >= minPrice_, "DutchAuction: invalid prices");
        require(duration_ > 0, "DutchAuction: zero duration");

        // Mint NFT to the contract
        _mint(address(this), nftId_);

        // Create auction
        _auctions[nftId_] = Auction(
            buyToken_,
            maxPrice_,
            minPrice_,
            duration_,
            block.timestamp
        );

        emit AuctionCreated(nftId_);
    }

    /**
     * @dev Bid on an auction at the current price
     * @param nftId_ ID of the NFT to bid on
     */
    function bid(uint256 nftId_) external {
        require(ownerOf(nftId_) == address(this), "DutchAuction: invalid auction");

        Auction memory auction_ = _auctions[nftId_];
        uint256 price_ = _calculateCurrentPrice(auction_);

        // Transfer NFT to bidder
        transferFrom(address(this), msg.sender, nftId_);
        
        // Transfer tokens from bidder to contract owner
        auction_.buyToken.transferFrom(msg.sender, owner(), price_);

        emit AuctionBid(nftId_, msg.sender, price_);
    }

    /**
     * @dev Get auction details
     * @param nftId_ ID of the NFT
     * @return Auction data
     */
    function getAuction(uint256 nftId_) external view returns (Auction memory) {
        return _auctions[nftId_];
    }

    /**
     * @dev Get current price of an auction
     * @param nftId_ ID of the NFT
     * @return Current price
     */
    function getCurrentPrice(uint256 nftId_) external view returns (uint256) {
        Auction memory auction_ = _auctions[nftId_];
        return _calculateCurrentPrice(auction_);
    }

    /**
     * @dev Calculate current price based on time elapsed
     * @param auction_ Auction to calculate price for
     * @return Current price
     */
    function _calculateCurrentPrice(Auction memory auction_) internal view returns (uint256) {
        require(
            block.timestamp <= auction_.startedAt + auction_.duration,
            "DutchAuction: auction ended"
        );

        uint256 timePassed_ = block.timestamp - auction_.startedAt;
        uint256 discount_ = ((auction_.maxPrice - auction_.minPrice) * timePassed_) /
            auction_.duration;

        return auction_.maxPrice - discount_;
    }

    /**
     * @dev Override base URI
     */
    function _baseURI() internal pure override returns (string memory) {
        return DUTCH_AUCTION_COLLECTION_URI;
    }
}
```

### Move Implementation

```rust
module dutch_auction_address::dutch_auction {
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
    
    // Error constants
    const ENOT_OWNER: u64 = 1;
    const EINVALID_PRICES: u64 = 2;
    const EINVALID_DURATION: u64 = 3;
    const EOUTDATED_AUCTION: u64 = 4;
    const ETOKEN_SOLD: u64 = 5;
    
    // Collection constants
    const DUTCH_AUCTION_COLLECTION_NAME: vector<u8> = b"Dutch Auction Collection";
    const DUTCH_AUCTION_COLLECTION_DESCRIPTION: vector<u8> = b"A collection of NFTs for Dutch Auctions";
    const DUTCH_AUCTION_COLLECTION_URI: vector<u8> = b"https://example.com/collection";
    const DUTCH_AUCTION_SEED_PREFIX: vector<u8> = b"DUTCH_AUCTION";
    
    // Auction resource struct
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Auction has key {
        sell_token: Object<Token>,         // NFT token being sold
        buy_token: Object<Metadata>,       // Fungible token used for bidding
        max_price: u64,                    // Starting price
        min_price: u64,                    // Minimum price if auction ends without bids
        duration: u64,                     // Duration in seconds
        started_at: u64                    // Timestamp when auction started
    }
    
    // Token configuration resource struct
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenConfig has key {
        transfer_ref: TransferRef         // Reference allowing token transfer
    }
    
    // Event for auction creation
    #[event]
    struct AuctionCreated has drop, store {
        auction: Object<Auction>
    }
    
    // Event for successful bid
    #[event]
    struct AuctionBid has drop, store {
        auction: Object<Auction>,
        bidder: address,
        price: u64
    }
    
    // Initialize module - create the NFT collection
    fun init_module(creator: &signer) {
        let description = string::utf8(DUTCH_AUCTION_COLLECTION_DESCRIPTION);
        let name = string::utf8(DUTCH_AUCTION_COLLECTION_NAME);
        let uri = string::utf8(DUTCH_AUCTION_COLLECTION_URI);
        
        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }
    
    // Helper function to verify owner
    inline fun only_owner(owner: &signer) {
        assert!(
            signer::address_of(owner) == @dutch_auction_address,
            error::permission_denied(ENOT_OWNER)
        );
    }
    
    // Start a new auction
    public entry fun start_auction(
        owner: &signer,
        token_name: String,
        token_description: String,
        token_uri: String,
        buy_token: Object<Metadata>,
        max_price: u64,
        min_price: u64,
        duration: u64
    ) {
        only_owner(owner);
        
        assert!(max_price >= min_price, error::invalid_argument(EINVALID_PRICES));
        assert!(duration > 0, error::invalid_argument(EINVALID_DURATION));
        
        let collection_name = string::utf8(DUTCH_AUCTION_COLLECTION_NAME);
        
        // Create the NFT token
        let sell_token_ctor = token::create_named_token(
            owner,
            collection_name,
            token_description,
            token_name,
            option::none(),
            token_uri,
        );
        let transfer_ref = object::generate_transfer_ref(&sell_token_ctor);
        let sell_token = object::object_from_constructor_ref<Token>(&sell_token_ctor);
        
        // Create the auction with necessary parameters
        let auction = Auction {
            sell_token,
            buy_token,
            max_price,
            min_price,
            duration,
            started_at: timestamp::now_seconds()
        };
        
        // Create and initialize auction object
        let auction_seed = get_auction_seed(token_name);
        let auction_ctor = object::create_named_object(owner, auction_seed);
        let auction_signer = object::generate_signer(&auction_ctor);
        
        move_to(&auction_signer, auction);
        move_to(&auction_signer, TokenConfig { transfer_ref });
        
        let auction = object::object_from_constructor_ref<Auction>(&auction_ctor);
        
        event::emit(AuctionCreated { auction });
    }
    
    // Place a bid on an auction
    public entry fun bid(
        customer: &signer,
        auction: Object<Auction>
    ) acquires Auction, TokenConfig {
        let auction_address = object::object_address(&auction);
        let auction_ref = borrow_global_mut<Auction>(auction_address);
        
        // Ensure auction is still active and token hasn't been sold
        assert!(exists<TokenConfig>(auction_address), error::unavailable(ETOKEN_SOLD));
        
        // Calculate current price
        let current_price = must_have_price(auction_ref);
        
        // Transfer tokens from bidder to auction owner
        primary_fungible_store::transfer(
            customer,
            auction_ref.buy_token,
            @dutch_auction_address,
            current_price
        );
        
        // Transfer NFT to bidder
        let transfer_ref = &borrow_global_mut<TokenConfig>(auction_address).transfer_ref;
        let linear_transfer_ref = object::generate_linear_transfer_ref(transfer_ref);
        
        object::transfer_with_ref(linear_transfer_ref, signer::address_of(customer));
        
        // Remove token config to prevent further transfers
        move_from<TokenConfig>(auction_address);
        
        event::emit(AuctionBid { 
            auction, 
            bidder: signer::address_of(customer),
            price: current_price
        });
    }
    
    // Calculate current price based on time elapsed
    fun must_have_price(auction: &Auction): u64 {
        let time_now = timestamp::now_seconds();
        
        assert!(
            time_now <= auction.started_at + auction.duration,
            error::unavailable(EOUTDATED_AUCTION)
        );
        
        let time_passed = time_now - auction.started_at;
        let discount = ((auction.max_price - auction.min_price) * time_passed)
            / auction.duration;
        
        auction.max_price - discount
    }
    
    // Helper function to construct auction seed
    fun get_auction_seed(token_name: String): vector<u8> {
        let token_seed = get_token_seed(token_name);
        
        let seed = DUTCH_AUCTION_SEED_PREFIX;
        vector::append(&mut seed, b"::");
        vector::append(&mut seed, token_seed);
        
        seed
    }
    
    // Helper function to get token seed
    fun get_token_seed(token_name: String): vector<u8> {
        let collection_name = string::utf8(DUTCH_AUCTION_COLLECTION_NAME);
        
        // Concatenates collection_name::token_name
        token::create_token_seed(&collection_name, &token_name)
    }
    
    // Helper function to get collection seed
    fun get_collection_seed(): vector<u8> {
        DUTCH_AUCTION_COLLECTION_NAME
    }
    
    // View functions for querying auction data
    
    #[view]
    public fun get_auction_object(token_name: String): Object<Auction> {
        let auction_seed = get_auction_seed(token_name);
        let auction_address = object::create_object_address(
            &@dutch_auction_address,
            auction_seed
        );
        
        object::address_to_object(auction_address)
    }
    
    #[view]
    public fun get_collection_object(): Object<Collection> {
        let collection_seed = get_collection_seed();
        let collection_address = object::create_object_address(
            &@dutch_auction_address,
            collection_seed
        );
        
        object::address_to_object(collection_address)
    }
    
    #[view]
    public fun get_token_object(token_name: String): Object<Token> {
        let token_seed = get_token_seed(token_name);
        let token_object = object::create_object_address(
            &@dutch_auction_address,
            token_seed
        );
        
        object::address_to_object<Token>(token_object)
    }
    
    #[view]
    public fun get_auction(auction_object: Object<Auction>): Auction acquires Auction {
        let auction_address = object::object_address(&auction_object);
        let auction = borrow_global<Auction>(auction_address);
        
        Auction {
            sell_token: auction.sell_token,
            buy_token: auction.buy_token,
            max_price: auction.max_price,
            min_price: auction.min_price,
            duration: auction.duration,
            started_at: auction.started_at
        }
    }
    
    #[view]
    public fun get_current_price(auction_object: Object<Auction>): u64 acquires Auction {
        let auction_address = object::object_address(&auction_object);
        let auction = borrow_global<Auction>(auction_address);
        
        // We wrap the calculation in a condition to avoid aborting in the view function
        if (timestamp::now_seconds() > auction.started_at + auction.duration) {
            auction.min_price
        } else {
            let time_passed = timestamp::now_seconds() - auction.started_at;
            let discount = ((auction.max_price - auction.min_price) * time_passed)
                / auction.duration;
            
            auction.max_price - discount
        }
    }
    
    #[view]
    public fun is_auction_active(auction_object: Object<Auction>): bool acquires Auction, TokenConfig {
        let auction_address = object::object_address(&auction_object);
        let auction = borrow_global<Auction>(auction_address);
        
        timestamp::now_seconds() <= auction.started_at + auction.duration 
            && exists<TokenConfig>(auction_address)
    }
}
```