# Smart Contract Testing Cheatsheet: Hardhat/Foundry vs Aptos Move

## Test Structure & Organization

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Test location | Separate `/test` directory | Separate `/test` directory | Inside source files with `#[test]` annotation |
| Test isolation | Each test file is separate | Each test file is separate | Tests are part of the module they test |
| Test file naming | `*.test.js` or `*.spec.js` | `*.t.sol` | No separate files, tests inside module |
| Test grouping | `describe()` blocks | Contract inheritance | No explicit grouping, just separate test functions |
| Individual tests | `it()` or `test()` functions | Functions with `test` prefix | Functions with `#[test]` annotation |

## Test Setup & Fixtures

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Setup helpers | `beforeEach()` hooks | `setUp()` function | `#[test_only]` helper functions |
| Test accounts | `ethers.getSigners()` | `vm.addr()` & cheatcodes | `account::create_account_for_test()` |
| Deploy contracts | Manual deployment in setup | Manual deployment in setup | Object creation with `object::create_named_object()` |
| Fixtures | Hardhat-specific fixtures feature | Base setup contract + inheritance | Common setup functions with `#[test_only]` |
| Time manipulation | `ethers.provider.send("evm_increaseTime")` | `vm.warp()` | `timestamp::fast_forward_seconds()` |

## Testing Assertions & Expectations

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Basic assertions | `expect(x).to.equal(y)` | `assertEq(x, y)` | `assert!(x == y, error_code)` |
| Error testing | `await expect(tx).to.be.revertedWith()` | `vm.expectRevert()` | `#[expected_failure(abort_code = code)]` |
| Custom errors | `expect().to.be.revertedWithCustomError()` | `vm.expectRevert(bytes4(selector))` | `#[expected_failure(abort_code = code)]` |
| Event testing | `expect(tx).to.emit(contract, "Event")` | `expectEmit()` | Events not directly testable |
| Gas testing | `await tx.wait()` then analyze | `gasLeft()` | Not applicable |

## Mock & Test Environment

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Test network | Local Hardhat Network | Local Anvil | In-memory test environment |
| Contract mocking | Mocks or Smock library | Interface mocking | Create test-only functions with `#[test_only]` |
| External calls | Mocks or network forking | Forking or mocks | Manual mocking required |
| Storage manipulation | Limited without plugins | Direct via `vm.store()` | Direct state manipulation in tests |
| Test-only code | Conditional imports or flags | `#if TEST` pragma | `#[test_only]` annotation |

## Advanced Testing Techniques

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Fuzz testing | External (e.g., Echidna) | Built-in with `function(uint256)` | Limited, mostly manual |
| Invariant testing | External tools | Built-in | Manual implementation |
| Forking mainnet | `hardhat.config.js` forking config | `--fork-url` flag | Not directly supported |
| Coverage | Hardhat coverage plugin | Forge coverage | Limited tooling |
| Debugging | Hardhat console.log | Forge `console2.log` | `debug::print()` |
| Trace analysis | Hardhat traces | Forge traces | Limited support |

## Mocking External Dependencies

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Price oracles | Mock contracts | Mock or fork cheatcodes | Custom test-only implementation |
| Token transfers | Mock ERC20s | Mock or pre-fund | Manual state manipulation |
| External protocols | Mock contracts or fork | Mock or fork | Manual state setup |
| Randomness | Mocks or test hooks | Cheatcodes | Manual overrides |

## End-to-End Testing

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Approach | Scripted interactions | Contract-based | Function-based |
| Complex scenarios | Script multiple transactions | Multiple test function calls | Sequential function calls |
| User journey simulation | Multiple signers, txs | vm.prank() | Multiple test accounts |
| Cross-contract tests | Direct in JS/TS | Call multiple contracts | Test across modules |

## Testing Commands & Workflow

| Feature | Hardhat (Solidity) | Foundry (Solidity) | Aptos Move |
|---------|-------------------|-------------------|------------|
| Run all tests | `npx hardhat test` | `forge test` | `aptos move test` |
| Run specific test | `npx hardhat test --grep "pattern"` | `forge test --match-test testName` | `aptos move test --filter module::name` |
| Verbose output | `--verbose` flag | `-vvv` flag | `--stackless` for more details |
| Gas reporting | Gas reporter plugin | `--gas-report` flag | Not applicable |
| Test files | JavaScript/TypeScript | Solidity | Move (same as source) |

## Best Practices Comparison

| Best Practice | Hardhat/Foundry | Aptos Move |
|---------------|----------------|------------|
| Test isolation | Each test should be independent | Each test should be independent |
| Comprehensive testing | Test happy and sad paths | Test happy and sad paths |
| External dependencies | Mock or fork | Manual mock implementation |
| Coverage goal | High coverage (>90%) | High coverage (>90%) |
| Test-only helpers | Keep in test files | Mark with `#[test_only]` in module |
| Test speed | Optimize for fast tests | Optimize for fast tests |
| Edge cases | Fuzz testing | Manual testing |
| State verification | Check storage slots | Check global storage state |

## Special Aptos Move Testing Considerations

1. **Resource Access**: Unlike Ethereum, Move has resources that can only be accessed by their owning module, requiring specific patterns for testing

2. **Abort Codes**: Move uses specific abort codes instead of revert strings, requiring exact code matching

3. **Global Storage**: Move's global storage model differs from Ethereum's, affecting how you verify state changes

4. **Module Initialization**: Move modules initialize differently than Solidity contracts, often requiring setup in tests

5. **Time Dependency**: Must use `timestamp::set_time_has_started_for_testing()` before time-dependent testing

6. **Signer Management**: Requires careful management of signer objects from test accounts

7. **External Modules**: Dependency modules need explicit imports and test setup

8. **Resource Account Pattern**: Testing resource accounts requires special consideration

9. **Test-Only Functions**: Leverage `#[test_only]` for helper functions and test utilities

10. **Artifacts**: Move doesn't generate artifacts like ABIs, affecting how tests interact with modules