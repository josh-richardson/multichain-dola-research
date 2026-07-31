# SUPERSEDED: Option D - Custom L1/L2 gateway

> Historical working memo. See `../TECHNICAL_OPTIONS.md`.

Date: 2026-04-14
Author: research agent (pure research, no code)

## Summary — Verdict

**Option D does NOT solve the Multichain problem.** It is politically lighter than Options A/B (shared-infrastructure upgrades), but it is technically **insufficient on its own** because the old L1 standard gateway can finalize withdrawals directly from the Outbox, bypassing the `L1GatewayRouter` mapping entirely. The ~1.9 M L2 DOLA still in the Multichain router remains a live claim on the ~1.935 M L1 DOLA escrowed at `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`, regardless of any `setGateway` redirect.

Option D is viable only as **one component of a compound action**: (custom gateway registration) + (Arbitrum-DAO-authored action that either neutralizes the old L1 escrow path or forces its drain). That compound action is essentially Option A/B in different wrapping — so Option D's "it's just a routine custom-gateway AIP" political argument collapses.

Political viability vs A/B/C:
- Custom-gateway registration alone: routine (precedents: Sky/USDS, Livepeer LPT). But alone it does not fix DOLA.
- Custom-gateway registration + escrow drain / old-gateway-disable-for-DOLA: becomes a bespoke DOLA-specific constitutional AIP, which is roughly as heavy as Option A/B.
- Worse than Option C (L1-side neutralization via DOLA operator) because it requires Arbitrum DAO approval at all.

## 1. `setGateway` authorization path

L1GatewayRouter: `0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef`
Implementation source reviewed: `/private/tmp/tmp.flesh.7gbC/research/artifacts/l1router_impl.txt`.

Two entry points in the router implementation:

### 1a. Token-initiated `setGateway(address _gateway, ...)` (permissionless in theory)

```solidity
require(
    ArbitrumEnabledToken(msg.sender).isArbitrumEnabled() == uint8(0xa4b1),
    "NOT_ARB_ENABLED"
);
require(_gateway.isContract(), "NOT_TO_CONTRACT");
address currGateway = getGateway(msg.sender);
if (currGateway != address(0) && currGateway != defaultGateway) {
    require(currGateway == _gateway, "NO_UPDATE_TO_DIFFERENT_ADDR");
}
```

Requirements:
- `msg.sender` must be the L1 token itself AND expose `isArbitrumEnabled()` returning `0xa4b1`.
- Token must currently be on the default gateway (DOLA is — confirmed below).

L1 DOLA (`0x865377367054516e17014CcdED1e7d814EDC9ce4`) is the frozen `ERC20.sol` in `dola-l1.json` (Solidity 0.5.16, no proxy, no Arbitrum hooks, no `isArbitrumEnabled()` method). L1 DOLA's `operator()` is the Inverse Treasury but there is no minter-level function that can CALL the router. **Token-initiated path is not available to Inverse** unless Inverse first deploys a new L1 DOLA implementation — which defeats the premise of L1 DOLA being the canonical, immutable asset.

### 1b. Owner-initiated `setGateways(...)` (privileged)

```solidity
function setGateways(...) external payable onlyOwner returns (uint256) { ... }
```

Router owner (queried on-chain 2026-04-14):
- `L1GatewayRouter.owner() = 0x3ffFbAdAF827559da092217e474760E2b2c3CeDd`

Bytecode at that address is an OZ transparent-proxy pattern (admin slot + DEFAULT_ADMIN/EXECUTOR roles present). This matches the Arbitrum **L1 Upgrade Executor** pattern. Access flows: Arbitrum DAO (Tally) → L1 Timelock (DelayedInbox round-trip) → L1 Upgrade Executor (`perform`-calls action contract). UNVERIFIED that the address is literally `L1UpgradeExecutor` (matches pattern but not confirmed by name lookup in this session).

**Conclusion**: practically the only path for DOLA is a **constitutional AIP** that the Arbitrum DAO votes on, which ultimately `perform`-calls a `SetGatewayAction` (or `RegisterAndSetArbCustomGatewayAction`) from the L1 Upgrade Executor.

### Current state (verified on-chain 2026-04-14)

- `getGateway(DOLA_L1) = 0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` (default standard gateway)
- `defaultGateway() = 0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`
- L1 escrow on that gateway: `1,935,010.023641...` DOLA (matches L2 totalSupply within rounding).
- L2 DOLA token (`0x6A7661795C374c0bFC635934efAddFf3A7Ee23b6`):
  - `l1Address() = 0x865377367054516e17014CcdED1e7d814EDC9ce4`
  - `l2Gateway() = 0x09e9222E96E7B4AE2a407B98d48e330053351EEe`
- L2 gateway counterpart: `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` (the old L1 standard gateway)

## 2. Custom gateway interface requirements

Per Arbitrum docs and `ITokenGateway` / `IL1ArbitrumGateway` interfaces:

### L1 custom gateway MUST implement
- `outboundTransfer(address _token, address _to, uint256 _amount, uint256 _maxGas, uint256 _gasPriceBid, bytes _data)` and `outboundTransferCustomRefund(...)` — escrows L1 token, sends retryable to L2 counterpart.
- `finalizeInboundTransfer(address _token, address _from, address _to, uint256 _amount, bytes _data)` — guarded by `onlyCounterpartGateway` (reads Outbox's `getL2ToL1Sender` and compares to `counterpartGateway`). Releases L1 escrow.
- `calculateL2TokenAddress(address _l1Token) returns (address)` — MUST return a non-zero, non-default-derived address. The `L1GatewayRouter._setGateways` sanity-checks this and reverts with `TOKEN_NOT_HANDLED_BY_GATEWAY` otherwise.
- `counterpartGateway()` — the L2 custom gateway address.
- `supportsInterface` for `outboundTransferCustomRefund.selector`.

### L2 custom gateway MUST implement
- Same `ITokenGateway` surface on L2.
- `finalizeInboundTransfer` (onlyCounterpartGateway with `AddressAliasHelper.applyL1ToL2Alias`) — mints L2 token on deposit.
- `outboundTransfer` — burns L2 token, `sendTxToL1` with payload targeting L1 counterpart.

### Token-side requirements
- If using `RegisterAndSetArbCustomGatewayAction`, the custom L1 gateway must expose a `forceRegisterTokenToL2(address[] l1Tokens, address[] l2Tokens, ...)` hook (L1Arb/Custom gateway pattern, per `contracts/tokenbridge/ethereum/gateway/L1CustomGateway.sol`, unverified in this session but standard).
- The **new L2 DOLA** in Option D is a fresh deployment ; it must implement `IArbToken` (`l1Address()`, `bridgeMint`, `bridgeBurn`).

Reference: Arbitrum docs — Generic custom gateway (https://docs.arbitrum.io/build-decentralized-apps/token-bridging/token-bridge-erc20) and (https://docs.arbitrum.io/build-decentralized-apps/token-bridging/bridge-tokens-programmatically/how-to-bridge-tokens-custom-gateway).

## 3. CRITICAL — Does the old L1 gateway still finalize after `setGateway` redirect?

**Yes, it does. This is the fatal flaw of Option D as stated.**

`L1ArbitrumGateway.finalizeInboundTransfer` (reviewed from OffchainLabs/token-bridge-contracts):

```solidity
modifier onlyCounterpartGateway() override {
    address _inbox = inbox;
    address bridge = address(super.getBridge(_inbox));
    require(msg.sender == bridge, "NOT_FROM_BRIDGE");
    address l2ToL1Sender = super.getL2ToL1Sender(_inbox);
    require(l2ToL1Sender == counterpartGateway, "ONLY_COUNTERPART_GATEWAY");
    _;
}

function finalizeInboundTransfer(address _token, address _from, address _to, uint256 _amount, bytes calldata _data)
    public payable virtual override onlyCounterpartGateway { ... inboundEscrowTransfer(_token, _to, _amount); ... }
```

Two facts kill Option D:

1. **Finalization does NOT query the router.** The L1 gateway does not call `L1GatewayRouter.getGateway(_token)` anywhere in finalization. It only checks:
   - `msg.sender == bridge` (Outbox/Bridge),
   - `L2ToL1Sender == counterpartGateway` (its own immutable L2 counterpart).
   After passing, it blindly releases escrow by `_token` address.

2. **The L2 standard gateway's `outboundTransfer` is callable directly (not only via L2 router).** From `/private/tmp/tmp.flesh.7gbC/research/artifacts/l2gateway.json` (`L2ArbitrumGateway.outboundTransfer`):
   ```solidity
   if (isRouter(msg.sender)) { ... } else { _from = msg.sender; _extraData = _data; }
   ...
   address l2Token = calculateL2TokenAddress(_l1Token);
   require(IArbToken(l2Token).l1Address() == _l1Token, "NOT_EXPECTED_L1_TOKEN");
   _amount = outboundEscrowTransfer(l2Token, _from, _amount); // bridgeBurn
   id = triggerWithdrawal(_l1Token, _from, _to, _amount, _extraData);
   ```
   The L2 gateway computes `l2Token` via its OWN `calculateL2TokenAddress` (beacon clone pattern), not via any router mapping. As long as the old L2 DOLA's `l1Address()` returns `0x8653...` (which it does), the burn + withdrawal message succeeds. The message is sent to the L2 gateway's stored `counterpartGateway` = old L1 gateway. At the Outbox, the old L1 gateway recognizes `L2ToL1Sender == counterpartGateway` and releases escrow.

### Attack path post-setGateway (Option D as stated)
1. Anyone controlling old L2 DOLA (e.g., whoever gains Multichain MPC control) calls `L2StandardGateway.outboundTransfer(L1_DOLA, recipient, amount, 0, 0, "")` directly.
2. Old L2 DOLA burns.
3. Old L1 gateway finalizes and releases escrowed L1 DOLA to `recipient`.
4. The L1GatewayRouter mapping change is **irrelevant** to this path.

This is confirmed by architecture: the router is only used on the L1 **deposit** side (`outboundTransferCustomRefund` consults `getGateway`) and on the L2 **deposit finalization** side (via L2 router forwarding). Neither withdrawal direction consults the L1 router.

## 4. L1 escrow migration mechanics

Even if Option D were otherwise sound, escrow migration is non-trivial:

- `L1GatewayRouter._setGateways` does NOT sweep escrow. It only updates mapping and pushes a message to L2 router.
- `RegisterAndSetArbCustomGatewayAction.sol` (Arbitrum governance repo) performs `forceRegisterTokenToL2` + `setGateways`, but does **not** move escrowed tokens.
- There is no standard "escrow sweep" hook. The DAI / Sky precedent uses a **pre-deployed, shared escrow** contract reused across gateway upgrades (per Sky/USDS forum thread) — i.e., the DAI custom gateway already existed alongside canonical DAI; it did not inherit escrow from the default standard gateway.
- For DOLA, an escrow sweep would require either (a) a bespoke Arbitrum-DAO action that calls some admin function on the old L1 standard gateway to `transfer(..)` its DOLA holdings, or (b) draining via withdrawals, or (c) leaving escrow where it is and designing the new custom L1 gateway to treat the old gateway's address as its own escrow (non-standard).

Since the old L1 standard gateway has no such "sweep" admin function exposed (it is behind a proxy controlled by the same L1 Upgrade Executor, so technically *upgradable*, but that reopens the political surface Option D was trying to avoid), escrow migration is effectively an upgrade-class action.

**Net:** Option D cannot avoid touching the shared bridge infrastructure if escrow is to follow the migration. If escrow stays on the old gateway, the claim stays redeemable (see section 3).

## 5. Precedent list

1. **USDS (Sky / MakerDAO) — Constitutional AIP, under discussion as of Mar 2025.**
   - Forum: https://forum.arbitrum.foundation/t/constitutional-proposal-for-arbitrum-dao-to-register-the-sky-custom-gateway-contracts-in-the-router/28617
   - Registers Sky custom L1/L2 gateways for USDS and sUSDS via `SetGatewayAction` / `RegisterAndSetArbCustomGatewayAction`. Reuses DAI escrow pattern. Required ChainSecurity + Cantina audits + Certora. Constitutional AIP → Tally vote. Status as of last fetch: in community discussion, not yet executed. UNVERIFIED whether passed.

2. **Livepeer LPT — custom gateway deployed (live).**
   - `L1LPTGateway` / `L2LPTGateway` (per Livepeer docs, https://docs.livepeer.org/guides/delegating/bridge-lpt-to-arbitrum).
   - No AIP search hit in this session, but LPT has a live custom gateway on Arbitrum (https://etherscan.io/address/0xcEe284F754E854890e311e3280b767F80797180d is the Arbitrum core custom gateway, not LPT-specific). UNVERIFIED governance path for LPT.

3. **USDT legacy bridge disable (June 2025) — `DisableGatewayAction.sol`.**
   - Already summarized in `/private/tmp/tmp.flesh.7gbC/research/DOLA_multichain_research.md`.
   - Sets L1 gateway = `address(1)` (DISABLED sentinel). Router returns `0` for that token. Does NOT touch the old gateway's finalization path — Tether claimed the legacy bridge was already non-functional externally.
   - Most relevant negative precedent: the Arbitrum-approved flavor of "disable router for a token" does **not** block L2-initiated withdrawals; it only blocks router-mediated deposits.

4. **DAI (MakerDAO, original) — pre-existing custom gateway.** Deployed at the same time as Maker's Arbitrum integration, so no router-migration escrow question.

Common pattern: **all successful custom-gateway registrations have been for tokens that either (a) never used the standard gateway, or (b) had already migrated off it externally.** No precedent exists for redirecting an already-bridged token with material existing escrow to a new custom gateway and neutralizing the old path.

## 6. Political viability vs A/B/C

- **Option A/B (shared-infra upgrade)**: Arbitrum DAO must upgrade the default L1/L2 standard gateway or the L2 beacon implementation to add DOLA-specific handling. Precedent: hostile (sets a "we'll patch shared bridge infra for one token" line).
- **Option C (L1-side neutralization by Inverse)**: Inverse-unilateral where possible. No Arbitrum governance touch.
- **Option D (as proposed)**: one routine-looking AIP (`RegisterAndSetArbCustomGatewayAction`). BUT as demonstrated above, this does not solve the problem.
- **Option D + drain / disable old gateway for DOLA**: requires an additional bespoke action that either upgrades the old standard gateway or disables L2-initiated withdrawals for the DOLA `l1Address`. That is functionally Option A/B in a different package, with the same political weight.

## 7. Open technical questions (must resolve before any code)

1. **Can Arbitrum governance author a DOLA-scoped action on the L2 standard gateway** (e.g., add a check in `outboundEscrowTransfer` that reverts on `_l1Token == DOLA`)? This is the minimum Arbitrum-side change that makes Option D actually work. Needs audit precedent and DAO appetite — likely zero.

2. **Alternative: add the DOLA L2 token to a per-token denylist on the old L2 gateway.** Does any such hook exist? (Not visible in the L2 gateway source reviewed — no token denylist, no pause.)

3. **Could the L2 DOLA beacon (owner `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`) be upgraded to revert on `bridgeBurn`?** This is the minimum L2-token-side change, and it is an UNVERIFIED open question whether that beacon owner is the Arbitrum DAO or the Foundation. If the DAO, this is a bespoke DOLA-specific AIP. This is effectively Option A/B.

4. **Escrow sweep**: is the old L1 standard gateway (proxy admin = L1 Upgrade Executor, UNVERIFIED) upgradable to expose a one-shot `sweepToken(DOLA, newGateway)`? If yes, the compound action is tractable but still far from "routine custom gateway."

5. **Verify** `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` is the Arbitrum L1 Upgrade Executor (pattern matches; not confirmed by label).

6. **Verify** whether the USDT `DisableGatewayAction` precedent can be extended to also forcibly drain / burn on the L2 side. The audit artifact (`research/artifacts/arbitrum-upgrades.pdf`) should be reviewed — not read in this session.

7. **Custom gateway interface edge case**: the L1 router's `_setGateways` calls `TokenGateway(_gateway).calculateL2TokenAddress(L1_DOLA)` and requires non-zero. If the new L2 DOLA is a fresh deployment at a new L2 address, the new custom L1 gateway must hard-code or register that mapping *before* `setGateways` is called — hence the compound action `RegisterAndSetArbCustomGatewayAction`.

## Appendix — On-chain values (verified 2026-04-14)

| Item | Address / Value |
| --- | --- |
| L1 DOLA | `0x865377367054516e17014CcdED1e7d814EDC9ce4` |
| L1 GatewayRouter | `0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef` |
| L1 GatewayRouter.owner | `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` (L1 Upgrade Executor pattern, UNVERIFIED by label) |
| L1 GatewayRouter.getGateway(DOLA) | `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` (== default) |
| L1 escrow balance (DOLA @ standard gateway) | `1,935,010.023641...` DOLA |
| L2 DOLA | `0x6A7661795C374c0bFC635934efAddFf3A7Ee23b6` |
| L2 DOLA.l2Gateway | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` |
| L2 standard gateway.counterpart | `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` |
| L2 standard gateway.router | `0x5288c571Fd7aD117beA99bF60FE0846C4E84F933` (L2 GatewayRouter — note: message.txt linked this as "the contract to write to"; it's the L2 router, not L1) |
| Multichain router (Arb, holding stuck DOLA) | `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` |
| DOLA held at Multichain router (L2) | `1,899,702.791...` |

Note on message.txt link `https://arbiscan.io/address/0x83df9c846789fdb6fc1f34ac4ad25dd9ef704300`: this address is slightly different from the canonical L1GatewayRouter (`0x72Ce9c...`). It looks like a transcription typo in the original memo (`0x83df...704300` vs `0x72Ce...031ef`). The writeProxyContract link `0x5288c571...` is the **L2 GatewayRouter** on Arbitrum, not the L1 router — so the original memo conflated L1 and L2 router roles. The L1 router is what must be called by the DAO via `setGateways`.

## Sources

- `/private/tmp/tmp.flesh.7gbC/research/artifacts/l1router_impl.txt` (L1GatewayRouter source, verified)
- `/private/tmp/tmp.flesh.7gbC/research/artifacts/l2gateway.json` (L2ArbitrumGateway source, verified)
- `/private/tmp/tmp.flesh.7gbC/research/artifacts/dola-l1.json` (DOLA L1 source — no Arbitrum hooks)
- `/private/tmp/tmp.flesh.7gbC/research/DOLA_multichain_research.md`
- OffchainLabs/token-bridge-contracts — `L1ArbitrumGateway.sol` finalization path
- ArbitrumFoundation/governance `src/gov-action-contracts/token-bridge/` — `SetGatewayAction.sol`, `RegisterAndSetArbCustomGatewayAction.sol`, `DisableGatewayAction.sol`
- https://forum.arbitrum.foundation/t/constitutional-proposal-for-arbitrum-dao-to-register-the-sky-custom-gateway-contracts-in-the-router/28617
- https://docs.arbitrum.io/build-decentralized-apps/token-bridging/token-bridge-erc20
- On-chain calls via `https://eth.llamarpc.com` and `https://arb1.arbitrum.io/rpc` (2026-04-14)
