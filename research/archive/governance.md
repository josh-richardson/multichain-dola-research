# SUPERSEDED: Cross-DAO governance feasibility memo

> Historical working memo. Governance mechanics are consolidated in `../GOVERNANCE.md`; predictions and percentage estimates are not canonical.

**Date:** 2026-04-14
**Author:** research
**Status:** draft — unverified items explicitly flagged below

This memo covers the governance mechanics of a coordinated two-DAO action between
**Arbitrum DAO** (to neutralize the legacy DOLA withdrawal path on L2) and
**Inverse DAO** (to reissue DOLA to affected holders on BSC and other Multichain chains).
It does not evaluate technical sufficiency of any specific onchain intervention — that is
covered in the sibling feasibility docs (see `option-c-l1-escrow-neutralization.md`).

---

## 1. Arbitrum DAO process

### 1.1 End-to-end AIP flow

The Arbitrum Constitution formalizes a multi-phase process. Per the DAO Constitution
(<https://docs.arbitrum.foundation/dao-constitution>):

| Phase | What happens | Duration |
| --- | --- | --- |
| 0. Forum post + temperature check (Snapshot) | Off-chain poll, simple majority, no quorum | ~1 week |
| 1. Formal on-chain submission | Proposer must hold ≥ 1,000,000 delegated ARB; 3-day voter-distribution snapshot window | 3 days |
| 2. On-chain voting (Tally) | Constitutional: ~50% quorum of delegated votes (scaled 150M–450M ARB). Non-Constitutional: ~40% (scaled 100M–300M ARB). Extends 2 days if quorum is hit in the final 2 days. | 14 days (+2) |
| 3. L2 Core Governor timelock | 3 days (treasury) or 8 days for actions producing L2→L1 messages | 3–8 days |
| 4. L2→L1 outbox finalization | Rollup challenge / withdrawal window | ~6.4 days (~1 week) |
| 5. L1 timelock | L1 Core timelock delay | 3 days |
| 6. Execution via L1/L2 Upgrade Executor | `execute()` → `delegatecall` into the action contract | tx-level |

**Wall-clock estimate (Constitutional AIP with L1 execution):**
~6–8 weeks from first temp-check post to L1 execution; more typically **8–12 weeks**
once you account for forum iteration cycles and pre-audit. The Foundation's own
public guidance quotes "approximately 37 days" for Constitutional once formal
voting starts, but our experience-based estimate layers on the forum discussion
and audit work that realistically precedes the formal start.

### 1.2 Constitutional vs Non-Constitutional classification

The Constitution routes actions touching "protocol, software, chain ownership, or new
chains" to the Constitutional bucket (higher quorum, longer timelock, L1 execution).
Applied to our candidate actions:

| Action | Classification | Rationale |
| --- | --- | --- |
| (a) Beacon upgrade on L2 DOLA token implementation | **Constitutional** | Upgrades a chain-owned proxy beacon used by Standard Arb ERC20s — core bridge software. |
| (b) Shared L2 gateway logic upgrade | **Constitutional** | Modifies L2ArbitrumGateway implementation used by every standard-bridged token — clearly "software" and chain-wide risk. |
| (c) `setGateway` call (remap DOLA to custom gateway) | **Constitutional per precedent** | $BORING (<https://forum.arbitrum.foundation/t/constitutional-register-boring-in-the-arbitrum-generic-custom-gateway/29206>) and Sky (<https://forum.arbitrum.foundation/t/constitutional-proposal-for-arbitrum-dao-to-register-the-sky-custom-gateway-contracts-in-the-router/28617>) were both filed as Constitutional. $BORING passed both Snapshot and Tally; Sky passed Snapshot only. |
| (d) `DisableGatewayAction`-style token-specific action | **Constitutional** | The USDT precedent (<https://forum.arbitrum.foundation/t/constitutional-aip-disable-legacy-tether-bridge/29503>) was explicitly filed as "Constitutional AIP". It touches the L1GatewayRouter (shared bridge infrastructure), which is the tell — any action that writes to `L1GatewayRouter` or its L2 counterpart is Constitutional. |

USDT was Constitutional because `L1GatewayRouter.setGateways(...)` is a state-writing
call on Arbitrum's canonical bridge contract. Even though the operation is "just a
mapping update", it is on shared critical infrastructure, so the higher bar applies.
DOLA's intervention is at least as invasive, so **assume Constitutional**.

### 1.3 Action-contract pattern (the deliverable shape)

Source: <https://github.com/ArbitrumFoundation/governance/tree/main/src/gov-action-contracts>

A **Governance Action Contract (GAC)** is the on-chain artifact the proposal actually
ships. Conventions:

- Single external entry point: `function perform() external` (sometimes
  `function perform(...) external payable` when L1→L2 retryable tickets are needed —
  e.g. `DisableGatewayAction`).
- No mutable state; only `immutable` or `constant` fields captured at construction.
- Must be a safe `delegatecall` target.
- Executed by the **UpgradeExecutor** via `delegatecall`, so the action runs with the
  executor's permissions (which are the ones that actually hold admin / owner rights on
  router, beacons, etc.).
- Address-registry style construction — dependencies injected as immutables so the
  action is auditable as a pure bytecode artifact.

Relevant subdirectories in `src/gov-action-contracts/`:
- `AIPs/` — one-off AIP-numbered upgrade actions (e.g. sequencer maintenance bundles).
- `token-bridge/` — where `DisableGatewayAction.sol` lives; where a new DOLA-specific
  action would belong.
- `governance/`, `rollup/`, `sequencer/`, `treasury/`, `arb-token/`.

Reference shape of `DisableGatewayAction.sol`:

- Stores `l1GatewayRouter` (L1 router address) and token array as immutables.
- `perform()` calls `L1GatewayRouter.setGateways(tokens, gateways /* all = address(1) */,
  maxGas, gasPriceBid, maxSubmissionCost){value: maxGas*gasPriceBid + maxSubmissionCost}`
  to propagate the disable to L2 via an auto-redeemed retryable.
- Executed on L1 by the L1 UpgradeExecutor.

**What the Foundry project must produce for DOLA:** one or more GACs deployed to the
relevant chain(s), each exposing `perform()`, parameterized via immutables, plus a
test suite that forks mainnet + Arbitrum and simulates the Upgrade Executor calling
`performUpgrade(address action, bytes data)` against the deployed action. See
`option-c-l1-escrow-neutralization.md` for the specific action(s) required.

### 1.4 Security Council shortcut

The 12-member Security Council can bypass Phases 0–2 with **9-of-12** approval for
two kinds of actions:

- **Emergency action**: immediate software upgrade to address a critical,
  time-sensitive vulnerability. Post-hoc transparency report required. Bypasses the
  timelock as well.
- **Non-emergency action**: routine maintenance proposal that still goes through the
  timelock (Phases 3–6) but skips the vote.

**Applicability to DOLA recovery:** low. The Security Council exists for live
exploits, not 3-year-old dead-bridge cleanup. Pitching a DOLA-specific
`DisableGatewayAction` as an "emergency" would be a reach; a reasonable fallback
framing is "non-emergency Security Council action" to shave the voting phase, but
that is still politically equivalent to asking the Council to act on behalf of one
project — unlikely without full DAO vote precedent first.

**Recommendation:** plan for full Constitutional AIP; treat SC as a contingency lever
only if an active exploit risk emerges (e.g. signs that Multichain signers are
reactivating).

### 1.5 Outreach / who to talk to

From the USDT, $BORING, and Sky threads:

- **Offchain Labs (OCL)** is the technical implementer. Per the $BORING thread, OCL
  "provided the governance action contract and required governance documentation
  necessary for executing it." OCL is the party that writes and audits the GAC for
  bespoke bridge operations. For DOLA, OCL is the right first technical contact.
- **Arbitrum Foundation** owns governance facilitation — forum moderation, Snapshot
  setup, Tally coordination, AIP numbering.
- USDT audit was performed by **Offchain Labs internal + external**; the `DisableGatewayAction`
  audit referenced in <https://docs.arbitrum.io/assets/files/2025-03-offchain-disablegateway-action-securityreview-11ed2e1370d062c2ade5e5d6b085a8f3.pdf>
  is from March 12, 2025. (The `arbitrum-upgrades.pdf` artifact in this repo is a
  Trail of Bits review of SC-elections / sequencer upgrades, January 2024 — different
  scope, but confirms Trail of Bits as a go-to reviewer for Arbitrum governance work.)
- **Forum flow**: post in the "Proposals" category, tag with `[Constitutional]` in
  the title. Precedents tag `@Arbitrum` the foundation account and prominent delegates
  (L2Beat, Gauntlet, Blockworks, StableLab, etc.) early for feedback. Authors on the
  BORING thread (`didi`, `hellwolf`, `Jose_StableLab`) and Sky thread are the style
  template for how Inverse would present.

**Concrete next step:** OTC contact to Offchain Labs (historically via
`governance@arbitrum.foundation` or direct to OCL engineering leads — **unverified**
whether that specific email is current; needs confirmation). Pre-draft the GAC
and have OCL scope the security review before filing the forum post — that is the
path BORING, Sky, and USDT all took.

---

## 2. Inverse DAO process

### 2.1 Proposal mechanics (confirmed via `cast`)

Governor Mills is a **Compound-fork GovernorAlpha-style** governor (name string
verified on-chain: `"Inverse Governor Mills"`). Key addresses and parameters:

| Field | Value | Verification |
| --- | --- | --- |
| Governor Mills | `0xBeCCB6bb0aa4ab551966A7E4B97cec74bb359Bf6` | `name()` → "Inverse Governor Mills" |
| Timelock | `0x1637e4e9941D55703a7A5E7807d6aDA3f7DCD61B` | `governor.timelock()` ✓ |
| Treasury (also `DOLA.operator()`) | `0x926dF14a23BE491164dCF93f4c468A50ef659D5B` | `DOLA.operator()` ✓ |
| INV token | `0x41D5D79431A913C4aE7d69a668ecdfE5fF9DFB68` | `governor.inv()` ✓ |
| xINV | `0x1637e4e9941D55703a7A5E7807d6aDA3f7DCD61B` | `governor.xinv()` — NOTE: this is the **same address as the timelock** in our query; likely the Governor tracks voting power from xINV deposits into a contract that shares admin surfaces. **Flag as needing a second-pass verification** — possible RPC ABI collision. |
| Proposal threshold | 1,900 INV (1.9e21 wei) | `proposalThreshold()` ✓ |
| Quorum | 15,500 INV (1.55e22 wei) | `quorumVotes()` ✓ |
| Voting period | 17,280 blocks (~60 hours @ 12.5s; historically Inverse uses ~2.5 days) | `votingPeriod()` ✓ |
| Voting delay | 1 block | `votingDelay()` ✓ |
| Timelock delay | (not retrievable via standard `delay()` getter; likely 2 days based on forum statements) — **unverified on-chain** | — |

The 1,900 INV proposal threshold and 15,500 INV quorum match the values documented
at <https://www.inverse.finance/blog/posts/en-US/all-about-governance-at-inverse-finance>
and the forum (`forum.inverse.finance/t/.../48`), which also describes the
~40-hour post-voting hold before execution.

**Wall-clock estimate**: forum post → on-chain execution ≈ **1 to 2 weeks** end-to-end
(much faster than Arbitrum) — forum/Discord discussion a few days, 1-block voting
delay, ~60h voting, ~40h (2-day) timelock, then execution.

### 2.2 Operator powers on L1 DOLA

Verified on-chain: `DOLA.operator() = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B`
(Treasury contract).

DOLA (`0x865377367054516e17014CcdED1e7d814EDC9ce4`) follows the Inverse "operator +
minters" pattern. Operator authority:

- `addMinter(address)` / `removeMinter(address)` — gate who can `mint()`.
- `setOperator(address)` — transfer operator powers.
- Minters (once granted) can `mint(address,uint256)` without further DAO action per mint.

The **Treasury** contract is itself controlled by the Timelock (i.e. by DAO vote) —
any operator-level DOLA action (adding a minter, minting directly if Treasury itself
is a minter, transferring operator) therefore **requires a successful Governor Mills
proposal**, then queued to Timelock, then executed against Treasury.

There is no "DWF-style" operator-only lane for DOLA issuance at the scale of ~1.9M
tokens. Smaller operational mints through existing minters (e.g. Fed contracts, which
are whitelisted minters for GovMills/FiRM expansion) happen without per-mint votes,
but those are already-authorized minters acting within pre-approved allowances and
are not an appropriate vehicle for a reissuance program.

**Bottom line:** reissuance requires a DAO vote — full GovernorMills flow.

### 2.3 Historical precedent for reissuance / making-whole

Two prior incidents set the Inverse reissuance playbook:

- **April 2, 2022 Frontier oracle manipulation** (~$15.6M notional / ~$8.8M
  recognized liability). Plan summarized at
  <https://www.inverse.finance/blog/posts/en-US/News-for-users-affected-by-april-2-2022-incident>
  and <https://www.inverse.finance/blog/posts/en-US/our-plan-making-good>.
  Key mechanics: **repayment in the native asset originally deposited** (WBTC → WBTC,
  ETH → ETH, YFI → YFI), funded from Frontier reserve balances plus multi-tranche
  revenue and debt issuance (DBR OTC sales).
- **June 16, 2022 Frontier incident** — separate event, summary at
  <https://www.inverse.finance/blog/preview/posts/en-US/june-16-incident-summary>.
  Outcome tracked alongside the April bad debt, socialized via the transparency
  bad-debt page (<https://www.inverse.finance/transparency/bad-debts>).
- **OTC DBR sales proposal**:
  <https://forum.inverse.finance/t/proposal-to-authorize-otc-dbr-sales-to-repay-dola-bad-debt/258>
  — the governance template for converting bad-debt obligation into long-dated
  claims funded by new instrument issuance.

**Pattern:** Inverse reissues in-kind (same asset), funds the reissuance from a
combination of reserves + new issuance (DBR OTC, DOLA mint backed by FiRM revenue),
and tracks the outstanding liability transparently until fully amortized. That is the
template a Multichain-restitution proposal should follow.

### 2.4 Victim-set enumeration: anyDOLA across chains

**Verified**:
- **BSC DOLA (Multichain wrapper)**: `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840` —
  AnyswapV6ERC20, `totalSupply = 1,793,864.39`, `underlying() = 0x0`, vault/owner =
  `0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7`. (Verified in the parent research
  artifact.)

**Unverified / to audit** — the following chains were Multichain-supported during
DOLA's active Multichain period (per <https://medium.com/multichainorg/>,
docs.multichain.org archive, and explorer searches). DOLA deployments need to be
checked one-by-one:

| Chain | Likely deployment | Address | Status |
| --- | --- | --- | --- |
| BSC | yes (confirmed) | `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840` | verified |
| Fantom | possible | — | **unverified**; FTMScan search for "DOLA" + Multichain minter address `0x58892974758A4013377A45fad698D2FF1F08d98E` required |
| Polygon | possible | — | **unverified** |
| Optimism | unlikely (Inverse guidance at the time was "use native bridges for Optimism") | — | **unverified** |
| Moonriver | possible | — | **unverified** |
| Avalanche | possible | — | **unverified** |
| Arbitrum | NO Multichain wrapper — the `1,899,702.79` DOLA is the canonical Standard Arb ERC20 sitting in Multichain's router, **not** an anyDOLA | `0x6a7661795c374c0bfc635934efaddff3a7ee23b6` is canonical, Multichain router `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` is the holder | verified |

**Concrete next step for the research lead**: run a batch `cast` script against
FTM/Polygon/Moonriver/Avalanche/Optimism RPCs searching (a) for ERC-20s named "DOLA"
with minter `0x58892974758A4013377A45fad698D2FF1F08d98E`, and (b) transfer history
from `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` (the Multichain router).
Until that is done, assume BSC is the majority of the victim set but do not rely on
it being the only one. Inverse's own public statements in 2023 claimed "0 DOLA
exposure on Multichain" from the protocol's balance sheet perspective; that does not
speak to user-held wrappers.

### 2.5 Snapshot methodology (once chain list is finalized)

For each verified Multichain-DOLA wrapper on each chain, take a balance snapshot at a
single, pre-announced block height (e.g. block immediately before Inverse publishes
the reissuance proposal). Exclude:

- the Multichain router and any Multichain-controlled MPC addresses,
- addresses that can be reliably attributed to the exploiter or to Multichain itself
  as custodian,
- Inverse-controlled addresses,
- known bridge / CEX hot-wallet addresses (unless the CEX is participating in a
  pass-through claim process).

This snapshot becomes the reissuance claim registry.

---

## 3. Cross-DAO coordination

### 3.1 Sequencing recommendation

**Recommended: Inverse temp-check first, Arbitrum AIP second, Inverse binding vote third.**

Rationale:

1. **Inverse off-chain temp-check (forum post + snapshot.org poll, ~1 week)**:
   establishes that Inverse is serious about reissuance and has working-group buy-in.
   Needed as a social signal for Arbitrum delegates — they will (rightly) refuse to
   do invasive bespoke work for a dead bridge unless the downstream DAO actually
   plans to make users whole.
2. **Arbitrum AIP (temp-check → Tally → execution, ~8–12 weeks)**: carries the
   hard-to-reverse action. Must be pre-audited before filing (OCL + Trail of Bits or
   similar).
3. **Inverse binding Governor Mills proposal (~1–2 weeks)**: filed conditional on
   Arbitrum execution being observable on-chain. Reissuance mint + distribution
   contract deploys only after the L1 escrow neutralization is visible.

**Why not Arbitrum first**: Arbitrum delegates will ask "why should we do this if
Inverse hasn't committed to the other half?" — a forum temp-check is cheap and
answers that question.

**Why not simultaneous**: the Arbitrum side is the slower, harder leg; Inverse's
execution is fast enough that it can slot in after Arbitrum confirmation without
material schedule cost.

**Why Inverse's binding vote goes last**: prevents the reissuance from being live
while the L1 claim is still redeemable — the zero-bad-debt standard the parent memo
(`DOLA_multichain_research.md`) sets.

### 3.2 Who pays for the new DOLA (neutral framing)

Two structurally different options, presented without recommendation:

- **Option A — Treasury mint**. Governor Mills authorizes Treasury to mint ~1.79M
  DOLA (BSC wrapper supply, minus any excluded addresses) directly to a claims
  contract. Balance-sheet impact: increase in DOLA float with no corresponding new
  collateral. Requires governance decision on whether to back the new issuance
  against existing revenue streams (DBR fees, FiRM interest) or leave it as uncovered
  float.
- **Option B — FiRM bad-debt absorption**. Mint is routed through a FiRM bad-debt
  escrow, carried as an explicit liability on the transparency page (same pattern as
  post-April-2022 Frontier debt), and amortized from DBR OTC sales and revenue over
  time. Precedent-compatible with
  <https://forum.inverse.finance/t/proposal-to-authorize-otc-dbr-sales-to-repay-dola-bad-debt/258>.

Governance decides.

---

## 4. Action-contract shape (what the Foundry project must ship)

The Foundry deliverable for the Arbitrum side is one or more **Governance Action
Contracts** matching the `ArbitrumFoundation/governance` `src/gov-action-contracts/`
conventions:

1. **File location in the eventual PR**:
   `src/gov-action-contracts/token-bridge/DisableDolaLegacyBridgeAction.sol` (working
   name).
2. **Shape**:
   ```solidity
   contract DisableDolaLegacyBridgeAction {
       address public immutable l1GatewayRouter;     // 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef
       address public immutable l1Dola;              // 0x865377367054516e17014CcdED1e7d814EDC9ce4
       // plus any L2-side parameters needed for auto-redeemed retryables

       constructor(address _router, address _l1Dola /* , ... */) {
           l1GatewayRouter = _router;
           l1Dola = _l1Dola;
           // immutables only
       }

       function perform(/* maxGas, gasPriceBid, maxSubmissionCost */) external payable {
           // one of: L1GatewayRouter.setGateways(...) with address(1) sentinel
           //         (USDT-style, router-level shutoff),
           // or:     a bespoke call that sits on the L2 gateway or L2 token beacon,
           //         proxied through the L1→L2 Upgrade Executor via retryable.
       }
   }
   ```
3. **No state variables**, only immutables. No storage writes during `perform()`.
4. **Delegatecall-safe**: no `selfdestruct`, no `msg.sender`-dependent logic that
   breaks under delegatecall (`address(this)` etc. will resolve to the Upgrade
   Executor — that's intentional and required for the action to use its permissions).
5. **Tests**: Foundry fork tests against mainnet + Arbitrum fork, simulating
   `UpgradeExecutor.execute(actionAddr, abi.encodeWithSelector(perform.selector, ...))`.
   Verify post-state: `L1GatewayRouter.getGateway(DOLA) == address(0)` (or whatever
   the specific intervention requires), and that direct `outboundTransfer` on the L2
   gateway reverts for legacy DOLA holders.
6. **Audit scope**: same firms the precedents used (Offchain Labs internal + Trail of
   Bits or equivalent).

The Inverse-side deliverable is separate: a `Timelock.queueTransaction`-compatible
proposal payload containing `Treasury.addMinter(claimsContract)` and a deployed
`DolaMultichainClaimsContract` holding the victim-set Merkle root. That is standard
Inverse tooling, not GAC-shaped.

---

## 5. Open questions

1. **xINV address collision**. Governor Mills' `xinv()` returned the same address as
   `timelock()` in our query. Needs a second-pass verification — either confirm the
   xINV contract address is correct and the two addresses genuinely coincide, or
   re-query with correct ABI. (Flagged unverified.)
2. **Timelock delay**. Governor Mills timelock's `delay()` getter reverted under the
   standard Compound ABI. Need to inspect the actual Timelock bytecode / Etherscan
   source to confirm delay (forum statements imply ~2 days, not confirmed on-chain
   in this pass).
3. **Victim-set completeness**. anyDOLA deployments on Fantom, Polygon, Moonriver,
   Avalanche, Optimism are all currently **unverified**. Needs direct explorer and
   RPC confirmation before any Inverse proposal is filed.
4. **Exact Arbitrum-side action**. USDT-style router-level `setGateways(address(1))`
   is NOT sufficient to neutralize the L1 escrow claim (per the parent memo). The
   action-contract shape above is correct; the `perform()` body is still open. This
   is tracked in `option-c-l1-escrow-neutralization.md`.
5. **Security Council appetite**. Has never been tested for third-party dead-bridge
   cleanup. Unknown whether a 9-of-12 would entertain even a non-emergency bundle.
6. **Legal overlay**. Multichain entity is in liquidation (Chainalysis /
   news reporting, 2024–2025). Any onchain neutralization of router balances could
   intersect with liquidation claims. Needs legal review before finalizing — not a
   governance-mechanics question but a gating question for both DAOs.
7. **Foundation contact details**. The right OCL / Arbitrum Foundation individual
   contact was not pinned down in public threads (proposal accounts are
   institutional). Recommend reaching out via the governance forum DM to
   `@Arbitrum` foundation account and cross-posting intent in the Arbitrum
   Discord governance channel to surface the right engineer.

---

## Sources

### Arbitrum
- DAO Constitution: <https://docs.arbitrum.foundation/dao-constitution>
- Governance action contracts repo: <https://github.com/ArbitrumFoundation/governance/tree/main/src/gov-action-contracts>
- `DisableGatewayAction.sol`: <https://github.com/ArbitrumFoundation/governance/blob/main/src/gov-action-contracts/token-bridge/DisableGatewayAction.sol>
- USDT Constitutional AIP: <https://forum.arbitrum.foundation/t/constitutional-aip-disable-legacy-tether-bridge/29503>
- USDT `DisableGatewayAction` security review: <https://docs.arbitrum.io/assets/files/2025-03-offchain-disablegateway-action-securityreview-11ed2e1370d062c2ade5e5d6b085a8f3.pdf>
- $BORING custom gateway: <https://forum.arbitrum.foundation/t/constitutional-register-boring-in-the-arbitrum-generic-custom-gateway/29206>
- Sky custom gateway: <https://forum.arbitrum.foundation/t/constitutional-proposal-for-arbitrum-dao-to-register-the-sky-custom-gateway-contracts-in-the-router/28617>
- Token bridging: <https://docs.arbitrum.io/how-arbitrum-works/deep-dives/token-bridging>

### Inverse
- Governance overview: <https://www.inverse.finance/blog/posts/en-US/all-about-governance-at-inverse-finance>
- Docs smart-contracts index: <https://docs.inverse.finance/inverse-finance/inverse-finance/technical/smart-contracts>
- April 2, 2022 incident plan: <https://www.inverse.finance/blog/posts/en-US/News-for-users-affected-by-april-2-2022-incident>
- June 16, 2022 incident summary: <https://www.inverse.finance/blog/preview/posts/en-US/june-16-incident-summary>
- "Plan for Making Good on Our Commitments": <https://www.inverse.finance/blog/posts/en-US/our-plan-making-good>
- Bad-debt transparency: <https://www.inverse.finance/transparency/bad-debts>
- DBR OTC bad-debt proposal: <https://forum.inverse.finance/t/proposal-to-authorize-otc-dbr-sales-to-repay-dola-bad-debt/258>
- Governor Mills voting-limits discussion: <https://forum.inverse.finance/t/proposal-to-modify-current-governor-mills-voting-and-proposal-limits/48>

### Onchain verifications (this pass)
- `GovernorMills.name()`, `.proposalThreshold()`, `.quorumVotes()`, `.votingPeriod()`,
  `.votingDelay()`, `.timelock()`, `.inv()`, `.xinv()` — queried via `cast call` on
  mainnet at block ~current (2026-04-14).
- `DOLA.operator()` → Treasury address.
- `DOLA.totalSupply()` → `136,098,118.24…` DOLA (at query time; informational only).
