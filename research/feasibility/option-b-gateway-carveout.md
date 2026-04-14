# Option B — Shared L2 Standard Gateway Carve-Out for Legacy DOLA

**Date:** 2026-04-14
**Author:** Inverse research (joshua@richardson.tech)
**Scope:** Feasibility of modifying / wrapping the Arbitrum shared standard gateway so that `outboundTransfer` / `bridgeBurn` for DOLA reverts, while leaving DOLA registered to the standard gateway.

All claims marked **[UNVERIFIED]** are hypotheses pending further primary evidence. All other claims are backed by direct on-chain reads or inspected source.

---

## Summary

- Option B is **technically feasible but politically extremely unlikely**, and in practice requires the same Arbitrum-DAO-level governance surface as Option D (custom-gateway migration) without offering Option D's advantage of avoiding shared-infrastructure churn.
- The L2 standard gateway at `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` is a `TransparentUpgradeableProxy` whose admin (`0xd570aCE65C43af47101fC6250FD6fC63D1c22a86`, an OZ `ProxyAdmin`) is owned by `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827` — the Arbitrum Foundation L2 UpgradeExecutor (the same entity that owns the beacon of the L2 DOLA token itself). The L1 side (`0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`) is also a TransparentUpgradeableProxy whose ProxyAdmin (`0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa`) is owned by `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` — the Arbitrum Foundation L1 UpgradeExecutor. So both gateways are upgradeable by Arbitrum DAO governance and only by Arbitrum DAO governance.
- A per-token carve-out in these gateways changes logic used by **every** standard-bridge ERC-20. That raises the audit / risk surface dramatically vs. Option D (which only touches a router mapping — the exact pattern used for USDT / Sky / Boring) and vs. Option A (a beacon upgrade to the DOLA L2 token, which is Inverse-local only in the *token* proxy but still under Arbitrum's beacon owner).
- **Verdict:** feasible-in-principle, unattractive-in-practice. Recommend framing Option D as primary and Option A as secondary; keep Option B on the table only as a last-resort variant of Option D (with the same governance touch but broader blast radius). Do not lead with Option B.

### Political viability (rough ranking)

| Option | Arbitrum-DAO lift | Precedent | Blast radius | Actually blocks legacy redemption? |
|---|---|---|---|---|
| A (beacon upgrade of L2 DOLA token only) | Low-Medium (requires L2 UpgradeExecutor) | None found for token-beacon upgrades to neutralize a specific token | Inverse-only (DOLA L2 token logic) | Yes, if `bridgeBurn` is patched |
| **B (shared gateway carve-out)** | **High (Constitutional AIP)** | **None — all shared-gateway upgrades to date are generic, not token-specific** | **Every standard-bridge ERC-20 on Arbitrum** | Yes, if outbound path is patched |
| D (custom-gateway registration) | Medium-High (Constitutional AIP; well-established) | Yes — Sky, Boring, USDT | Router mapping only; old path remains unless combined with Option A/B-style block | Only if gated on token-side |

The user's `message.txt` notes Arbitrum is averse to precedent of "mutating balances." Option B does not mutate balances, but it modifies shared bridge mechanics for one actor's problem — which cuts against the same aversion principle.

---

## 1. L2 Gateway Upgrade Mechanics

Verified via on-chain reads against `https://arb1.arbitrum.io/rpc`:

| Slot / Call | Value |
|---|---|
| Gateway proxy | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` |
| EIP-1967 impl slot | `0x0` (not standard EIP-1967; TransparentUpgradeableProxy delegates impl reads through admin) |
| EIP-1967 admin slot | `0xd570aCE65C43af47101fC6250FD6fC63D1c22a86` |
| ProxyAdmin.getProxyImplementation(gateway) | `0x1DCf7D03574fbC7C205F41f2e116eE094a652e93` |
| ProxyAdmin.getProxyAdmin(gateway) | `0xd570aCE65C43af47101fC6250FD6fC63D1c22a86` (self) |
| ProxyAdmin.owner() | `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827` (Arbitrum L2 UpgradeExecutor) |
| `counterpartGateway()` (L1 gateway) | `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` |
| `router()` (L2 router) | `0x5288c571Fd7aD117beA99bF60FE0846C4E84F933` |

Upgrade pattern: **OZ TransparentUpgradeableProxy → OZ ProxyAdmin → Arbitrum L2 UpgradeExecutor → L2 Timelock → Arbitrum DAO governance.** The same UpgradeExecutor (`0xCF5757...A827`) also owns the L2 DOLA token's beacon (`0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`, per prior memo §"Arbitrum DOLA token upgradeability"), confirming Inverse has no local lever on either object.

To execute a carve-out, Arbitrum DAO would have to:
1. author a new `L2ERC20Gateway` implementation (or an action contract that deploys one) that special-cases `l1Address == 0x865377...9ce4`,
2. pass a Constitutional AIP because it modifies chain-owner-controlled code,
3. schedule via L2 Timelock and execute through the L2 UpgradeExecutor, which calls `ProxyAdmin.upgradeAndCall(0x09e9...EEe, newImpl, postUpgradeInit())`.

The `L2ArbitrumGateway` source already anticipates the `postUpgradeInit()` pathway — it exists and is `proxyAdmin`-only, see `L2ArbitrumGateway.sol` lines included in `l2gateway.json`.

## 2. L1 Gateway Upgrade Mechanics

Verified against `https://ethereum-rpc.publicnode.com` (llamarpc returned 502s mid-read):

| Slot / Call | Value |
|---|---|
| L1 gateway proxy | `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` |
| EIP-1967 admin slot | `0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa` |
| ProxyAdmin.owner() | `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` (Arbitrum Foundation: Upgrade Executor, per Etherscan label) |
| ProxyAdmin.getProxyImplementation(L1 gw) | `0xb4299A1F5f26fF6a98B7BA35572290C359fde900` |
| `counterpartGateway()` | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` (the L2 gateway) |
| `router()` | `0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef` (L1 GatewayRouter) |
| L1 GatewayRouter owner() | `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` (same UpgradeExecutor) |

The L1 Executor is driven by the Arbitrum L1 Timelock (`0xe6841d92b0c345144506576ec13ecf5103ac7f49`) per Etherscan transaction history. So a full carve-out requires **two coordinated upgrades** (L1 gateway + L2 gateway) both via Constitutional AIP, because otherwise an in-flight withdrawal initiated pre-upgrade could still be finalized on L1 via `finalizeInboundTransfer` on the L1 gateway. The L1 gateway `finalizeInboundTransfer` is `onlyCounterpartGateway`, so legitimate outbound from the L2 gateway maps directly to a withdraw of L1 escrow — which is exactly what must be blocked.

## 3. Scope / Blast-Radius of a Gateway Carve-Out

Key observations from `contracts/tokenbridge/arbitrum/gateway/L2ArbitrumGateway.sol` and `L2ERC20Gateway.sol` (in `l2gateway.json`):

- `outboundTransfer(l1Token, to, amount, maxGas, gasPriceBid, data)` is **one shared function** used by every standard-gateway token. A per-token revert must either:
  - check a new storage mapping `mapping(address => bool) public isBlocked;` on `L2ArbitrumGateway`, or
  - hardcode an `if (_l1Token == DOLA) revert;` branch.
- Either approach **touches logic in the hot path for every standard-bridge token on Arbitrum One** (USDC.e, LINK, many memecoins, etc.). That is much broader than what Option D requires.
- `outboundEscrowTransfer` is `virtual` and calls `IArbToken(l2Token).bridgeBurn(...)`. So a token-side block (Option A) can also achieve the goal without gateway changes; the gateway path is not the only lever.
- `finalizeInboundTransfer` (inbound to L2) would also need the same filter to prevent a deposit → auto-withdraw ping-pong from re-establishing a redeemable L1 claim. The current logic already force-withdraws if the L2 token contract is missing/invalid, so carving DOLA out of inbound must be careful to not accidentally trigger this fallback.
- The `L2ArbitrumGateway.postUpgradeInit()` is admin-only (`ProxyUtil.getProxyAdmin()`), so a storage-mapping approach is mechanically supported at upgrade time.

**Net:** per-token revert in the shared gateway requires a global-logic patch plus (preferably) a storage mapping. There is no "isolated" way to do this. Every other standard-bridge ERC-20 inherits the modified contract.

## 4. Direct-Gateway Bypass Confirmation

`L2ArbitrumGateway.outboundTransfer` (excerpt from `l2gateway.json`):

```solidity
if (isRouter(msg.sender)) {
    (_from, _extraData) = GatewayMessageHandler.parseFromRouterToGateway(_data);
} else {
    _from = msg.sender;
    _extraData = _data;
}
```

`isRouter(_target)` is `return _target == router;` (from `TokenGateway.sol`). Critically the function itself is **public**, not `routerOnly`. A caller that is not the router is accepted and `_from = msg.sender`. So a legacy DOLA holder can call the L2 gateway directly, skipping the router entirely, and still reach `IArbToken(l2Token).bridgeBurn(_from, _amount)` → `createOutboundTx` → L1 withdrawal message.

On the L1 side, `finalizeInboundTransfer` is gated only by `onlyCounterpartGateway` (verified via WebSearch of OffchainLabs token-bridge-contracts and Trust-Security / c4 audit references). It does **not** verify that the original L2 caller went through the router. Thus a router-only disable (the USDT-style `DisableGatewayAction`, which sets `l1TokenToGateway[DOLA] = address(1)` → router returns `address(0)`) is insufficient: the legacy path `direct L2 gateway call → bridgeBurn → L1 finalize` still works end-to-end.

This confirms the research memo's assertion (§"L2 gateway behavior") and is the key reason Option B (gateway logic patch) or Option A (token-side `bridgeBurn` patch) is needed, not just router disable.

## 5. Precedent

Searched Arbitrum forum and governance repo for prior shared-gateway per-token modifications.

- **USDT "Disable Legacy Tether Bridge"** (AIP, June 2025, forum thread 29503): operates on `L1GatewayRouter` via `setGateways(...)` with sentinel `address(1)`. Does **not** modify the shared L1 or L2 gateway contracts. Applied only after Tether had already externally migrated to USDT0. [UNVERIFIED FINAL STATUS — thread marked for Snapshot; assumed passed given the Arbitrum docs' security-review publication.]
- **Sky custom gateway registration** (Constitutional proposal, forum thread 28617): router-level `setGateway` call to point `l1TokenToGateway[SKY]` at Sky's own custom gateway. Shared standard gateway code untouched.
- **Boring custom gateway registration** (Constitutional proposal, forum thread 29206): same pattern as Sky. Router-level only.
- **Standard gateway implementation upgrades** historically have been generic (e.g., post-Nitro-migration refactors, the `postUpgradeInit` hook) — **not** token-specific. No public proposal found that hardcodes a per-token filter into the shared gateway.

In short: **no precedent exists for a per-token carve-out inside the shared L1/L2 standard gateway itself.** This makes Option B a governance first-of-its-kind, which cuts against its political viability.

## 6. Comparison vs Option D

| Axis | Option B (gateway carve-out) | Option D (custom-gateway migration) |
|---|---|---|
| Arbitrum governance action | Constitutional AIP to upgrade two shared gateway implementations | Constitutional AIP to `setGateway(DOLA, <new custom GW>)` on router |
| Blast radius | Every standard-bridge ERC-20 (logic path shared) | Only DOLA's router mapping changes |
| Does it stop legacy redemption by itself? | Yes (assuming both L1 and L2 sides patched, with reentry/inflight guards) | **No** — legacy holders can still call the old L2 gateway directly (see §4) |
| Code audit surface | New logic in both L1ERC20Gateway and L2ERC20Gateway implementations | New gateway pair (Inverse-controlled), no change to Arbitrum core code |
| Precedent? | None found | Sky, Boring, USDT (router mechanic) |
| Recovery of trapped funds (the separate problem) | Doesn't help — just prevents further redemption | Doesn't help either; both options are about neutralizing the live claim, not retrieving the stuck balance |

**Key insight:** Option D *alone* does not close the direct-gateway bypass. To close the loop with Option D, Inverse still needs either (a) an L2-DOLA `bridgeBurn` patch (effectively Option A on the token), or (b) an L1-gateway patch that refuses `finalizeInboundTransfer` for DOLA from the *old* L2 counterpart (effectively half of Option B). That means **Option D only works when paired with a token-side or gateway-side block** — which brings us back to Option A (beacon upgrade on L2 DOLA token) as the lightest sufficient add-on.

Therefore the cleanest theoretical path is **A alone or A+D**, not B. B is only attractive if Arbitrum will *not* touch the token beacon (unlikely since they own it) and *will* touch the shared gateway (very unlikely).

## 7. Open Questions

1. **[UNVERIFIED]** Does the Arbitrum Foundation have a stated policy against token-specific logic in shared gateway contracts? Forum search did not surface an explicit one, but the absence of precedent is strong. Worth asking in a forum temp-check post before proposing B.
2. **[UNVERIFIED]** Is there any pre-existing in-flight withdrawal for DOLA in the Outbox (i.e., an already-initiated L2→L1 message that's past challenge window)? If so, even a post-upgrade L1 block wouldn't prevent finalization of messages already committed to the rollup state. Needs a scan of `L2ArbSys`/`Outbox` events for `0x6a7661795c374c0bfc635934efaddff3a7ee23b6` withdrawals. Multichain has been defunct for years so this may be low-risk but should be confirmed.
3. **[UNVERIFIED]** Would the L2 UpgradeExecutor accept a DOLA-only postUpgradeInit that installs a mapping entry without replacing the implementation? Rechecking `postUpgradeInit` in the current deployed impl would tell us; the source we have only shows `require(msg.sender == proxyAdmin)` and no storage writes, meaning any change still requires a new implementation contract.
4. **[UNVERIFIED]** Could Option A alone (beacon upgrade to L2 DOLA token making `bridgeBurn` revert for the Multichain router address, or globally) satisfy the requirement while avoiding shared-gateway changes? Almost certainly yes — and it has a smaller blast radius than B. This pushes Option A ahead of Option B on a technical basis.
5. **[UNVERIFIED]** Does the L1 gateway implementation at `0xb4299A1F5f26fF6a98B7BA35572290C359fde900` match the GitHub `L1ERC20Gateway.sol` version we assumed, or a later variant with additional hooks? Would need to fetch verified source from Etherscan (blocked by 403 in this run).

---

## Sources

### On-chain (primary)
- L2 gateway (Arbitrum): https://arb1.arbitrum.io/rpc — slots and `counterpartGateway()`, `router()` reads on `0x09e9222E96E7B4AE2a407B98d48e330053351EEe`
- L2 ProxyAdmin: `0xd570aCE65C43af47101fC6250FD6fC63D1c22a86`; owner `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`
- L1 gateway (Ethereum): https://ethereum-rpc.publicnode.com — `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`
- L1 ProxyAdmin: `0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa`; owner `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` (Arbitrum Foundation: Upgrade Executor, Etherscan label)

### Source artifacts (local)
- `research/artifacts/l2gateway.json` — verified Etherscan JSON multi-source bundle for L2 gateway impl (`L2ArbitrumGateway.sol`, `L2ERC20Gateway.sol`, `TokenGateway.sol`)
- `research/artifacts/l1router_impl.txt` — `L1GatewayRouter.sol` source confirming `setGateways` / router-level mechanic
- `research/DOLA_multichain_research.md` — prior memo documenting direct-gateway bypass and balance figures
- `research/artifacts/arbitrum-upgrades.pdf` — Trail of Bits "Offchain Labs Arbitrum Upgrades" summary (Jan 2024), confirming governance upgrade machinery

### External
- OffchainLabs `token-bridge-contracts` (GitHub): `L2ArbitrumGateway.sol`, `L1ERC20Gateway.sol`, `L1CustomGateway.sol`
- Arbitrum docs: ERC-20 token bridging; generic-custom gateway flow
- Arbitrum forum: thread 29503 (USDT disable), thread 28617 (Sky custom gateway), thread 29206 (Boring custom gateway)
- Etherscan label lookup: `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` = "Arbitrum Foundation: Upgrade Executor" (driven by L1 Timelock `0xe6841d92b0c345144506576ec13ecf5103ac7f49`)
