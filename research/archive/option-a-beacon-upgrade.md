# SUPERSEDED: Option A - Beacon Implementation Upgrade

> Historical working memo. See `../TECHNICAL_OPTIONS.md`.

**Date:** 2026-04-14
**Author:** research agent
**Scope:** Feasibility of upgrading the Arbitrum `StandardArbERC20` beacon implementation to neutralize the ~1.9M DOLA balance held by the defunct Multichain router at `0x0615dbba33fe61a31c7ed131bda6655ed76748b1`, as a component of the DOLA recovery plan.

---

## 1. Summary (verdict)

| Dimension | Verdict |
|---|---|
| Technically possible in principle | Yes — the beacon is upgradeable. |
| Technically scoped to DOLA only | **No.** The beacon is **shared across many (likely all) non-custom `StandardArbERC20` bridge tokens on Arbitrum One.** Upgrading it affects every standard-bridged token, not just DOLA. |
| Governance path | Arbitrum DAO Constitutional AIP through the L1 Timelock (3-day + 12.8-day delays) → L1 UpgradeExecutor → retro-call into L2 UpgradeExecutor, **OR** Arbitrum Security Council (9/12 emergency action). In both cases the **L2 UpgradeExecutor `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`** is the calling contract that owns the beacon. |
| Politically viable | **Low.** Arbitrum DAO has never upgraded this beacon under DAO governance (last upgrade Oct 2021, pre-DAO). The ask is to fork the behavior of a shared token logic contract for the exclusive benefit of one third-party protocol whose problem was caused by a now-defunct off-chain bridge. USDT's `DisableGatewayAction` is not a precedent for this — it modified a router mapping, not a shared token implementation. |
| Storage-layout risk | High to all other tokens sharing the beacon. Any new implementation must be strictly append-only relative to the current `StandardArbERC20` layout (`aeERC20` → `L2GatewayToken` → `StandardArbERC20`). A bug would corrupt every token using the beacon. |
| Recommendation | Do not pursue A1 (balance wipe). A2 (burn-guard) is even more invasive than A1 semantically (adds per-address logic to shared code). Both should be deprioritized relative to a DOLA-specific custom gateway path, unless Arbitrum has privately signaled openness. |

**Bottom-line:** Option A is not a realistic path. The beacon is shared infrastructure, the DAO has no precedent for per-token implementation forks, and the same protective effect is achievable through paths that do not require touching shared code (custom gateway registration + token migration, with economic deprecation of the legacy supply).

---

## 2. Beacon ownership & governance path

All addresses verified on Arbitrum One at `https://arb1.arbitrum.io/rpc` on 2026-04-14.

### 2.1 Direct chain

1. **Arbitrum DOLA token (proxy):** `0x6a7661795c374c0bfc635934efaddff3a7ee23b6`
   - EIP-1967 beacon slot points to: `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`
2. **Beacon (`UpgradeableBeacon`):** `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`
   - `implementation()` → `0x3f770Ac673856F105b586bb393d122721265aD46` (`StandardArbERC20`)
   - `owner()` → `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`
3. **Beacon owner:** `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`
   - Labelled on Arbiscan as **"Arbitrum Foundation: Upgrade Executor"** (the L2 `UpgradeExecutor`).
   - Is itself a `TransparentUpgradeableProxy`:
     - EIP-1967 impl slot → `0x3d745b8815f9be5bf053858165f8ab1f58c77932`
     - EIP-1967 admin slot → `0xdb216562328215E010F819B5aBe947bad4ca961e` (`ProxyAdmin`)
   - That `ProxyAdmin.owner()` returns `0xCF57...A827` (self-admin loop, typical for the UpgradeExecutor pattern).

### 2.2 UpgradeExecutor role holders (from `RoleGranted` / `RoleRevoked` event history)

`EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE") = 0xd8aa0f31...51469e63`

Current active EXECUTOR_ROLE holders on `0xCF57...A827`:

| Address | Identity | How it reaches the executor |
|---|---|---|
| `0xf7951d92b0c345144506576ec13ecf5103ac905a` | **L2 alias of L1 Timelock** `0xE6841D92...03aC7f49` (`alias = L1 + 0x1111...1111`; verified by arithmetic) | DAO proposal → L2 Core Governor → L2 Core Timelock (3-day) → L2→L1 outbox → L1 Timelock (3-day) → L1 UpgradeExecutor → `retryableTicket` to L2 → aliased sender on L2 calls the L2 UpgradeExecutor. End-to-end ~12.8 day minimum finality window. |
| `0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641` | **Arbitrum Foundation: L1 Security Council 9** (9-of-12 Gnosis Safe, mirrored on L2) — granted at block 132049587, replacing the earlier council address `0x3568a44b3e72f5b17a0e14e53fdb7366b3b7ad13` which was revoked in the same tx. | Security Council can call UpgradeExecutor directly without timelock delay (emergency path). |

So: the **beacon owner can only be moved by either** (a) a successful Constitutional AIP all the way through the DAO + L1 Timelock + crosschain retryable ticket, or (b) a 9/12 Security Council emergency action. There is no Offchain Labs multisig path distinct from these.

**For Option A specifically:** this is **not a Security Council use case** (it's not an emergency protocol vulnerability in Arbitrum). It would require a full Constitutional AIP and DAO vote with both the 3-day L2 timelock and the 3-day L1 timelock plus the 12.8-day constitutional delay — months of governance process minimum.

### 2.3 Sources

- https://arbiscan.io/address/0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827 (labelled "Arbitrum Foundation: Upgrade Executor")
- https://arbiscan.io/address/0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641 (labelled "Arbitrum Foundation: L1 Security Council 9")
- https://etherscan.io/address/0xE6841D92B0C345144506576eC13ECf5103aC7f49 (labelled "Arbitrum Foundation: L1 Timelock")
- https://github.com/ArbitrumFoundation/governance/blob/main/docs/overview.md (governance topology)

---

## 3. Beacon scope: shared or DOLA-specific?

**Shared.** Confirmed on-chain.

Spot-checked three other Arbitrum tokens by reading the EIP-1967 beacon slot (`0xa3f0ad74...33d50`) of each proxy:

| Token | Address | Beacon slot |
|---|---|---|
| DOLA | `0x6a7661795c374c0bfc635934efaddff3a7ee23b6` | `0xe72ba9...37333` ✓ |
| GRT (Arbitrum) | `0x23a941036ae778ac51ab04cea08ed6e2fe103614` | `0xe72ba9...37333` ✓ |
| CELR (Arbitrum) | `0x3a8b787f78d775aecfeea15706d4221b40f345ab` | `0xe72ba9...37333` ✓ |
| FXS (Arbitrum, custom) | `0x9d2f299715d94d8a7e6f5eaa8e654e8c74a988a7` | `0x00` (not a beacon proxy — custom gateway / non-standard) |
| WETH (`0xfc5a1...`) | — | `0x00` (custom) |

The beacon is the `BeaconProxyFactory` beacon used by the L2 `L2ERC20Gateway` (`0x09e9222E96E7B4AE2a407B98d48e330053351EEe`, Arbitrum's standard L2 ERC-20 gateway) when it deploys new standard bridge-minted tokens. Any project that used the default standard bridge (rather than registering a custom gateway) got a proxy pointing at this beacon.

**Implication for Option A:** upgrading the beacon changes logic for *every* standard-bridge token on Arbitrum One simultaneously. Any DOLA-specific logic (e.g. `if (from == 0x0615dbba...) revert;`) added to the shared implementation would live in the logic contract used by dozens of other tokens. The DAO has extremely strong reason to refuse this: introducing per-address logic in a shared upgradeable beacon is a blast radius problem. A bug, or a precedent-setting fork, could affect the entire tail of Arbitrum tokens.

### 3.1 Beacon upgrade history

Only two `Upgraded(address)` events have ever been emitted by the beacon:

| Block | Date | New impl |
|---|---|---|
| 226787 | 2021-08-30 | `0xb4d1650bb950a7551a1500903181b77118d81826` |
| 2455378 | 2021-10-22 | `0x3f770Ac673856F105b586bb393d122721265aD46` *(current)* |

Both upgrades predate Arbitrum DAO launch (March 2023). The beacon has **never** been touched under DAO governance. A DOLA-motivated upgrade would be the first DAO-authorized upgrade to this shared beacon in Arbitrum's history. This is a significant political bar.

---

## 4. Storage layout notes

Current implementation `0x3f770Ac673856F105b586bb393d122721265aD46` is `StandardArbERC20`, with this inheritance (from `OffchainLabs/token-bridge-contracts`):

```
StandardArbERC20
  ├── L2GatewayToken
  │     └── aeERC20  (upgradeable ERC20 + ERC20Permit variant)
  └── Cloneable
```

Verified state (slot 0 of DOLA proxy = `0x01`, consistent with an `_initialized` flag at slot 0 from `Initializable`, plus the ERC20 mappings hashed into later slots).

Declared state variables:
- `L2GatewayToken`: `address public l2Gateway`; `address public override l1Address`;
- `StandardArbERC20`: `struct ERC20Getters { bool ignoreDecimals; bool ignoreName; bool ignoreSymbol; } ERC20Getters private availableGetters;`
- `aeERC20` parents: standard OZ upgradeable ERC20 storage (`_balances`, `_allowances`, `_totalSupply`, `_name`, `_symbol`, plus `Initializable` flags, plus `ERC20Permit` nonces/domainSeparator cache).
- `Cloneable`: small marker / init state.

**Safety requirements for any A1/A2 replacement implementation:**

1. New implementation must preserve the *exact* storage layout of the current one. Any reordering, deletion, or type-change of an existing slot would corrupt every token proxy using the beacon (DOLA, GRT, CELR, and all other standard-bridge tokens).
2. Appended variables are allowed at the tail, but appending is risky across a shared beacon because future Arbitrum upgrades to `StandardArbERC20` would have to accommodate the appendage.
3. An A1 "wipe on first call" approach is particularly hazardous: balance wipes affect every proxy that observes the first-call trigger, not just DOLA, unless the wipe is gated on `address(this)` equaling the DOLA proxy — which then hard-codes a single token's address into shared logic, which is exactly the anti-pattern Arbitrum DAO would reject.
4. A2 "burn-guard" (reverting `bridgeBurn` when `from == multichainRouter`) has the same shared-code problem: the logic would live in the code path for every standard-bridge token's burn; reviewers have to reason about side effects for dozens of tokens.

The storage layout itself is not a blocker (it is well-known and OZ-standard). The blocker is **what logic you can add without corrupting semantics for unrelated tokens**.

---

## 5. Precedent analysis

### 5.1 USDT `DisableGatewayAction` (the commonly cited precedent)

- **What it did:** set the L1 router's per-token gateway mapping to the sentinel `address(1)` (`DISABLED`), causing `getGateway()` to return `address(0)` and router-mediated bridging to revert.
- **What it did *not* do:** upgrade a token implementation, modify any shared beacon, touch balances, or change L2 token logic.
- **Context:** Tether had already migrated to USDT0 externally; the legacy path was already known-broken. The DAO was formalizing deprecation of a dead router entry.
- **Scope:** one targeted router entry. Zero shared-infrastructure implementation change.

This precedent supports a different, narrower ask (a DOLA-specific router/gateway change). It does **not** support Option A.

### 5.2 Searches for beacon-implementation upgrades under DAO governance

- On-chain: the beacon `0xe72ba9...37333` has had only two `Upgraded` events, both pre-DAO (2021-08 and 2021-10). No DAO-era upgrades.
- Governance repo (`github.com/ArbitrumFoundation/governance`): the `gov-action-contracts/token-bridge/` subdirectory contains `DisableGatewayAction.sol` and related gateway-routing actions. There are no action contracts that upgrade the `StandardArbERC20` beacon implementation, and there is no AIP I could identify that proposes per-token modifications to shared bridge-token logic.
- Forum (`forum.arbitrum.foundation`): the Tether-legacy-bridge proposal is the only bridge-offboarding precedent. Other token-specific interventions I could find are at the router/gateway layer, not the token-logic layer.

**Net:** there is **no precedent** for upgrading the `StandardArbERC20` beacon under DAO governance. Option A would set that precedent.

### 5.3 Why that matters beyond optics

The beacon is the single logic contract behind a long tail of Arbitrum tokens. The DAO has every reason to treat it as "change-control frozen" except for genuinely cross-ecosystem reasons (fixing a security bug in all standard-bridge tokens, adopting a new ERC-20 extension, etc.). Using it as a lever to extinguish one project's stranded balance would:

- Invite future requests from other protocols with their own stranded-balance problems.
- Establish that Arbitrum DAO is willing to change balances / transferability of tokens held by specific addresses in the shared bridge. This is a reputational / censorship-resistance concern for the whole chain.
- Increase audit burden for every subsequent routine beacon upgrade, since reviewers must now verify that no per-address logic from prior interventions has silently broken.

The DAO is very likely to view these costs as disqualifying.

---

## 6. Political viability assessment

**Estimate: Low.**

Reasoning:

1. **No precedent.** No DAO-era beacon upgrade, no per-token implementation fork, nothing remotely comparable has been approved.
2. **Blast radius.** The ask requires the DAO to accept shared-infrastructure modification for one third party's benefit. The math of "risk to all tokens vs. benefit to one protocol" is unfavorable unless Inverse can show cross-ecosystem benefit (it cannot — the problem is specific to DOLA and its Multichain router).
3. **Alternative exists.** A DOLA-specific custom-gateway migration (plus economic deprecation and reissuance designed to tolerate any later movement of the legacy supply) is available and does not require touching shared code. Any reasonable DAO delegate will push Inverse toward the narrower intervention.
4. **Governance timeline.** Even if favored, a Constitutional AIP takes ~12.8 days minimum plus ≥3-day L1 timelock plus retryable-ticket execution, on top of the forum RFC → Snapshot temp-check → Tally on-chain vote cadence. Realistically 2–4 months assuming no opposition; longer assuming normal debate.
5. **Signalling from Offchain Labs historically.** Offchain Labs has been consistent that token-level balance interventions are outside the canonical bridge's remit. The original user memo (`message.txt`) described the ask as "highly doubtful" for the same reason.
6. **Security Council path is not applicable.** The Security Council is scoped to chain-security emergencies. A third-party bridge's stranded balance is not in scope, and the Council is unlikely to act unilaterally on a matter that has a normal (albeit slow) DAO pathway.

A generous revision: **low-to-very-low.** I would not assign >5–10% probability of approval, conditional on Inverse spending substantial engineering and governance effort.

---

## 7. Specific verdict on A1 vs A2

**A1 — balance wipe on first call / initializer:**
- Requires either (a) hard-coding DOLA's proxy address into the shared implementation (unacceptable precedent), or (b) a generic "wipe balance at X address" hook triggered somehow (even worse, introduces a primitive the DAO definitely will not accept in shared code).
- Decrements `totalSupply` on first call; interaction with `aeERC20` invariants must be proven safe for all tokens sharing the beacon.
- Verdict: **infeasible politically; technically hostile to shared-code contracts.**

**A2 — burn-guard:**
- Adds `if (from == multichainRouter) revert;` or similar in `bridgeBurn`.
- Still hard-codes a single address into code shared by all standard-bridge tokens.
- Does not remove the dangerous balance; merely prevents one particular withdrawal path. Any contract that ever gained `approve` from the router could still transfer out and burn from a fresh address. (Not applicable today, but non-zero-effort to verify permanently.)
- Verdict: **slightly less invasive than A1 semantically, but still requires per-token logic in shared code; same political barriers; does not fully solve the threat model.**

Neither sub-variant is a clean cut of scope.

---

## 8. Open questions for user / Arbitrum team

1. Has Inverse made any informal outreach to Offchain Labs, Arbitrum Foundation, or Security Council members about this class of intervention? Private signals could raise or lower the probability estimate substantially; current estimate assumes cold approach.
2. Is there a DOLA-specific custom gateway / token migration path already scoped that does not require touching the shared beacon? (The user's own prior memo implies yes — `setGateway()` via `0x5288c571Fd7aD117beA99bF60FE0846C4E84F933` on L1, with DAO cooperation.) If so, Option A is strictly worse than that alternative for the same DAO approval cost.
3. Is there a plausible reissuance structure on L1 DOLA that accepts the legacy Arbitrum claim being live, e.g. minting only amounts net of the trapped router balance, or using an escrow-contingent claim that unwinds if the router balance ever moves? That avoids the need to neutralize Option A's target entirely.
4. If Arbitrum indicates willingness to act, would they prefer the intervention at the **L2 gateway** layer (change `L2ERC20Gateway` behavior for DOLA only, via a custom-gateway retarget) rather than at the token implementation? That is substantially more targeted and does not touch the beacon.
5. Are there any prior Arbitrum forum threads we missed in which a project requested per-token beacon changes? Worth a deeper search before concluding "no precedent."
6. **Unverified:** I could not access Arbiscan via WebFetch (403). All address labels are from Arbiscan search-result snippets via WebSearch and from the Arbitrum Foundation docs. The core role-holder and beacon-ownership findings are direct on-chain reads and are solid; the *labels* are secondary.

---

## Appendix A — Concrete governance path if the DAO were to approve

For completeness, the end-to-end action a DOLA-motivated AIP would have to execute:

1. Inverse drafts, deploys, and audits a new `StandardArbERC20V2` implementation that includes a DOLA-specific `bridgeBurn` guard (A2) keyed on the Multichain router address.
2. Inverse drafts an `UpgradeAction` (Solidity) that calls `UpgradeableBeacon(0xe72ba9...).upgradeTo(newImpl)`.
3. Forum RFC → Snapshot temp-check → Tally on-chain Constitutional AIP vote (≥5% turnout, supermajority for constitutional).
4. If passed: L2 Core Governor → L2 Core Timelock (3 day) → outbox message to L1 Timelock.
5. L1 Timelock (3 day) → L1 UpgradeExecutor.
6. L1 UpgradeExecutor `createRetryableTicket` to L2 UpgradeExecutor `0xCF57...A827`, which calls `UpgradeAction.perform()`, which calls `beacon.upgradeTo(newImpl)`.
7. The retryable must be redeemed on L2; one block later all standard-bridge tokens use the new logic.

Plus any post-deploy token-specific bookkeeping (e.g. emitting `Transfer(router, 0, X)` for indexers if the logic wipes balance).

Minimum wall-clock from formal vote start to execution: ~20–30 days. Realistic wall-clock including temp-check and discussion: ~2–4 months.

---

## Appendix B — Key addresses (Arbitrum One unless noted)

| Label | Address |
|---|---|
| DOLA token (L2 proxy) | `0x6a7661795c374c0bfc635934efaddff3a7ee23b6` |
| DOLA token (L1 canonical) | `0x865377367054516e17014CcdED1e7d814EDC9ce4` (Ethereum) |
| Multichain router (stranded ~1.9M DOLA) | `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` |
| L2ERC20Gateway (standard) | `0x09e9222E96E7B4AE2a407B98d48e330053351EEe` |
| StandardArbERC20 beacon | `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333` |
| Current beacon impl | `0x3f770Ac673856F105b586bb393d122721265aD46` |
| **Beacon owner (L2 UpgradeExecutor)** | `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827` |
| L2 UpgradeExecutor impl | `0x3d745b8815f9be5bf053858165f8ab1f58c77932` |
| L2 UpgradeExecutor ProxyAdmin | `0xdb216562328215E010F819B5aBe947bad4ca961e` |
| EXECUTOR_ROLE holder: L1 Timelock (L2 alias) | `0xf7951d92b0c345144506576ec13ecf5103ac905a` |
| EXECUTOR_ROLE holder: L1 Security Council 9 (L2) | `0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641` |
| L1 Timelock (Ethereum) | `0xE6841D92B0C345144506576eC13ECf5103aC7f49` |
| Example of sibling token sharing the beacon (GRT) | `0x23a941036ae778ac51ab04cea08ed6e2fe103614` |
| Example of sibling token sharing the beacon (CELR) | `0x3a8b787f78d775aecfeea15706d4221b40f345ab` |
