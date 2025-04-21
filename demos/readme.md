# Aptos Demo Projects

In this folder, I've implemented Move-based contracts/modules for projects I previously built in Solidity. These implementations showcase the differences between Ethereum/Solidity and Aptos/Move development approaches.

## Featured Projects

### [Aptos Fighters VS Ethereum Fighters](./AptosFighters)
- **ETHGlobal Taipei Winner** 🏆
- A trading simulation game where players compete by managing asset portfolios
- Implements the Ethereum version's core mechanics in Move
- Features:
  - Asset trading in fictional balances (using Aptos' alternative to FHE in Ethereum)
  - Real-time price oracle integration via Pyth (equivalent to Chainlink in Ethereum)
  - Staking mechanics with rewards for winners
  - Game state management with time-based progression
  - Score calculation based on portfolio performance

### Coming Soon


## How to Run These Projects

Each project folder contains its own README with specific setup instructions, but the general process is:

1. Navigate to the project directory
   ```bash
   cd AptosFighters
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
   aptos move publish --named-addresses project=YOUR_ADDRESS
   ```

## Learning Focus

Each demo project focuses on teaching specific aspects of Aptos and Move development:

- **Resource management** - How to create, store, and manipulate resources
- **Object model** - Working with Aptos objects and dynamic fields
- **Event emission** - Creating and handling events for off-chain indexing
- **Authentication** - Working with signers and permissions
- **Testing** - Comprehensive Move testing approaches
- **Transaction flow** - Understanding the Aptos execution model



### issues 
- running tests 
   - missing match test like the ones we have in foundry , here we only have 
   ```bash 
   -f, --filter <FILTER>
          A filter string to determine which unit tests to run
   ```
   - using correct code but the evm uses diffirent error code 
```bash 

┌── test_init_contract_invalid_duration ──────
│ error[E11001]: test failure
│     ┌─ C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:262:5
│     │
│ 216 │ public entry fun init_contract(
│     │                  ------------- In this function in 0x456::aptos_fighters
│     ·
│ 262 │     assert!(game_duration > 0, error::invalid_argument(EINVALID_DURATION));
│     │     ^^^^^^ Test did not error as expected. Expected test to abort with code 3 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters but instead it aborted with code 65539 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters rooted here
│
│
│ stack trace
│       aptos_fighters::test_init_contract_invalid_duration(C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:408-418)
│
└──────────────────


┌── test_init_contract_invalid_reward_amount ──────
│ error[E11001]: test failure
│     ┌─ C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:264:5
│     │
│ 216 │ public entry fun init_contract(
│     │                  ------------- In this function in 0x456::aptos_fighters
│     ·
│ 264 │     assert!(reward_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
│     │     ^^^^^^ Test did not error as expected. Expected test to abort with code 2 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters but instead it aborted with code 65538 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters rooted here
│
│
│ stack trace
│       aptos_fighters::test_init_contract_invalid_reward_amount(C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:495-505)
│
└──────────────────


┌── test_init_contract_invalid_staking_amount ──────
│ error[E11001]: test failure
│     ┌─ C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:263:5
│     │
│ 216 │ public entry fun init_contract(
│     │                  ------------- In this function in 0x456::aptos_fighters
│     ·
│ 263 │     assert!(game_staking_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
│     │     ^^^^^^ Test did not error as expected. Expected test to abort with code 2 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters but instead it aborted with code 65538 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters rooted here
│
│
│ stack trace
│       aptos_fighters::test_init_contract_invalid_staking_amount(C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:451-461)
│
└──────────────────


┌── test_init_contract_invalid_start_time ──────
│ error[E11001]: test failure
│     ┌─ C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:531:31
│     │
│ 511 │     public fun test_init_contract_invalid_start_time(aptos_framework: &signer) {
│     │                ------------------------------------- In this function in 0x456::aptos_fighters
│     ·
│ 531 │         let game_start_time = current_time - 1000; // Start in the past (invalid)
│     │                               ^^^^^^^^^^^^^^^^^^^ Test did not error as expected. Expected test to abort with code 17 originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters but instead it gave an arithmetic error with error message: "Subtraction overflow". Error originating in the module 0000000000000000000000000000000000000000000000000000000000000456::aptos_fighters rooted here
│
│
└──────────────────


```