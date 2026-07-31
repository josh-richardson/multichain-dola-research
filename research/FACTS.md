# Verified facts and control paths

Unless stated otherwise, balances and mutable configuration were checked on 2026-07-31. Arbitrum values were read at block `489736745`.

## Contract map

| Role | Chain | Address | Evidence status |
|---|---:|---|---|
| Ethereum DOLA | 1 | `0x865377367054516e17014CcdED1e7d814EDC9ce4` | Verified onchain/source |
| Arbitrum L1 Standard ERC-20 Gateway | 1 | `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` | Verified onchain/source |
| Canonical Arbitrum DOLA | 42161 | `0x6a7661795c374c0bfc635934efaddff3a7ee23b6` | Verified onchain/source |
| Arbitrum L2 Standard ERC-20 Gateway | 42161 | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` | Verified onchain/source |
| Multichain `anyDOLA` custody token | 42161 | `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` | Verified onchain/source |
| Multichain Router V6 and `anyDOLA` vault | 42161 | `0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc` | Verified onchain/source |
| Router MPC authority | 42161 | `0xD7ADbfC92d0250f9B1a08e0a32A84137b68A9964` | Verified onchain, identity/control unresolved |
| BSC Multichain DOLA | 56 | `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840` | Verified onchain/source |

## BSC wrapper

Calls to the BSC token establish:

| Call | Result |
|---|---|
| `underlying()` | `0x0000000000000000000000000000000000000000` |
| `vault()` / `owner()` | `0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7` |
| `getAllMinters()` | `[0x58892974758A4013377A45fad698D2FF1F08d98E]` |
| `totalSupply()` | `1,793,864.391064841026826353` |

Because `underlying()` is zero, the wrapper contract itself holds no configured redeemable underlying token. This does not determine the legal rights of holders; it establishes only the deployed token mechanics.

## Arbitrum custody

Calls to `0x0615...48b1` establish:

| Call | Result |
|---|---|
| `name()` | `Dola USD Stablecoin` |
| `symbol()` | `anyDOLA` |
| `underlying()` | `0x6A7661795C374c0bFC635934efAddFf3A7Ee23b6` |
| `vault()` / `owner()` | `0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc` |
| `getAllMinters()` | `[0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc]` |

Canonical Arbitrum DOLA `balanceOf(0x0615...48b1)` is `1,899,702.791056052107486162`.

The latest canonical DOLA transfer involving the custody contract returned by the explorer API was an inbound `2,000 DOLA` transfer at Arbitrum block `108043811`, transaction `0xaab69cc729c639969a8c6c30d6428d0f0e165eeb60c77beb5f5be94969145d28`, timestamp `1688542456` (2023-07-05). No later transfer was returned.

## Demonstrated Multichain release path

Verified `AnyswapV6Router` source implements:

```solidity
function anySwapInUnderlying(
    bytes32 txs,
    address token,
    address to,
    uint amount,
    uint fromChainID
) external onlyMPC {
    _anySwapIn(txs, token, to, amount, fromChainID);
    AnyswapV1ERC20(token).withdrawVault(to, amount, to);
}
```

For `token = anyDOLA`, `_anySwapIn` mints wrapper tokens to `to`. `withdrawVault` then burns those tokens and transfers the configured underlying canonical Arbitrum DOLA from the custody contract to `to`.

The current Router V6 `mpc()` is `0xD7AD...9964`. A one-DOLA `eth_call` simulation:

- succeeded with `from = 0xD7AD...9964`;
- reverted with `AnyswapV6Router: FORBIDDEN` from an arbitrary address.

This demonstrates that a valid call from the configured MPC can release the collateral. It does not prove that any named person or entity currently controls the MPC credentials.

## Canonical bridge backing

Canonical Arbitrum DOLA reports:

| Call | Result |
|---|---|
| `l1Address()` | `0x865377367054516e17014CcdED1e7d814EDC9ce4` |
| `l2Gateway()` | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` |
| `totalSupply()` | `1,924,094.289641336370430383` |

Ethereum DOLA `balanceOf(0xa3A7...60EeC)` is `1,924,094.389641336370430484`. The approximately `0.1 DOLA` difference between L1 escrow and L2 supply is not material to the control-path finding but should be explained before using the figures for final accounting.

## Legacy withdrawal path

Verified bridge source establishes:

- `L2ArbitrumGateway.outboundTransfer` is publicly callable.
- For a direct caller, `_from` becomes `msg.sender`; the L2 router is not required.
- The gateway calls `bridgeBurn` on canonical Arbitrum DOLA and creates an L2-to-L1 message.
- L1 `finalizeInboundTransfer` authenticates the counterpart gateway/outbox path and does not consult the current gateway-router mapping.

Therefore a party that first receives canonical Arbitrum DOLA from `anyDOLA` can use the legacy gateway directly even after a router remap.

## Derived amounts

| Derivation | Amount |
|---|---:|
| Arbitrum DOLA outside `anyDOLA` | `1,924,094.289641336370430383 - 1,899,702.791056052107486162 = 24,391.498585284262944221` |
| `anyDOLA` collateral above BSC supply | `1,899,702.791056052107486162 - 1,793,864.391064841026826353 = 105,838.399991211080659809` |

These differences are arithmetic facts. Their attribution to particular users or chains is unresolved.
