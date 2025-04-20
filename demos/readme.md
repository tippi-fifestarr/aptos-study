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