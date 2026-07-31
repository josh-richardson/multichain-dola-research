# Technical options

This document records concrete actions, required authority, and technical effect. It does not predict whether a DAO or other actor will approve an action.

## Required objective

For replacement DOLA to create no duplicate claim, the existing Multichain-controlled canonical Arbitrum DOLA must either cease to be redeemable for Ethereum DOLA, or the possible duplicate claim must be fully funded.

## Option 1: custom gateway registration

### Action

Deploy an Inverse-specific L1/L2 gateway and L2 token implementation, then have Arbitrum governance call `L1GatewayRouter.setGateways` for Ethereum DOLA. Register the corresponding L2 token with the custom gateway.

### Required authority

- Arbitrum governance for the gateway-router registration.
- Inverse for the new gateway/token deployment and operation.

### Technical effect

- Changes the standard route for future DOLA deposits and withdrawals.
- Provides a forward migration path for users.

### Limitation

It does not disable the old L2 gateway or old L1 finalization path. A holder of legacy canonical Arbitrum DOLA can call the old L2 gateway directly. This option is therefore insufficient by itself to neutralize the Multichain claim.

### Status

**Technically possible; insufficient alone.**

## Option 2: block legacy L1 finalization for DOLA

### Action

Upgrade the legacy L1 Standard ERC-20 Gateway implementation so `finalizeInboundTransfer` rejects Ethereum DOLA when the message originates from the legacy DOLA path. The action must be narrowly scoped to the DOLA token and preserve unrelated gateway behavior.

A corresponding L2 gateway block on `outboundTransfer` can prevent new withdrawal initiation, but the L1 finalization block is the controlling protection against already-created or direct legacy messages.

### Required authority

- L1 Standard ERC-20 Gateway proxy: ProxyAdmin `0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa`.
- ProxyAdmin owner: L1 UpgradeExecutor `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd`.
- Arbitrum governance execution path to the UpgradeExecutor.

An L2 defense-in-depth upgrade additionally requires the L2 UpgradeExecutor path controlling the L2 gateway ProxyAdmin.

### Technical effect

- Prevents the legacy Multichain-controlled L2 claim from releasing Ethereum DOLA after the upgrade.
- Does not transfer or redistribute existing escrow.

### Implementation requirements

- Specify the exact DOLA token and legacy gateway pair.
- Define handling of in-flight withdrawals.
- Preserve storage layout and initialization behavior.
- Test all standard gateway entry points, not only the router path.
- Audit the shared gateway implementation change.

### Status

**Technically possible only through Arbitrum-controlled gateway upgrades.**

## Option 3: shared L2 token-beacon change

### Action

Upgrade the shared `StandardArbERC20` beacon implementation and add DOLA-specific behavior that blocks `bridgeBurn` for the affected balance or token.

### Required authority

The beacon at `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333` is owned through Arbitrum's L2 UpgradeExecutor path.

### Technical effect

A correctly implemented DOLA-specific branch could prevent legacy DOLA burns on L2.

### Limitations

- The beacon is shared by multiple standard-bridge tokens.
- A logic upgrade changes the implementation executed by every proxy using that beacon.
- The DOLA proxy exposes no callable function that can replace its beacon independently.

### Status

- **Per-proxy beacon reassignment: impossible through the currently deployed proxy runtime.**
- **Shared-beacon implementation change: technically possible through Arbitrum authority, with shared-code impact.**

## Option 4: one-shot Ethereum gateway escrow transfer

### Action

Upgrade the L1 gateway with a narrowly scoped, one-use function that transfers an exact amount of Ethereum DOLA from gateway escrow to a designated recovery contract or Treasury, then execute it.

### Required authority

The same Arbitrum L1 UpgradeExecutor and ProxyAdmin path as Option 2.

### Technical effect

- Recovers escrow rather than merely preventing withdrawal.
- If the transferred amount equals the remaining Multichain-attributable claim after other holders and in-flight messages are resolved, a later Multichain withdrawal will fail for insufficient gateway balance.

### Preconditions

- Enumerate all legitimate legacy L2 holders.
- Resolve or account for every in-flight deposit and withdrawal.
- Establish the amount attributable to the Multichain liability.
- Specify a distribution and accounting contract.
- Obtain legal analysis of the proposed transfer.

### Status

**Technically possible through an Arbitrum-controlled gateway upgrade. No direct Arbitrum precedent was found for transferring user-token escrow in this manner.**

## Option 5: unilateral Ethereum DOLA action by Inverse

### Candidate actions reviewed

- seize DOLA from the Arbitrum L1 gateway;
- blacklist the gateway or recipient;
- pause legacy DOLA;
- upgrade Ethereum DOLA with a transfer restriction.

### Deployed constraints

Ethereum DOLA is not a proxy and exposes no pause, blacklist, administrative `transferFrom`, or escrow-seizure function. Its operator can manage minters and mint; it cannot transfer the gateway's existing balance.

### Status

**The listed seizure, blacklist, pause, and upgrade actions are impossible through the currently deployed Ethereum DOLA contract.**

## Option 6: full Ethereum DOLA migration

### Action

Deploy a new Ethereum token, migrate accepted holders and protocol accounting, replace minters, liquidity, collateral integrations, oracles, exchange listings, and cross-chain deployments, and deprecate the old token economically.

### Technical effect

The old Arbitrum claim would redeem only for deprecated old DOLA rather than the new asset.

### Limitation

This requires migration of every integration and leaves residual value wherever old DOLA remains accepted or liquid.

### Status

**Technically possible; ecosystem-wide migration required.**

## Option 7: replacement issuance backed against duplicate-claim risk

### Action

Distribute DOLA to verified affected holders while separately committing assets sufficient to cover any still-live Multichain claim.

### Required authority

Inverse governance and sufficient Treasury assets or other committed backing.

### Technical effect

Does not neutralize the old claim. It funds the resulting maximum liability instead.

### Status

**Technically possible if the complete duplicate claim is funded. A probability-weighted reserve is risk management, not full neutralization.**
