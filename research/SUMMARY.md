# DOLA / Multichain-Arbitrum Recovery — Consolidated Research Summary

**Date:** 2026-04-14
**Audience:** Inverse Finance internal (working group + DAO-facing delegates)
**Status:** Synthesis of all research to date. Supersedes individual memos for decision-making; memos remain authoritative on primary sources.

---

## 1. Executive summary

Multichain's 2023 collapse left approximately 1,899,703 DOLA (the Arbitrum canonical `StandardArbERC20` representation at `0x6a7661795c374c0bfc635934efaddff3a7ee23b6`) stranded in Multichain's Arbitrum router at `0x0615dbba33fe61a31c7ed131bda6655ed76748b1`. That L2 balance is a live, fully-collateralized claim on the 1,935,010 DOLA escrowed at Arbitrum's L1 StandardERC20Gateway (`0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`). Because the L2 burn-and-withdraw path is accessible to anyone who controls the Multichain router's DOLA, any later reanimation of Multichain's signer set — by remaining operators, a liquidator, or an attacker — can drain the L1 escrow. If Inverse reissues DOLA to the BSC wrapper holders (`0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840`, supply 1,793,864) before that L2 claim is neutralized, the protocol faces a double-claim against L1 DOLA that is not funded from any Inverse reserve. [DOLA_multichain_research.md; option-c-l1-escrow-neutralization.md]

The research set evaluated four onchain paths. Three are dead on technical grounds:
- **Option A (shared L2 beacon upgrade):** possible only by changing the `StandardArbERC20` logic contract shared by every standard-bridge token on Arbitrum; blast radius is unacceptable, and a per-proxy beacon rewrite for DOLA alone is cryptographically impossible — the `ClonableBeaconProxy` has no admin, no setter, and no runtime path that writes the beacon slot. [option-a-beacon-upgrade.md; spike-upgradeexecutor-beacon.md]
- **Option C (L1-only unilateral action):** L1 DOLA is an immutable 0.5.16 ERC20 with no pause, blacklist, admin transfer, or upgrade mechanism; the operator can only mint. A full L1 token migration is possible but catastrophic to every DOLA integration (FiRM, Feds, Curve/Balancer pools, CEXes, cross-chain representations). [option-c-l1-escrow-neutralization.md]
- **Option D (custom-gateway migration alone):** independently verified insufficient. `L1ArbitrumGateway.finalizeInboundTransfer` is guarded only by `onlyCounterpartGateway` and never consults the router; `L2ArbitrumGateway.outboundTransfer` is public, not router-gated. A legacy holder can call the old L2 gateway directly, burn, and finalize against the old L1 gateway regardless of any router remap. [option-d-custom-gateway.md; verify-bypass.md]

**The one surviving technical path is a `ProxyUpgradeAction`-style upgrade of the legacy L1 StandardERC20Gateway (and ideally its L2 mirror) to refuse `finalizeInboundTransfer` / `outboundTransfer` when `_l1Token == DOLA_L1`.** This is a Constitutional AIP on the Arbitrum DAO that modifies shared bridge infrastructure for one dead token. Realistic odds of passage, on the research as it stands: approximately 15–25%. The routine `setGateway` half (custom gateway for legitimate holders) is ~85–95%; the bespoke gateway-surgery half is ~15–30%; the joint proposal is dominated by the harder component. [precedent-discourse.md; governance.md; verify-disablegatewayaction.md]

Why the odds are poor, in order of weight:
1. **No precedent for per-token logic in shared bridge infrastructure.** Boring, Sky, and RARI were router-mapping operations on active protocols with zero pre-existing escrow. USDT's `DisableGatewayAction` was a router-only cleanup of a path Tether had already bricked eight months earlier via an OFT upgrade. None of these touched shared L1/L2 gateway implementations to introduce a per-token revert, and none handled pre-existing standard-gateway escrow controlled by a malicious holder. [precedent-discourse.md; verify-disablegatewayaction.md]
2. **Shared infrastructure, asymmetric risk.** The legacy L1/L2 standard gateways escrow and mint for a long tail of tokens. Delegates must weigh systemic risk across every standard-bridge token against benefit to one protocol whose underlying problem is an off-chain bridge failure.
3. **Precedent risk framing.** "If you'll patch the gateway for DOLA, who's next?" There are many dead bridges and stranded balances. The DAO has strong systemic reasons to refuse the first such request.
4. **Novel malicious-holder frame.** Delegate discussion in Boring and Sky never engaged with an adversarial-holder scenario. It is untested territory.

**Implied recommendation:** only commit to a 4–5 month Constitutional AIP if Inverse first pre-wires Offchain Labs engineering, the Arbitrum Foundation, L2BEAT (krst), and the major delegate blocs (Gauntlet, StableLab, Blockworks, Lampros, Tane) and receives credible private signals that a bespoke gateway upgrade is entertain-able. Frame the ask as maximally scoped — one conditional, one token, one dead bridge — and tonally endorse the Maintenance Upgrades Working Group. Fund ChainSecurity + Cantina audits and plan for at least one payload-correction cycle.

---

## 2. The problem

- **DOLA canonical issuance:** L1 DOLA at `0x865377367054516e17014CcdED1e7d814EDC9ce4` is a single-contract, Solidity 0.5.16 ERC-20. `operator()` = Inverse Treasury `0x926dF14a23BE491164dCF93f4c468A50ef659D5B`. Operator can `addMinter` / `removeMinter` / `mint`; cannot pause, blacklist, seize, or upgrade. Contract is immutable. [option-c-l1-escrow-neutralization.md §1]
- **Multichain-BSC victim set:** BSC DOLA wrapper `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840` is `AnyswapV6ERC20` with `underlying() = 0x0`, `vault() = owner() = 0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7`. `totalSupply = 1,793,864.391064841026826353`. Not redeemable against any locked collateral on BSC. [DOLA_multichain_research.md §1, §3]
- **Trapped Arbitrum balance:** L2 DOLA `totalSupply = 1,935,009.923641336370430383`; Multichain router balance on Arbitrum = `1,899,702.791056052107486162`. Remaining legitimate L2 holders hold `35,307.132585284262944221` across all other addresses. [DOLA_multichain_research.md §4–6]
- **L1 escrow, fully collateralized:** L1 DOLA balance at the standard gateway `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` = `1,935,010.023641...`, matching L2 supply within ~0.1 rounding. Every L2 DOLA has a matching L1 claim; the escrow is large enough to fully service a double-claim. [option-c-l1-escrow-neutralization.md §2]
- **Double-claim mechanics:** if Inverse reissues DOLA to BSC victims and the Multichain router's 1.9M L2 DOLA later burns through the Arbitrum canonical bridge, the protocol has honored both claims. Inverse DAO's stated standard does not tolerate this. [DOLA_multichain_research.md §"Double-claim / bad-debt logic"]
- **Victim chains beyond BSC:** unverified — Fantom, Polygon, Moonriver, Avalanche, Optimism all had Multichain support during DOLA's active period. Snapshot must enumerate before reissuance. [governance.md §2.4]

---

## 3. Technical options considered

| Option | Thesis | Verdict |
|---|---|---|
| A — Shared `StandardArbERC20` beacon upgrade | Upgrade shared token logic to revert DOLA burns, or wipe the router balance | **Dead.** Shared logic; per-proxy rewrite is cryptographically impossible; blast radius to all standard-bridge tokens |
| B — Shared L2/L1 gateway carve-out | Patch `L2ArbitrumGateway` / `L1ArbitrumGateway` to revert on DOLA | **Technically viable, politically least favored.** Hot path touches every standard-bridge ERC-20 |
| C — L1-only unilateral neutralization | Drain escrow, blacklist transfers, or migrate L1 DOLA | **Dead** except C3 (full migration), which is catastrophic to every DOLA integration |
| D — Custom-gateway migration alone | `setGateway(DOLA, newCustomGateway)` via router | **Necessary but insufficient.** Router is not consulted on the hot path; old L2 gateway direct call still works |
| **A+D or B+D (compound)** | Pair legacy gateway/token freeze with custom gateway for legit holders | **Only surviving path.** Legacy L1 gateway `ProxyUpgradeAction` with DOLA-scoped revert |

### 3.1 Option A — Beacon upgrade

The L2 DOLA proxy is a `ClonableBeaconProxy` pointing at beacon `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`, owner `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827` (L2 UpgradeExecutor). The beacon is shared: GRT (`0x23a941036ae778ac51ab04cea08ed6e2fe103614`) and CELR (`0x3a8b787f78d775aecfeea15706d4221b40f345ab`) are confirmed co-tenants. Any logic change to the beacon implementation applies to every standard-bridge token. The spike work confirms the DOLA proxy itself has no admin, no setter, and no runtime path that writes the EIP-1967 beacon slot — per-token beacon rewrite is impossible even with full UpgradeExecutor cooperation. A DOLA-conditional branch inside the shared implementation is possible but hard-codes one token's address into shared code, which is exactly the pattern the DAO should (and will) refuse. [option-a-beacon-upgrade.md §1–6; spike-upgradeexecutor-beacon.md §2–3]

### 3.2 Option B — Shared gateway carve-out

Both the L2 gateway (`0x09e9222E96E7B4AE2a407B98d48e330053351EEe`, admin `ProxyAdmin 0xd570aCE65C43af47101fC6250FD6fC63D1c22a86`, owner `0xCF57...A827`) and the L1 gateway (`0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`, admin `ProxyAdmin 0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa`, owner `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd` — the L1 UpgradeExecutor) are transparent-proxy-upgradeable by Arbitrum DAO. A patched implementation that `require(_l1Token != DOLA_L1)` in `outboundTransfer` / `finalizeInboundTransfer` is technically straightforward. The code change is small; the audit/review risk is that every standard-bridge token executes through the same patched logic. No prior AIP has added per-token filters to shared gateway code. [option-b-gateway-carveout.md §1–5]

### 3.3 Option C — L1-only

C1 (escrow drain) is impossible: L1 DOLA has no admin-override transfer path and the gateway is DAO-owned. C2 (transfer blacklist via upgrade) is impossible: L1 DOLA is not upgradeable. C3 (full token migration) is technically possible but requires redeploying every Fed, rebuilding every Curve/Balancer/Uni DOLA pool, rewiring FiRM collateral/debt accounting, and coordinating CEXes, aggregators, and cross-chain integrations. Economic, not cryptographic, neutralization — any residual old-DOLA liquidity leaks value. Only useful as a credible negotiating threat. [option-c-l1-escrow-neutralization.md §3–5]

### 3.4 Option D — Custom gateway alone

A `setGateway(DOLA, newDolaCustomGateway)` via `L1GatewayRouter.setGateways(...)` is feasible (owner `0x3ffFbAdAF827559da092217e474760E2b2c3CeDd`, driven by L1 Timelock `0xE6841D92B0C345144506576eC13ECf5103aC7f49`), and has two strong direct precedents (Boring, Sky) plus the older RARI case. But a standalone `setGateway` does nothing to prevent legacy redemption: the old L1 gateway's `finalizeInboundTransfer` is gated only by `onlyCounterpartGateway` and trusts its immutable L2 pair; the old L2 gateway's `outboundTransfer` is `public payable virtual` and accepts direct callers. The router is not consulted on either side. The DOLA-router's 1.9M L2 balance can be burned through the old L2 gateway and finalized against the old L1 escrow after any setGateway migration. [option-d-custom-gateway.md §1–4; verify-bypass.md §Q1–Q5]

---

## 4. Critical verified facts that collapse the options

1. **`L1ArbitrumGateway.finalizeInboundTransfer` is guarded only by `onlyCounterpartGateway`.** No router consult, no token allowlist, no `L1GatewayRouter.getGateway(_token)` call. The modifier checks only: `msg.sender == bridge(inbox)` and `getL2ToL1Sender(inbox) == counterpartGateway`. Source-verified against `OffchainLabs/token-bridge-contracts` and independently re-verified. [option-d-custom-gateway.md §3; verify-bypass.md §Q1]
2. **`L2ArbitrumGateway.outboundTransfer` is publicly callable.** `public payable virtual`, no `routerOnly` modifier. If `msg.sender != router`, `_from = msg.sender` and the flow proceeds through `IArbToken(l2Token).bridgeBurn` → `sendTxToL1` targeting the hard-coded `counterpartGateway`. Source-verified and independently re-verified. [option-b-gateway-carveout.md §4; verify-bypass.md §Q2]
3. **`DisableGatewayAction` only writes the sentinel; the sentinel is never read on the hot path.** The action sets `l1TokenToGateway[token] = address(1)` on both routers. `GatewayRouter.getGateway(token)` returns `0x0` when DISABLED, but `getGateway` is only called from `L1GatewayRouter.outboundTransfer*`, `L2GatewayRouter.outboundTransfer`, and router-side `calculateL2TokenAddress`. Neither `L1ArbitrumGateway.finalizeInboundTransfer` nor `L2ArbitrumGateway.outboundTransfer` touches the router. [verify-disablegatewayaction.md §1, §4; verify-bypass.md §Q3, Q5]
4. **Empirical: two legacy USDT withdrawals finalized on L1 *after* `DisableGatewayAction` executed (2025-09-23).** Blocks 23,578,772 and 23,687,331, both from pre-Tether-upgrade Outbox entries. The DAO action did not stop them; Tether's earlier L2 USDT→USDT0 implementation upgrade (2025-01-29, `Upgraded(0x3263cd78...a3f4)`) is what severed new withdrawability by making `bridgeBurn` revert with `"Only OFT can call"`. [verify-disablegatewayaction.md §2]
5. **The L2 DOLA proxy is a `ClonableBeaconProxy` with no admin and no beacon-setter.** Not a permissions issue — the function does not exist. `BeaconProxy._setBeacon` is `internal`, called only in the constructor. Runtime bytecode contains no `SSTORE` to the beacon slot. UpgradeExecutor can make any call to any target but the target has no function to accept. [spike-upgradeexecutor-beacon.md §2a–2c, §3]
6. **The `StandardArbERC20` beacon is shared across all standard-bridge tokens.** DOLA, GRT (`0x23a941036ae778ac51ab04cea08ed6e2fe103614`), and CELR (`0x3a8b787f78d775aecfeea15706d4221b40f345ab`) all point at `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`. Custom-gateway tokens (FXS, WETH) do not. The beacon has had only two `Upgraded` events in history (2021-08 and 2021-10), both pre-DAO. [option-a-beacon-upgrade.md §3, §3.1]
7. **L1 DOLA is immutable.** Single-contract Solidity 0.5.16 ERC-20 at `0x865377367054516e17014CcdED1e7d814EDC9ce4`. Operator can `addMinter`, `removeMinter`, `mint`, `setPendingOperator`. No `pause`, `blacklist`, `burnFrom`, admin `transferFrom`, rescue, or upgrade mechanism. Burn is self-only. [option-c-l1-escrow-neutralization.md §1]
8. **L1 escrow ≈ L2 supply.** 1,935,010.023641 L1 escrow vs 1,935,009.923641 L2 supply (~0.1 rounding delta). The 1.9M double-claim is fully collateralized. [option-c-l1-escrow-neutralization.md §2]

---

## 5. The one surviving path

**Pattern: `ProxyUpgradeAction` on the legacy L1 StandardERC20Gateway (and ideally the L2 mirror) that scopes a revert to `_l1Token == DOLA_L1`**, combined with a `setGateway` remap so legitimate holders have a forward path.

### 5.1 Ownership chain

```
L1 StandardERC20Gateway (proxy)   0xa3A7B6F88361F48403514059F1F16C8E78d60EeC
  └─ ProxyAdmin                   0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa
     └─ owner = L1 UpgradeExecutor 0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
        └─ driven by L1 Timelock   0xE6841D92B0C345144506576eC13ECf5103aC7f49
           └─ driven by Arbitrum DAO (L2 Core Governor + L2 Timelock + outbox)

L2 StandardArbERC20Gateway (proxy) 0x09e9222E96E7B4AE2a407B98d48e330053351EEe
  └─ ProxyAdmin                    0xd570aCE65C43af47101fC6250FD6fC63D1c22a86
     └─ owner = L2 UpgradeExecutor  0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827
        └─ EXECUTOR_ROLE holders:
           - L1 Timelock alias      0xf7951d92b0c345144506576ec13ecf5103ac905a
           - L1 Security Council 9  0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641

L1 GatewayRouter                   0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef
  └─ owner = L1 UpgradeExecutor    0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
```

[option-a-beacon-upgrade.md §2; option-b-gateway-carveout.md §1–2; option-d-custom-gateway.md §1]

### 5.2 Deliverable shape

A Governance Action Contract (GAC) following `ArbitrumFoundation/governance` conventions under `src/gov-action-contracts/token-bridge/`:

```solidity
contract DolaLegacyGatewayFreezeAction {
    address public immutable l1ProxyAdmin;        // 0x9aD46fac...0c0aDa
    address public immutable l1GatewayProxy;      // 0xa3A7B6F8...60EeC
    address public immutable newL1Logic;          // pre-deployed frozen-impl
    address public immutable l1GatewayRouter;     // 0x72Ce9c84...031ef
    address public immutable l1Dola;              // 0x86537736...9ce4
    address public immutable newDolaCustomGw;     // pre-deployed Inverse gateway
    // plus retryable parameters for L2 mirror upgrade

    function perform() external payable {
        // 1. Upgrade L1 legacy gateway impl
        ProxyAdmin(l1ProxyAdmin).upgrade(
            TransparentUpgradeableProxy(payable(l1GatewayProxy)),
            newL1Logic
        );
        // 2. Register new custom gateway for ongoing legitimate DOLA flow
        address[] memory tokens = new address[](1); tokens[0] = l1Dola;
        address[] memory gws    = new address[](1); gws[0]    = newDolaCustomGw;
        L1GatewayRouter(l1GatewayRouter).setGateways{value: ...}(
            tokens, gws, maxGas, gasPriceBid, maxSubmissionCost
        );
        // 3. Retryable to L2 mirror action (ProxyUpgradeAction on L2 gateway)
    }
}
```

The new L1 logic must: (a) revert `finalizeInboundTransfer` / `outboundTransferCustomRefund` when `_token == DOLA_L1`; optionally (b) re-route escrow to an Inverse recovery address instead of `_to` inside finalize, which changes the ask from "freeze" to "DAO-seizure" — politically harder but enables recovery rather than permanent freeze. `ProxyUpgradeAction.sol` and `ProxyUpgradeAndCallAction.sol` in the governance repo are the canonical upgrade primitives. [verify-disablegatewayaction.md §5; governance.md §1.3, §4]

### 5.3 Paired action checklist

- Pre-deploy the new Inverse-operated custom L1 gateway (implements `ITokenGateway` + `calculateL2TokenAddress` + `forceRegisterTokenToL2`) and L2 counterpart, plus the new L2 DOLA implementing `IArbToken`. [option-d-custom-gateway.md §2]
- Plan escrow migration: there is no standard "sweep escrow on setGateway" hook, so the same `ProxyUpgradeAction` that installs the freeze must also expose a one-shot transfer of the 1,935,010 legitimate-plus-malicious escrow out of the old gateway — or leave it where it is and have the new DOLA-conditional finalize logic route escrow payouts to the recovery address. Either implies DAO-seizure framing for the portion attributable to Multichain. [option-d-custom-gateway.md §4]
- Coordinate the L2 mirror upgrade through a retryable so inbound deposits (if any are in-flight) do not re-establish a redeemable claim. [option-b-gateway-carveout.md §2]
- Enumerate and handle the ~35,307 DOLA held by the legitimate L2 addresses: either pre-announce a bridging window through the new custom gateway or forcibly migrate balances via the upgrade init. [DOLA_multichain_research.md §6]

---

## 6. Why this is unlikely to pass the Arbitrum DAO

This section is the decision-critical one. Estimates are drawn from `precedent-discourse.md` §4 and cross-validated against `governance.md` §1 and `verify-disablegatewayaction.md` §5.

### 6.1 No precedent for per-token logic changes in shared bridge infrastructure

- **Boring (topic 29206):** `L1GatewayRouter.setGateways` only. Active protocol, no pre-existing escrow. Passed Tally 2025-08-14 with 212.95M FOR / 42.11k AGAINST.
- **Sky / USDS (topic 28617):** `L1GatewayRouter.setGateways` only. Active protocol; Arbitrum Foundation disabled USDS/sUSDS through the bridge UI *specifically to prevent standard-gateway escrow from accruing* before custom-gateway registration. Passed Tally 2025-07-03 with 217.67M FOR after a cancelled-and-resubmitted payload-fix cycle.
- **RARI:** same pattern, older precedent.
- **USDT (topic 29503):** `DisableGatewayAction` — router-only sentinel write. The L2 token was bricked by Tether eight months earlier via the USDT0 OFT upgrade. The DAO action was explicitly "rubber-stamp" cleanup (L2BEAT/Sinkas quote). [precedent-discourse.md §1–3; verify-disablegatewayaction.md §3]

None of these modified shared L1/L2 gateway implementations. None added per-token filters. None handled pre-existing escrow controlled by an adversarial holder. **DOLA is a first-of-its-kind ask on all three axes.** [precedent-discourse.md §3]

### 6.2 Delegate discussion in Boring/Sky never engaged with malicious-holder or pre-existing-escrow scenarios

Across 47 Boring posts and 103 Sky posts, no delegate raised either scenario. GensDAO's Sky #26 precedent-risk question was the closest and was answered in a single paragraph with "DAO retains unmap lever." The Sky thread establishes that the DAO is comfortable with bespoke, externally-owned, isolable infrastructure (Sky controls its own gateway, DAO can unmap). The DOLA ask is the inverse: modify shared, DAO-owned infrastructure in a permanent way for a legacy state. Untested. [precedent-discourse.md §3]

### 6.3 Tether analogue

The USDT case is not a precedent for the DOLA ask; it is a precedent against. Tether, as token issuer, did the hard work (OFT upgrade killing `bridgeBurn`). The DAO was willing to rubber-stamp cleanup afterwards. Multichain has no cooperative equivalent — no one can unilaterally upgrade the L2 DOLA token since it is a shared-beacon `StandardArbERC20`. If the DAO acts for DOLA, it is doing the hard work itself for the first time. [verify-disablegatewayaction.md §3, §6]

### 6.4 Shared-infra asymmetry

A gateway-logic change means every delegate weighs systemic risk across every standard-bridge token (LINK, USDC.e, and a long tail) against one protocol's cleanup. The risk/benefit math is structurally unfavorable unless Inverse can show cross-ecosystem benefit — which it cannot. [option-a-beacon-upgrade.md §6; option-b-gateway-carveout.md §3]

### 6.5 Precedent-risk framing

"If you patch the gateway for DOLA, who's next?" Every dead bridge and stranded balance becomes a template. The DAO has strong systemic reasons to refuse the first request of this kind. Expect L2BEAT-style "canonical bridge trust assumptions" framing to dominate. [verify-disablegatewayaction.md §5]

### 6.6 Realistic political odds (from research)

| Component | Odds of passage | Driver |
|---|---|---|
| A — routine `setGateway` to new DOLA custom gateway | **~85–95%** | Boring/Sky/RARI provide direct precedent; delegates frame this as rubber-stamp |
| B — bespoke legacy gateway freeze (per-token revert in shared impl) | **~15–30%** | No precedent; shared-infra asymmetry; malicious-holder novelty |
| Joint (A+B bundled) | **~15–25%** | Dominated by B; bundling may be read as Trojan horse |

Quorum risk is additionally real. Boring hit quorum 213M vs 204M required; Sky hit 234M vs 222M — both narrowly. [precedent-discourse.md §4]

### 6.7 Timeline and mid-flight blockers

- Phase 0 (forum RFC + Snapshot temp-check): ~1 week
- Phase 1 (formal submission, delegation snapshot): 3 days
- Phase 2 (Tally voting): 14 days + possible 2-day extension
- Phase 3 (L2 Core Governor timelock): 3 days treasury, 8 days if L2→L1 message
- Phase 4 (L2→L1 outbox finalization): ~6.4 days
- Phase 5 (L1 Core Timelock): 3 days
- Phase 6 (Upgrade Executor execution)

Foundation's nominal "37 days once voting starts" plus realistic forum + audit work yields **4–5 months** end-to-end; Sky required a cancelled-and-resubmitted Tally cycle that added ~6 weeks. Security Council 9/12 shortcut is not applicable (not an emergency protocol vulnerability). [governance.md §1.1, §1.4; precedent-discourse.md §4]

Mid-flight blockers to plan for: Foundation objection on payload shape (Sky precedent); Security Council objection if the action is read as DAO-seizure; delegate fatigue producing quorum miss; audit findings requiring a new impl deploy and restart.

---

## 7. Governance deliverable shape

A serious AIP must arrive with:

- **Forum post structure** (copying Boring #1 / Sky #1): abstract → motivation (ecosystem framing, not Inverse-internal) → specification (GAC address, deployed impl addresses, parameters) → audits (ChainSecurity + Cantina + Certora is the delegate-credibility stack) → constitutional classification → timeline → "DAO retains unmap lever" language → non-endorsement language. Title must pattern-match Boring/Sky, not Tether — e.g. "Register DOLA custom gateway and retire legacy escrow path." [precedent-discourse.md §5]
- **Audit stack**: ChainSecurity and Cantina (Sky precedent) + Certora formal verification for the frozen-gateway impl + a separate audit of the GAC itself (Sky/Boring paid for this separately). Offchain Labs internal review of the governance action (both Boring #35 and Sky #83 show OCL playing this role but only after the project delivers the payload). [governance.md §1.5; precedent-discourse.md §2]
- **GAC code layout** (see §5.2 above): single `perform()` external entry, all parameters as immutables, no mutable state, delegatecall-safe, no `selfdestruct`. File location `src/gov-action-contracts/token-bridge/DolaLegacyGatewayFreezeAction.sol` or similar. Foundry fork tests simulating `UpgradeExecutor.execute` end-to-end. [governance.md §4]
- **Pre-deployed artifacts**: new frozen-impl logic for L1 and L2 legacy gateways, new DOLA custom gateway pair, new L2 DOLA `IArbToken` implementation, action contract(s) deployed to L1 and L2.

---

## 8. Inverse-side mechanics

- **Governor Mills** (Compound-fork): `0xBeCCB6bb0aa4ab551966A7E4B97cec74bb359Bf6`
- **Timelock**: `0x1637e4e9941D55703a7A5E7807d6aDA3f7DCD61B`
- **Treasury / DOLA operator**: `0x926dF14a23BE491164dCF93f4c468A50ef659D5B`
- **INV token**: `0x41D5D79431A913C4aE7d69a668ecdfE5fF9DFB68`
- **Proposal threshold**: 1,900 INV
- **Quorum**: 15,500 INV
- **Voting period**: 17,280 blocks
- **Voting delay**: 1 block
- **End-to-end wall-clock**: 1–2 weeks forum post → execution

Any DOLA reissuance or new-minter authorization requires a full Governor Mills proposal → Timelock queue → execute against Treasury. No operator-only lane exists for issuance at the scale of 1.79M DOLA. [governance.md §2.1–2.2]

**Historical reissuance precedent:** Frontier April 2, 2022 (~$15.6M notional / ~$8.8M recognized) and Frontier June 16, 2022 incidents were made whole via in-kind repayment (WBTC→WBTC, ETH→ETH) funded from reserves plus multi-tranche issuance including DBR OTC sales. That is the template for a Multichain restitution program — explicit bad-debt liability on the transparency page, amortized from DBR OTC + protocol revenue. [governance.md §2.3]

**Cross-DAO sequencing:** Inverse off-chain temp-check first (provides Arbitrum delegates with evidence of downstream commitment) → Arbitrum AIP second (slow leg) → Inverse binding Governor Mills proposal third (conditional on Arbitrum execution being observable on-chain, to preserve the zero-bad-debt standard). [governance.md §3.1]

---

## 9. Open questions / residual research

1. **Chains beyond BSC.** Fantom, Polygon, Moonriver, Avalanche, Optimism Multichain-DOLA deployments are unverified. Batch `cast` script against each RPC searching for ERC-20s named "DOLA" with Multichain minter `0x58892974758A4013377A45fad698D2FF1F08d98E` or transfers from `0x0615dbba33fe61a31c7ed131bda6655ed76748b1`. Required before snapshot. [governance.md §2.4]
2. **Legal overlay.** Multichain entity is in liquidation. Any onchain neutralization of the 1.9M router balance could intersect with liquidation claims. Requires legal review. [governance.md §5]
3. **Payer mechanics.** Treasury mint to claims contract vs FiRM bad-debt escrow with DBR OTC amortization — open governance question. Precedent exists for both. [governance.md §3.2]
4. **L2-only vs L1-mirror freeze.** An L2-only `outboundTransfer` revert stops new burns but does not affect any message already past the 7-day challenge window on the Outbox (if one exists). An L1-only `finalizeInboundTransfer` revert stops finalization regardless of L2 state. Ideal is both; cheapest-if-sufficient is L1. Requires a scan of `L2ArbSys` / Outbox events for in-flight DOLA withdrawals before finalization of proposal scope. [option-b-gateway-carveout.md §7; verify-disablegatewayaction.md §6]
5. **Security Council appetite.** Untested for dead-bridge cleanup. Assume unavailable; confirm privately. [governance.md §1.4]
6. **Governor Mills `xinv()` / timelock `delay()`.** Onchain reads were anomalous; re-verify. Not load-bearing for strategy. [governance.md §2.1]
7. **Maintenance Upgrades Working Group.** Nascent (krst / L2BEAT, per Boring #34). If stood up in time, could reduce the routine `setGateway` component to a non-vote; does not help the bespoke component. [precedent-discourse.md §4]

---

## 10. Recommendation

The only technical path that satisfies Inverse DAO's zero-bad-debt standard is an Arbitrum Constitutional AIP that modifies shared bridge logic (via `ProxyUpgradeAction` on the legacy L1 standard gateway, ideally mirrored on L2) for one dead token. Realistic odds are 15–25%. The alternatives are worse: unilateral L1 token migration (Option C3) is protocol-destructive to every DOLA integration; socializing losses via reissuance without neutralizing the 1.9M L2 claim violates the DAO's stated standard. If Inverse is going to pursue the Arbitrum path, it should pre-wire Offchain Labs engineering, the Arbitrum Foundation, L2BEAT, and the major delegate blocs *before* filing; fund ChainSecurity + Cantina + Certora audits up front; frame the action as maximally scoped (one conditional, one token, one dead bridge); and invoke the Maintenance Upgrades Working Group tonally while making clear the substantive ask is narrower than a general precedent. Budget 4–5 months plus one payload-correction cycle, and plan the Inverse-side reissuance to execute only after Arbitrum execution is observable on-chain.

---

## Appendix — Key addresses

```
L1 DOLA                          0x865377367054516e17014CcdED1e7d814EDC9ce4
L2 DOLA (ClonableBeaconProxy)    0x6a7661795c374c0bfc635934efaddff3a7ee23b6
StandardArbERC20 beacon          0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333
Current beacon implementation    0x3f770Ac673856F105b586bb393d122721265aD46
Multichain router (Arbitrum)     0x0615dbba33fe61a31c7ed131bda6655ed76748b1
BSC DOLA (AnyswapV6ERC20)        0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840
BSC Multichain vault/owner       0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7
BSC Multichain minter            0x58892974758A4013377A45fad698D2FF1F08d98E

L1 StandardERC20Gateway          0xa3A7B6F88361F48403514059F1F16C8E78d60EeC
L1 Gateway ProxyAdmin            0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa
L1 UpgradeExecutor               0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
L1 Timelock                      0xE6841D92B0C345144506576eC13ECf5103aC7f49
L1 GatewayRouter                 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef
L1 CustomGateway (shared)        0xcEe284F754E854890e311e3280b767F80797180d

L2 StandardArbERC20Gateway       0x09e9222E96E7B4AE2a407B98d48e330053351EEe
L2 Gateway ProxyAdmin            0xd570aCE65C43af47101fC6250FD6fC63D1c22a86
L2 UpgradeExecutor               0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827
L2 GatewayRouter                 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933
L2 CustomGateway                 0x096760F208390250649E3e8763348E783AEF5562
L1 Timelock alias on L2          0xf7951d92b0c345144506576ec13ecf5103ac905a
L2 Security Council 9            0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641

Inverse Governor Mills           0xBeCCB6bb0aa4ab551966A7E4B97cec74bb359Bf6
Inverse Timelock                 0x1637e4e9941D55703a7A5E7807d6aDA3f7DCD61B
Inverse Treasury / DOLA operator 0x926dF14a23BE491164dCF93f4c468A50ef659D5B
INV token                        0x41D5D79431A913C4aE7d69a668ecdfE5fF9DFB68
```

Beacon co-tenants verified: GRT `0x23a941036ae778ac51ab04cea08ed6e2fe103614`, CELR `0x3a8b787f78d775aecfeea15706d4221b40f345ab`.

---

## Appendix — Key numbers

| Item | Value |
|---|---|
| BSC DOLA total supply | 1,793,864.391064841026826353 |
| Arbitrum DOLA total supply | 1,935,009.923641336370430383 |
| Arbitrum DOLA at Multichain router | 1,899,702.791056052107486162 |
| Arbitrum DOLA outside router (legitimate) | 35,307.132585284262944221 |
| L1 DOLA escrow at standard gateway | 1,935,010.023641... |
| L1 DOLA total supply | 136,098,118.240939... |
| Router excess over BSC wrapper | 105,838.399991... |

---

## Source memos

- `research/DOLA_multichain_research.md` — framing, victim set, onchain verification, upgrade history
- `research/artifacts/message.txt` — original write-up
- `research/recent_proposals/props.md` — Boring / Sky thread pointers
- `research/feasibility/option-a-beacon-upgrade.md`
- `research/feasibility/option-b-gateway-carveout.md`
- `research/feasibility/option-c-l1-escrow-neutralization.md`
- `research/feasibility/option-d-custom-gateway.md`
- `research/feasibility/governance.md`
- `research/feasibility/spike-upgradeexecutor-beacon.md`
- `research/feasibility/precedent-discourse.md`
- `research/feasibility/verify-bypass.md`
- `research/feasibility/verify-disablegatewayaction.md`
