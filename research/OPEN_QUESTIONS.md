# Open questions

These items are not established by the current repository.

## Creditor accounting

- Enumerate every Multichain DOLA deployment and liability on Fantom, Polygon, Moonriver, Avalanche, Optimism, and any other supported chain.
- Explain the `105,838.399991211080659809` DOLA difference between the Arbitrum `anyDOLA` collateral and BSC wrapper supply.
- Determine the appropriate historical snapshot block for every affected chain.
- Define treatment of exchanges, contracts, liquidity pools, bridge transactions in flight, and balances moved after the incident.

## Current control

- Determine whether the credentials for MPC address `0xD7AD...9964` still exist and who, if anyone, can exercise them.
- Determine whether control of those credentials or the collateral is implicated in an insolvency or liquidation proceeding.

## Bridge state

- Enumerate all unfinalized DOLA withdrawals and retryable/in-flight deposits on the legacy Arbitrum bridge.
- Explain the approximately `0.1 DOLA` difference between current L1 gateway escrow and L2 supply.
- Verify the latest deployed L1 and L2 gateway implementation source against the exact runtime bytecode before authoring an upgrade.

## Implementation design

- Specify whether the intended remedy is a permanent DOLA finalization block, an escrow recovery, or fully funded duplicate-claim coverage.
- Specify treatment of the `24,391.498585284262944221` canonical Arbitrum DOLA currently outside `anyDOLA`.
- For an escrow transfer, prove the exact recoverable amount only after resolving legitimate holders and in-flight messages.
- For a custom gateway, define the legacy-holder migration mechanism and the new token/gateway trust model.

## Legal and governance

- Determine legal entitlement to the Arbitrum collateral and Ethereum escrow before any transfer or restitution.
- Obtain an authoritative classification of the required Arbitrum governance path for each proposed action.
- Determine whether emergency authorities can legally and technically execute a reactive gateway block; do not assume that they can.
