# Aptos Sponsored Transactions 
## What Are Sponsored Transactions?

Sponsored transactions allow one account (the fee payer) to cover the gas fees for another account's transaction (the sender). This feature was implemented through [AIP-39](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-39.md) and enables applications to create better user experiences by removing the need for users to hold APT tokens for gas.

## Key Benefits

- **Improved Onboarding**: New users can interact with dApps without acquiring APT tokens first
- **Better UX**: Applications can abstract away blockchain fees from their users
- **Cross-Chain Integration**: Projects can onboard users from other chains (like Ethereum)


## Process Flow

1. **Sender prepares operation**: Sender determines an operation by creating a `RawTransaction`
2. **Transaction wrapping**: Sender wraps the transaction in a `RawTransactionWithData::MultiAgentWithFeePayer` structure
   - *Prior to framework 1.8*: Must contain fee payer's address
   - *After framework 1.8*: Can optionally set to `0x0`
3. **Signature collection**: 
   - The sender signs the transaction
   - (Optional) The sender collects signatures from other involved accounts
4. **Fee payer signing**: Transaction is forwarded to the fee payer for signing
5. **Transaction submission**: Fully signed transaction is submitted to the blockchain
6. **Execution**: 
   - Sender's sequence number is incremented
   - All gas fees are deducted from the fee payer's account
   - Any gas refunds go to the fee payer


## Implementation Strategy

For application developers, consider these strategies:

1. **Backend-as-Fee-Payer**: Run a backend service that acts as the fee payer
2. **Transaction Relaying**: Create an API where users can submit unsigned or partially signed transactions to be completed
3. **Budget Management**: Implement limits on how much gas your application is willing to sponsor per user/transaction
4. **Gas Optimization**: Carefully optimize your transactions to minimize the cost of sponsorship

## Security Considerations

- **Transaction Validation**: Always validate transaction contents before signing as a fee payer
- **Replay Protection**: Verify the sender's sequence number to prevent replay attacks
- **Spending Limits**: Consider implementing per-user or per-session sponsorship limits
- **Simulating Transactions**: Use simulation to estimate gas costs before sponsoring

## Common Patterns

1. **Selective Sponsorship**: Only sponsor specific transaction types or functions
2. **Metered Sponsorship**: Track and limit the amount of gas sponsored per user
3. **Time-Limited Sponsorship**: Only sponsor transactions during promotions or for new users
4. **Conditional Sponsorship**: Require users to meet certain conditions to qualify for sponsorship
