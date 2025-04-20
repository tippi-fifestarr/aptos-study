
### Types of Account Abstraction in Aptos

#### 1. Standard Account Abstraction (AA)
- Works with **existing accounts** by registering an authentication function
- Requires an explicit on-chain transaction to enable
- Costs gas for each account setup
- Useful for adding security features to established accounts

#### 2. Derivable Account Abstraction (DAA)
- **Deterministically derives** account addresses from abstract public keys
- No need for an initial setup transaction
- Creates isolated address spaces for each authentication scheme
- Perfect for cross-chain accounts and new account creation
- Provides identical user experience to native authentication

### Key Benefits of Aptos's Approach
- **Simplicity**: Authentication logic is directly integrated into the account
- **Security**: The Move language provides strong safety guarantees
- **Accessibility**: Developers can easily create custom authentication schemes
- **Performance**: Native implementation avoids additional protocol overhead
- **Flexibility**: Multiple account abstraction flavors for different use cases
