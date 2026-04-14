# Inverse DOLA Recovery: Recommended Strategy

Date: 2026-04-14

## One-paragraph summary

Inverse should not bet its recovery on an unprecedented Arbitrum governance action. The primary plan is a self-sufficient four-part program that makes BSC victims whole on a known timeline without requiring Arbitrum to cross a political threshold it has never crossed before. A separate, opportunistic rescue proposal to Arbitrum — asking for a one-time transfer of stranded escrow back to the Treasury — should be pursued as a stretch goal in parallel. If the rescue passes, Inverse's reserves are replenished and the residual tail risk disappears. If it fails, Inverse has already delivered on the zero-bad-debt commitment through the primary plan, and the only loss is the time spent drafting the proposal.

## The primary plan

Four moves, all of which Inverse controls or has high-confidence ability to execute:

### 1. Migrate legitimate Arbitrum holders to an Inverse-controlled custom gateway

File a routine `setGateway` Constitutional AIP with the Arbitrum DAO, pointing L1 DOLA at a new Inverse-deployed custom L1/L2 gateway pair. Recent precedents — Boring at 99.9% for and Sky at 92.7% — suggest passage odds around 85–95%. Timeline to execution is roughly eight to twelve weeks.

Once the new gateway is live, run a two-to-four-week outreach to the ~35,307 DOLA of legitimate Arbitrum holders sitting on the old bridge. Migrate them to the new gateway. After migration, the old bridge's escrow backs only the Multichain router's 1.9M claim.

This is the lightest political lift in the whole plan and has the highest confidence of passage. It is also a real improvement regardless of what happens next: Inverse gets a cleanly-owned gateway, legitimate users are separated from the contaminated balance, and the forward-facing bridging story is on infrastructure Inverse itself controls.

### 2. Pre-load a reactive defense against the dormant attacker

In parallel with migration, draft, audit, and pre-stage a `ProxyUpgradeAction`-style upgrade to the old L1 StandardERC20 gateway that would, if ever needed, block finalization of outbound withdrawals for legacy L2 DOLA.

Do not file this as an AIP preemptively. Hold it ready. Establish a monitoring setup that watches for outbound `bridgeBurn` events against the Multichain router address on Arbitrum. If one ever fires, Inverse has seven days (the outbox challenge window) to push the upgrade through — probably via the Security Council's emergency path — before L1 finalization can complete.

The attacker's three-year dormancy makes this event extremely unlikely to ever trigger. The cost to pre-stage it is modest (one audited contract, one monitoring setup). The value, if it ever does trigger, is existential.

### 3. Maintain a self-insurance reserve sized to the residual risk

Fund a dedicated Treasury reserve against the probability that the attacker wakes up during the execution window AND the reactive defense fails to land in time. Rough sizing: a few percent times 1.9M, so low five to low six figures. Make the reserve explicit in any governance framing, so the zero-bad-debt commitment is backed by visible collateral rather than assertion.

### 4. Reissue to BSC holders

Via Inverse DAO vote through Governor Mills (`0xBeCCB6...9Bf6`) and the Timelock (`0x1637e4...CD61B`). Snapshot BSC anyDOLA holders at `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840` and any other verified Multichain-wrapped DOLA deployments (Fantom, Polygon, Moonriver, Avalanche, Optimism — pending verification). Fund from Treasury; do not mint unbacked DOLA.

Inverse has done something morally analogous before — the Frontier reimbursements of 2022 were paid in-kind and funded via reserves plus DBR OTC sales — so the playbook exists.

Execution of step 4 should not wait for Arbitrum's side. Steps 1–3 together create enough risk mitigation that BSC holders can be made whole on Inverse's own timeline, not Arbitrum's.

## The stretch proposal

File an Arbitrum Constitutional AIP asking for a one-time authorization to transfer the stranded ~1.9M DOLA from the old bridge's L1 escrow back to the Inverse Treasury. Technical details are in `ESCROW_RESCUE.md`. Key framing points for the filing:

- The action is a one-shot, self-terminating remedy, not an ongoing policy. The contract performs exactly one transfer and never runs again.
- The Multichain attacker is provably dormant (three years, no counterparty, keys presumed lost) and the stranded balance is therefore unclaimable by its rightful owner.
- Legitimate Arbitrum holders have already been migrated off the bridge at the time of filing, so collateral damage to real users is zero.
- The action does not require per-token logic in the gateway's hot path, does not censor any address, and does not create a general DAO power to modify escrow on an ongoing basis.
- Inverse commits to publish distribution records so every dollar rescued is traceable to a victim refund.

Honest expected outcome: passage odds around 10–20% given zero precedent for governance-led escrow rescue across Arbitrum or any comparable L2, plus the USDT AIP 29503 unfavorable baseline where the DAO declined to rescue ~$140k of analogous stranded Tether escrow. The proposal has to clearly distinguish Inverse's situation from Tether's — articulable distinctions exist (no operating company, no alternative redemption, a harmed class of users) but will not be universally persuasive.

If it passes, the rescued 1.9M refills the Treasury reserve from step 3 and fully closes the dual-claim exposure. If it fails, Inverse has lost nothing material — the primary plan already delivered on the zero-bad-debt commitment.

## Sequencing

A rough timeline:

- Weeks 0–2: deploy custom L1/L2 gateway pair; publish migration tooling; prepare Phase 2 action contract draft
- Weeks 2–4: pre-wire Offchain Labs, Arbitrum Foundation, L2BEAT, key delegate blocs; begin temp-check thread
- Weeks 4–14: file and pass `setGateway` AIP on Arbitrum; audit and pre-stage Phase 2 action contract
- Weeks 10–18: migrate legit Arbitrum holders as Phase 1 executes
- Weeks 14–16: file Inverse DAO proposal for victim reissuance + reserve funding; execute on passage
- Weeks 14–30: file stretch rescue AIP on Arbitrum, running in parallel with victim reissuance

Total realistic timeline to victims being whole: fourteen to eighteen weeks from day zero, driven by Inverse's own governance rather than Arbitrum's.

## What's required from Inverse

- Engineering: custom gateway deployment, migration UX, Phase 2 action contract, monitoring infrastructure
- Treasury: reserve funding, DOLA for victim reissuance
- Governance: Inverse DAO vote on reissuance and reserve; separate forum engagement on Arbitrum
- Relationship work: pre-wire Offchain Labs, Foundation, L2BEAT, delegates

All of this is within Inverse's normal capacity. Nothing in the primary plan depends on a decision Arbitrum has never made before.

## What's explicitly not in the plan

- No beacon upgrade ask (shared infrastructure, dead on arrival)
- No forever-filter-the-attacker ask (novel censorship primitive, unfavorable baseline)
- No full L1 DOLA token migration (catastrophic downstream impact)
- No reliance on the stretch proposal passing before reissuance begins

## Open items before execution

- Confirm victim set beyond BSC. Fantom, Polygon, Moonriver, Avalanche, Optimism anyDOLA deployments need to be verified as existing, unverified, or confirmed absent. This is a short on-chain task.
- Determine the exact distribution mechanism. Claims portal versus direct send versus CEX-coordinated rebalance are all viable; choice affects engineering scope.
- Decide on the Phase 2 action contract's activation path. Three candidates: pre-approved shelf AIP with onchain activation condition, pre-staged contract with Security Council emergency activation, or fast-track AIP with expedited timing. Each has tradeoffs.
- Finalize the reserve sizing. Needs an explicit probability × impact estimate anchored to a model the DAO can defend.
- Legal review of the Multichain dormancy claim. Singapore court filings, public disclosures from the Multichain team, and on-chain dormancy data all support the claim, but it should be assembled as a formal package for the stretch proposal.
