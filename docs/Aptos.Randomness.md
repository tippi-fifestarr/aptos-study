# Aptos Randomness API - Study Notes

## Key Concepts

### Introduction
- The Aptos Randomness API (also called "Aptos Roll") provides secure random number generation within smart contracts
- Solves a critical issue: blockchain transactions are deterministic, making secure randomness difficult

### Previous Insecure/Awkward Methods

#### Insecure Method: Using Blockchain Data
```move
fun decide_winner() {
    let lottery_state = load_lottery_state_mut();
    let n = std::vector::length(&lottery_state.players);
    let winner_idx = aptos_framework::timestamp::now_microseconds() % n;
    lottery_state.winner_idx = std::option::some(winner_idx);
}
```
- **Security Issues**:
  - Users can bias results by selecting transaction submission time
  - Validators can bias results by choosing which block includes the transaction

#### Awkward Method: External Randomness Source
```move
fun update_winner(winner_idx: u64, seed: vector<u8>) {
    let lottery_state = load_lottery_state_mut();
    assert!(is_valid_seed(lottery_state.seed_verifier, seed), ERR_INVALID_SEED);
    let n = std::vector::length(players);
    let expected_winner_idx = derive_winner(n, seed);
    assert!(expected_winner_idx == winner_idx, ERR_INCORRECT_DERIVATION);
    lottery_state.winner_idx = std::option::some(winner_idx);
}
```
- **Issues**:
  - Complex workflow requiring off-chain coordination
  - Multi-step process involving multiple transactions

## Aptos Randomness API Usage

### Basic Implementation
```move
#[randomness]
entry fun decide_winner() {
    let lottery_state = load_lottery_state_mut();
    let n = vector::length(&lottery_state.players);
    let winner_idx = aptos_framework::randomness::u64_range(0, n);
    lottery_state.winner_idx = std::option::some(winner_idx);
}
```

### Requirements
1. **Function Annotation**: Must use `#[randomness]` attribute
2. **Function Visibility**: Must be `entry` and `private`
3. **Compiler & Runtime Validation**: Compiler enforces rules; VM verifies compliance at runtime

### Available API Functions
```move
module aptos_framework::randomness {
    // Integer generation (available for u8, u16, u32, u64, u128, u256)
    fun u64_integer(): u64 {}  // Random number across full range
    fun u64_range(min_incl: u64, max_excl: u64): u64 {}  // Random number in [min_incl, max_excl)
    
    // Byte generation
    fun bytes(n: u64): vector<u8> {}  // Random byte sequence of length n
    
    // Permutation generation
    fun permutation(n: u64): vector<u64> {}  // Random permutation of [0,1,...,n-1]
}
```

## Security Considerations

### 1. Function Visibility & Test-and-Abort Attacks
- **Problem**: Public functions using randomness allow "test-and-abort" attacks
- **Mitigation**: Randomness-dependent functions must be private
- **Example Attack**:
  ```move
  // Vulnerable code with #[lint::allow_unsafe_randomness]
  public fun decide_winner_internal(lottery_state: &mut lottery_state) {
      let winner_idx = aptos_framework::randomness::u64_range(0, n);
      lottery_state.winner_idx = std::option::some(winner_idx);
  }
  
  // Attacker code
  fun exploit() {
      decide_winner_internal();
      if (result_not_favorable()) abort;
  }
  ```

### 2. Undergasing Attacks
- **Problem**: Users can set gas limits to abort specific execution paths
- **Scenario**: Different outcomes consume different gas amounts
- **Example Attack**:
  ```move
  #[randomness]
  entry fun play(user: &signer) {
      let random_value = aptos_framework::randomness::u64_range(0, 100);
      if (random_value == 42) {
          win(user);  // Less gas
      } else {
          lose(user);  // More gas
      }
  }
  ```
  - Set max gas sufficient for win() but not lose()
  - Repeatedly attempt until win path executes successfully

### 3. Best Practices for Avoiding Undergasing
- Design favorable outcomes to use **more** gas than unfavorable ones
- Only allow trusted accounts to use randomness
- Separate randomness generation from actions based on randomness:
  1. First transaction: Generate and store random value
  2. Second transaction: Take action based on stored random value

### 4. Randomness Is Not Secret
- All randomness on blockchain is public - it's random but not private
- **Avoid**: Using randomness for cryptographic keys, hidden information, etc.

## Implementation Steps

1. Install latest aptos-cli
2. Identify functions needing randomness
3. Make them private and add `#[randomness]` attribute
4. Use appropriate randomness API functions
5. Design application to prevent undergasing attacks

## Example: Secure Lottery Implementation
```move
module module_owner::lottery {
    // Lottery state
    struct LotteryState has key {
        players: vector<address>,
        winner_idx: std::option::Option<u64>,
    }
    
    // Secure implementation with randomness API
    #[randomness]
    entry fun decide_winner() {
        let lottery_state = load_lottery_state_mut();
        let n = vector::length(&lottery_state.players);
        let winner_idx = aptos_framework::randomness::u64_range(0, n);
        lottery_state.winner_idx = std::option::some(winner_idx);
    }
}
```