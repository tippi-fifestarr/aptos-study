# Aptos Development Study Notes & Projects

Welcome to my Aptos blockchain development repository! This collection contains comprehensive study notes and practical demo projects for learning Aptos and Move development.

## 📚 Study Notes

The repository contains detailed study notes on various aspects of Aptos and Move development:

### Core Concepts
- [Accounts & Transactions](./docs/aptos.accounts.transactions.md) - Account fundamentals, transaction handling, and asset standards
- [Storage in Move](./docs/aptos.storage.md) - Global storage operators, rules, and comparison with other systems
- [Ethereum to Aptos Comparison](./docs/etherum-to-aptos.studynotes.md) - Key differences between Ethereum and Aptos development
- [Solidity to Move Cheatsheet](./docs/solidty.move.cheatsheet.md) - Side-by-side comparison of Solidity and Move concepts and code

### Advanced Features
- [Account Abstraction](./docs/Aptos.AA.md) - Types and benefits of account abstraction in Aptos
- [Oracle Integration](./docs/aptos.oracle.md) - Connecting to off-chain data via Pyth Network
- [Randomness API](./docs/Aptos.Randomness.md) - Secure random number generation in Aptos
- [Sponsored Transactions](./docs/aptos.meta.transactions.md) - Implementation of gas fee sponsorship
- [Security Guidelines](./docs/aptos.security.md) - Best practices for secure Move development

## 🧪 Demo Projects

The [`/demos`](./demos) directory contains practical projects to apply what you've learned:

### Featured Projects
- [**Aptos Fighters VS Ethereum Fighters**](./demos/aptos_fighters) - ETHGlobal Taipei winner, a trading game where players compete by buying/selling assets with encrypted balances, implementing the Ethereum version's core game mechanics in Move

## 🚀 Getting Started

### Prerequisites
- Install the [Aptos CLI](https://aptos.dev/en/build/cli)
- Set up a local development environment

### Setup Instructions
1. Clone the repository

2. Navigate to a demo project:
   ```bash
   cd demos/aptos_fighters
   ```

3. Compile the Move code:
   ```bash
   aptos move compile
   ```

4. Run tests:
   ```bash
   aptos move test
   ```

5. Deploy to testnet (ensure you have testnet tokens):
   ```bash
   aptos move publish --named-addresses counter=YOUR_ADDRESS
   ```

## 📋 Learning Path

For those new to Aptos and Move, I recommend following this learning order:

1. **Foundations**:
   - Start with Account & Transaction notes
   - Study the Storage system in Move
   - Review Ethereum to Aptos comparison (especially if coming from Ethereum)

2. **Core Development**:
   - Implement the SimpleCounter and Billboard demos
   - Practice with the Solidity to Move cheatsheet

3. **Advanced Topics**:
   - Study Account Abstraction, Oracles, and Randomness
   - Experiment with TokenSwap and DutchAuction demos

4. **Specialized Features**:
   - Dive into Sponsored Transactions and Security Guidelines
   - Build the MultisigWallet and GaslessApp demos

## 🔗 Additional Resources

- [Official Aptos Documentation](https://aptos.dev/)
- [The Move Book](https://aptos.dev/en/build/smart-contracts/book)
- [Aptos Framework Reference](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework)
- [Aptos Developer Discord](https://discord.gg/aptoslabs)

## 🤝 Contributing

Contributions are welcome! If you find errors in the study notes or want to add more examples, please open a pull request.

## 📄 License

This repository is licensed under MIT - see the [LICENSE](LICENSE) file for details.