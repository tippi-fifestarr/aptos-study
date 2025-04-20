
# Ethereum vs. Aptos 

## Account Models

| Feature | Ethereum | Aptos |
|---------|----------|-------|
| **Account Types** | Two types: Externally Owned Accounts (EOAs) and Contract Accounts | Single type: Accounts serve as containers for both code and data |
| **Address Length** | 160-bit (20 bytes) | 256-bit (32 bytes) |
| **Code Storage** | Contract accounts store code; EOAs do not | Any account can store code in the form of "modules" |
| **Data Storage** | State stored in a key-value store | Data stored as typed "resources" under accounts |
| **Balance** | Direct field in account state | Stored as resources for each asset type |
| **Transaction Counter** | Nonce (tracks transactions paid for) | Sequence number (tracks transactions sent) |
| **Authentication** | EOAs: controlled by private keys<br>Contracts: controlled by code | Traditionally controlled by private keys<br>Account Abstraction: can use custom authentication logic |
| **Account Abstraction** | Separate proposal (EIP-4337) | Native feature in Aptos |

## Address Length Comparison

### Ethereum (160-bit)
- **Size**: 20 bytes, typically represented as a 40-character hex string (with 0x prefix)
- **Advantages**:
  - More compact representation (smaller storage footprint)
  - Lower gas costs for address manipulation
  - Established ecosystem with wide tooling support
  - Easier for humans to read and transcribe
- **Limitations**:
  - Theoretically more vulnerable to collision attacks (though still practically secure)
  - Less space for incorporating derived identification schemes

### Aptos (256-bit)
- **Size**: 32 bytes, typically represented as a 64-character hex string (with 0x prefix)
- **Advantages**:
  - Higher collision resistance (2^256 possible addresses vs 2^160)
  - Direct compatibility with modern cryptographic primitives (SHA-256, Ed25519)
  - Future-proof against quantum computing threats
  - Supports more complex derivation paths and account creation schemes
- **Limitations**:
  - Larger storage requirements
  - More difficult for humans to handle without truncation
  - Potentially higher computational overhead
| **Code Storage** | Contract accounts store code; EOAs do not | Any account can store code in the form of "modules" |
| **Data Storage** | State stored in a key-value store | Data stored as typed "resources" under accounts |
| **Balance** | Direct field in account state | Stored as resources for each asset type |
| **Transaction Counter** | Nonce (tracks transactions paid for) | Sequence number (tracks transactions sent) |
| **Authentication** | EOAs: controlled by private keys<br>Contracts: controlled by code | Traditionally controlled by private keys<br>Account Abstraction: can use custom authentication logic |
| **Account Abstraction** | Separate proposal (EIP-4337) | Native feature in Aptos |

## Account Abstraction Comparison

### What is Account Abstraction?
Account abstraction allows for customized transaction validation beyond simple cryptographic signatures, enabling features like social recovery, multi-signature requirements, and custom spending policies.

| Feature | Ethereum (EIP-4337) | Aptos Account Abstraction |
|---------|---------------------|---------------------------|
| **Implementation** | Add-on solution through a separate protocol | Native feature built into the core protocol |
| **Authentication** | Smart contract validates transactions | Move modules define custom authentication logic |
| **User Experience** | Requires special infrastructure (bundlers) | Seamless experience with standard transactions |
| **Simplicity** | Complex stack with multiple components | Direct implementation in the VM |
| **Gas Payment** | Can pay fees with any token | Similar flexibility in fee payment |
| **Recovery Options** | Programmable recovery logic | Fully customizable recovery mechanisms |
| **Account Creation** | Requires on-chain transaction | Supports both on-chain and deterministic derivation |


## Data Storage Models Comparison

### Storage on Ethereum
- Uses Patricia Merkle Trees as the core data structure
- Storage system consists of 4 trees:
  1. World State tree (one per blockchain, modified per block)
  2. Storage tree (per account, modified per block)
  3. Transaction tree (new tree per block)
  4. Receipt tree (new tree per block)

### Storage on Aptos (Move)
- Uses a simpler tree-shaped persistent global storage
- Structured as a forest of trees, each rooted at an account address
- In pseudocode:
```
struct GlobalStorage {
  resources: Map<(address, ResourceType), ResourceValue>
  modules: Map<(address, ModuleName), ModuleBytecode>
}
```
- Storage has two main components:
  1. **Resources storage**: Maps `(address, ResourceType)` pairs to resource values
  2. **Modules storage**: Maps `(address, ModuleName)` pairs to module bytecode
- Each account's data forms a tree that branches into specific modules and resources


## Contract-Level Storage in Ethereum

### Key Concepts
- In Ethereum, data is stored at the **contract level** in storage slots
- Each contract maintains its own state variables in dedicated storage
- For example, an ERC-721 NFT contract stores a mapping of token IDs to owner addresses
- The global state is a Patricia Merkle Tree of all contract states

### Example: NFT in Solidity
```solidity
contract MyNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Mapping from token ID to owner address
    // This mapping is inherently part of the ERC721 implementation
    // mapping(uint256 => address) private _owners; // In ERC721

    constructor() ERC721("MyNFT", "MNFT") {
        // code
    }

    function mintNFT(address recipient) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        // The _mint function updates the internal _owners mapping in ERC-721
        _mint(recipient, newItemId);

        return newItemId;
    }
}
```

### Characteristics
- Contract-centric approach
- Contract code and data are tightly coupled
- Ownership is tracked via mappings within contracts
- Each contract has a dedicated storage space addressed by slots
- Storage root is calculated from contract state using Patricia Merkle Tree

## Account-Centric Storage in Aptos (Move)

### Key Concepts
- In Aptos, data is stored at the **account level** in a unified global storage
- Storage is a forest of trees, with each account as a root
- Accounts act as "containers" for both modules (code) and resources (data)
- Resources are strongly typed data with ownership semantics
- Objects represent collections of resources at a specific address

### Example: NFT in Move
```move
module 0x1::my_module {
    use std::signer;
    use std::string;

    // Define a simple NFT resource
    struct NFT has key {
        id: u64,
        name: string::utf8("My NFT"),
    }
    
    // Create NFT and store it directly in the account
    public entry fun create_nft(account: &signer, id: u64, metadata: vector<u8>) {
        let nft = NFT { id, metadata };
        move_to(account, nft);
    }
}
```

### Characteristics
- Account-centric approach
- Clear separation between modules (code) and resources (data)
- Data ownership is directly tied to accounts
- Type system enforces data ownership rules
- Global storage operations (move_to, move_from, borrow_global) for accessing data


## Key Differences Between Storage Models

### Ethereum (Contract-Level)
- Storage organized by **contracts**
- Data ownership tracked in contract mappings
- Two account types: EOAs and Contract Accounts
- Contract inherits from standards like ERC-721
- State changes through contract function calls

### Aptos (Account-Centric)
- Storage organized by **accounts**
- Data ownership directly tied to account addresses
- Uniform account model (all accounts can hold both code and data)
- Objects with resources instead of inheritance
- State changes through global storage operations

### Practical Implications
- **Development Approach**: Ethereum focuses on contract design; Aptos focuses on resource and account management
- **Ownership Model**: Ethereum uses mappings for indirect ownership; Aptos uses direct resource placement
- **Composability**: Ethereum composes via contract calls; Aptos composes via typed resources
- **Data Access**: Ethereum requires contract methods; Aptos provides direct global storage operations
- **Security Model**: Ethereum secures via contract logic; Aptos secures via type system and ownership rules

## Structural Representation

### Ethereum Storage
```
World State
├── Contract Account 1
│   ├── Storage Slot 0: Value
│   ├── Storage Slot 1: Value
│   └── ...
├── Contract Account 2
│   ├── Storage Slot 0: Value
│   ├── Storage Slot 1: Value
│   └── ...
└── ...
```

### Aptos Storage
```
Global Storage
├── Account 1
│   ├── Module 1
│   │   └── Bytecode
│   ├── Module 2
│   │   └── Bytecode
│   ├── Resource 1
│   │   └── Value
│   └── Resource 2
│       └── Value
├── Account 2
│   ├── Module 1
│   │   └── Bytecode
│   └── Resource 1
│       └── Value
└── ...
```



