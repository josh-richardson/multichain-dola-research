# Governance mechanics and precedent

This document identifies the authorities required for the technical actions in [`TECHNICAL_OPTIONS.md`](TECHNICAL_OPTIONS.md). It does not predict whether those authorities will act.

## Arbitrum-controlled components

### L1 Standard ERC-20 Gateway

```text
L1 Standard ERC-20 Gateway
0xa3A7B6F88361F48403514059F1F16C8E78d60EeC
  -> ProxyAdmin
     0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa
       -> owner: L1 UpgradeExecutor
          0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
```

An implementation change to L1 withdrawal finalization or an escrow-transfer function requires execution through this authority chain.

### L2 Standard ERC-20 Gateway

```text
L2 Standard ERC-20 Gateway
0x09e9222E96E7B4AE2a407B98d48e330053351EEe
  -> ProxyAdmin
     0xd570aCE65C43af47101fC6250FD6fC63D1c22a86
       -> owner: L2 UpgradeExecutor
          0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827
```

An L2 gateway block requires execution through this authority chain.

### Shared StandardArbERC20 beacon

The canonical Arbitrum DOLA proxy uses beacon `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`. Its owner is the L2 UpgradeExecutor at `0xCF5757...A827`. The beacon is shared by other standard-bridge tokens.

### Gateway routers

The L1 GatewayRouter is `0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef`, owned by the L1 UpgradeExecutor. Router registration can select a custom gateway for future DOLA routing. It cannot by itself disable direct use of the old gateways.

## Inverse-controlled components

Inverse governance can conditionally:

- deploy and operate a custom DOLA gateway;
- authorize a restitution distribution;
- fund restitution from Treasury assets;
- mint DOLA through the existing operator/minter system;
- deploy a replacement Ethereum token and coordinate a migration.

Inverse governance cannot through current DOLA permissions:

- transfer DOLA out of Arbitrum's L1 gateway;
- modify the L1 or L2 standard gateways;
- change the shared StandardArbERC20 beacon;
- blacklist a holder of existing Ethereum DOLA.

## Relevant Arbitrum actions reviewed

### Custom gateway registrations

The Boring and Sky proposals use the established router-registration pattern: deploy custom gateway components and have Arbitrum governance register them. These actions support the technical availability of a new custom DOLA gateway. They do not establish a mechanism for neutralizing pre-existing legacy escrow claims.

### USDT legacy gateway disable

`DisableGatewayAction` writes the disabled sentinel into gateway-router mappings. Source review and post-action transaction review establish that this does not change the legacy gateways' direct call and finalization behavior. Tether had separately changed its L2 token behavior before the router action.

The reviewed USDT action left existing L1 gateway escrow in place. It is therefore precedent for router disablement, not for escrow recovery.

### Generic proxy-upgrade actions

The Arbitrum governance repository contains generic `ProxyUpgradeAction` and `ProxyUpgradeAndCallAction` mechanisms. These establish the execution machinery for a gateway implementation change. They are not precedent for the proposed DOLA-specific substance of that change.

## Precedent boundary

The reviewed sources establish precedent for:

- custom gateway registration;
- disabling a router mapping;
- generic proxy upgrades through governance.

No reviewed source established an executed Arbitrum action that:

- inserted a token-specific rejection into the shared standard gateway; or
- transferred ERC-20 user escrow out of a canonical gateway to remediate a third-party bridge failure.

This is a statement about the reviewed record, not a prediction about a future proposal.

## Required governance deliverables

Any proposal should include:

- exact deployed implementation and action-contract bytecode;
- complete authority and call sequence;
- storage-layout comparison;
- fork tests covering direct gateway calls and in-flight messages;
- exact token and amount constraints;
- rollback or failure behavior;
- independent audit reports;
- restitution accounting where value is transferred.
