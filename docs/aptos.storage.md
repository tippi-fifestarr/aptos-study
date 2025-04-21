# Move Global Storage - Study Notes

### Global Storage Operators
Move programs interact with global storage using five key operations:

| Operation | Description | Usage | Aborts? |
|-----------|-------------|-------|---------|
| `move_to<T>(&signer, T)` | Publish resource T under signer's address | Create new resources | If resource already exists at address |
| `move_from<T>(address)` | Remove and return resource T from address | Remove resources | If resource doesn't exist at address |
| `borrow_global_mut<T>(address)` | Get mutable reference to resource T | Modify resources | If resource doesn't exist at address |
| `borrow_global<T>(address)` | Get immutable reference to resource T | Read resources | If resource doesn't exist at address |
| `exists<T>(address)` | Check if resource T exists at address | Verify resource existence | Never aborts |

### Index Notation (Since Move 2.0)
More concise syntax for storage operations:

| Index Syntax | Equivalent Operation |
|--------------|----------------------|
| `&T[address]` | `borrow_global<T>(address)` |
| `&mut T[address]` | `borrow_global_mut<T>(address)` |
| `T[address]` | `*borrow_global<T>(address)` |
| `T[address] = x` | `*borrow_global_mut<T>(address) = x` |
| `T[address].field` | `borrow_global<T>(address).field` |
| `T[address].field = x` | `borrow_global_mut<T>(address).field = x` |

## Key Rules and Constraints

1. **Resource Requirements**:
   - Resources must have the `key` ability
   - Resources can only be manipulated by their defining module

2. **Reference Safety**:
   - Cannot return references to global storage resources
   - This prevents dangling references

3. **`acquires` Annotation**:
   - Functions using global storage operators must be annotated with `acquires T`
   - Since Move 2.2, the annotation is optional (will be inferred)
   - Needed when:
     - Function directly uses `move_from<T>`, `borrow_global<T>`, or `borrow_global_mut<T>`
     - Function calls another function in the same module with `acquires T`

## Storage Models Comparison (Extended)

| Feature | Ethereum (EVM) | Aptos (Move) |
|---------|---------------|--------------|
| **Basic Structure** | Multi-layered Merkle Patricia Trees | Forest of account-rooted trees |
| **Complexity** | More complex with 4 different trees | Simpler two-map structure |
| **State Access** | Key-value store pattern | Type-safe resource access |
| **Safety** | Dynamic runtime checks | Static compile-time verification |
| **Access Control** | Contract-based | Module-based encapsulation |
| **Reference Model** | Value-based | Resource ownership with safe references |
| **Type Safety** | Limited | Strong type system with abilities |

## Example: Counter Module

```move
module 0x42::counter {
  use std::signer;
 
  // Resource definition
  struct Counter has key { i: u64 }
 
  // Publish a Counter resource
  public fun publish(account: &signer, i: u64) {
    move_to(account, Counter { i })
  }
 
  // Read the Counter value
  public fun get_count(addr: address): u64 acquires Counter {
    borrow_global<Counter>(addr).i
  }
 
  // Increment the Counter
  public fun increment(addr: address) acquires Counter {
    let c_ref = &mut borrow_global_mut<Counter>(addr).i;
    *c_ref = *c_ref + 1
  }
 
  // Delete the Counter and return its value
  public fun delete(account: &signer): u64 acquires Counter {
    let c = move_from<Counter>(signer::address_of(account));
    let Counter { i } = c;
    i
  }
}
```

## Advanced Features

### Storage Polymorphism
- Global storage operations can be used with generic types
- Allows dynamic indexing into global storage at runtime
- Example:
```move
struct Container<T> has key { t: T }

// Generic container
fun publish_generic_container<T>(account: &signer, t: T) {
  move_to<Container<T>>(account, Container { t })
}
```

# Move Global Storage - Study Notes

## Core Concepts

### Global Storage Operators
Move programs interact with global storage using five key operations:

| Operation | Description | Usage | Aborts? |
|-----------|-------------|-------|---------|
| `move_to<T>(&signer, T)` | Publish resource T under signer's address | Create new resources | If resource already exists at address |
| `move_from<T>(address)` | Remove and return resource T from address | Remove resources | If resource doesn't exist at address |
| `borrow_global_mut<T>(address)` | Get mutable reference to resource T | Modify resources | If resource doesn't exist at address |
| `borrow_global<T>(address)` | Get immutable reference to resource T | Read resources | If resource doesn't exist at address |
| `exists<T>(address)` | Check if resource T exists at address | Verify resource existence | Never aborts |

### Index Notation (Since Move 2.0)
More concise syntax for storage operations:

| Index Syntax | Equivalent Operation |
|--------------|----------------------|
| `&T[address]` | `borrow_global<T>(address)` |
| `&mut T[address]` | `borrow_global_mut<T>(address)` |
| `T[address]` | `*borrow_global<T>(address)` |
| `T[address] = x` | `*borrow_global_mut<T>(address) = x` |
| `T[address].field` | `borrow_global<T>(address).field` |
| `T[address].field = x` | `borrow_global_mut<T>(address).field = x` |

## Key Rules and Constraints

1. **Resource Requirements**:
   - Resources must have the `key` ability
   - Resources can only be manipulated by their defining module

2. **Reference Safety**:
   - Cannot return references to global storage resources
   - This prevents dangling references

3. **`acquires` Annotation**:
   - Functions using global storage operators must be annotated with `acquires T`
   - Since Move 2.2, the annotation is optional (will be inferred)
   - Needed when:
     - Function directly uses `move_from<T>`, `borrow_global<T>`, or `borrow_global_mut<T>`
     - Function calls another function in the same module with `acquires T`
   - Not needed when:
     - Calling functions with `acquires` from another module
   - Multiple resources require multiple `acquires` declarations

## Example: Counter Module

```move
module 0x42::counter {
  use std::signer;
 
  // Resource definition
  struct Counter has key { i: u64 }
 
  // Publish a Counter resource
  public fun publish(account: &signer, i: u64) {
    move_to(account, Counter { i })
  }
 
  // Read the Counter value
  public fun get_count(addr: address): u64 acquires Counter {
    borrow_global<Counter>(addr).i
  }
 
  // Increment the Counter
  public fun increment(addr: address) acquires Counter {
    let c_ref = &mut borrow_global_mut<Counter>(addr).i;
    *c_ref = *c_ref + 1
  }
 
  // Reset Counter to 0
  public fun reset(account: &signer) acquires Counter {
    let c_ref = &mut borrow_global_mut<Counter>(signer::address_of(account)).i;
    *c_ref = 0
  }
 
  // Delete the Counter and return its value
  public fun delete(account: &signer): u64 acquires Counter {
    let c = move_from<Counter>(signer::address_of(account));
    let Counter { i } = c;
    i
  }
 
  // Check if Counter exists
  public fun exists_at(addr: address): bool {
    exists<Counter>(addr)
  }
}
```

## Advanced Features

### Storage Polymorphism
- Global storage operations can be used with generic types
- Allows dynamic indexing into global storage at runtime
- Example:
```move
struct Container<T> has key { t: T }

// Generic container
fun publish_generic_container<T>(account: &signer, t: T) {
  move_to<Container<T>>(account, Container { t })
}

// Type-specific container
fun publish_instantiated_container(account: &signer, t: u64) {
  move_to<Container<u64>>(account, Container { t })
}
```

## Comparisons to Other Systems

### Move vs. Traditional Storage
1. **Type Safety**: Move provides strong safety guarantees through its type system
2. **Ownership Model**: Resources have clear ownership and can't be duplicated
3. **Reference Safety**: The system prevents dangling references
4. **Module Encapsulation**: Only the defining module can manipulate its resources

### Move Storage vs. Ethereum Storage
1. **Structure**: 
   - Move: Forest of trees rooted at account addresses
   - Ethereum: Key-value store with Patricia Merkle Trees

2. **Safety**:
   - Move: Static type checking prevents many errors at compile time
   - Ethereum: Dynamic checks at runtime

3. **Access Control**:
   - Move: Module-based, only defining module can manipulate resources
   - Ethereum: Contract-based with more flexible but less safe access patterns

### Move 1.0 vs. Move 2.0
1. **Syntax**: 
   - Move 2.0 added index notation for cleaner code
   - Examples: `T[address]` instead of `*borrow_global<T>(address)`

2. **Annotations**:
   - Move 2.2 made `acquires` annotations optional (now inferred)