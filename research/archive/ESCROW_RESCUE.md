# SUPERSEDED: One-Shot Escrow Rescue

> Historical working memo. The concrete action is specified without political predictions in `../TECHNICAL_OPTIONS.md`.

Date: 2026-04-14 (revised after precedent research)

## The short version

Inverse Finance has roughly 1.9 million DOLA stranded behind a dead bridge (Multichain) on Arbitrum. If Multichain ever moves again, it can redeem that balance for real canonical DOLA on Ethereum mainnet, creating a double-claim against anything Inverse reissues to victim holders on BSC and elsewhere.

There is a single new technical opening, made possible by one load-bearing fact: **the Multichain attacker has been fully dormant for about three years.** That allows Inverse to ask for a narrower remedy than a forever-filter on the bridge. Instead of asking Arbitrum to permanently censor a specific balance, Inverse can ask for a one-time transfer of the stranded escrow back to the Treasury — with the bridge's own 1:1 invariant providing permanent forward defense for free.

**However**, a follow-up precedent search was unambiguous: this kind of action is *unprecedented* across all Arbitrum governance and every comparable L2, and the closest analogue (USDT `DisableGatewayAction`, AIP topic 29503) is actively *unfavorable* — the DAO confronted the same shape of orphaned escrow and explicitly declined to rescue ~$140k of Tether's. The rescue path is therefore best treated as a stretch objective layered on top of a more robust primary plan, not as the plan itself.

## What the bridge's own math gives us for free

The Arbitrum canonical bridge enforces a single invariant:

> L1 escrow balance === total L2 token supply.

Every L2 DOLA token was minted 1:1 when someone deposited L1 DOLA into the gateway's escrow. Every withdrawal burns L2 and releases L1 from that same escrow, 1:1. The gateway can never pay out more than it holds — it checks.

Right now:
- L1 escrow holds 1,935,010 DOLA
- L2 supply is 1,935,010 DOLA
- Of that, 1,899,703 is Multichain's and 35,307 is legitimate holders

That invariant, usually taken for granted, is actually a weapon Inverse can turn on the stranded claim.

## The move

Rather than asking Arbitrum to patch the gateway's withdrawal logic to reject a specific address forever, ask them to authorize a **one-time rescue** of the stranded escrow directly to Inverse. In plain English:

> "Multichain is provably dead. The 1.9 million DOLA it notionally backs on Arbitrum can never be recovered by its rightful counterparty. Authorize the Arbitrum DAO to transfer those stranded funds back to the Inverse Treasury, one time, so they can be returned to real holders."

The sequence looks like this:

1. **Migrate the 35,307 legit L2 DOLA holders off the old bridge** onto a new, Inverse-controlled custom gateway. This part is routine — `setGateway` AIPs have passed with near-unanimous support recently (Boring at 99.9%, Sky at 92.7%). Takes a couple of months and a couple of weeks of user outreach. After this, the old gateway's escrow backs only the Multichain router's claim.

2. **Arbitrum DAO upgrades the old L1 gateway implementation** to add a one-time admin-rescue primitive, then calls it to transfer the remaining ~1.9M escrow to Inverse Treasury. This is the novel ask. After execution, the escrow holds essentially zero DOLA.

3. **Inverse distributes the rescued 1.9M DOLA to verified victim holders** on BSC and other affected chains. This is existing plumbing — no new DOLA minted, just pass-through of the recovered funds.

## Why the attacker can never touch the money afterward

This is the elegant part: no ongoing defense is needed. The 1:1 invariant takes care of it.

If the Multichain attacker ever wakes up and tries to redeem:

- They call `bridgeBurn` on the old L2 gateway → succeeds, burns their L2 DOLA
- Seven days later, they call the Outbox to finalize the L1 withdrawal
- The L1 gateway tries to transfer 1.9M DOLA to them from a balance of ~0
- The transfer reverts on insufficient balance

The bridge's own math refuses to pay. Arbitrum doesn't need to remember anything, police anything, or keep any per-token logic in its hot path. The defense is structural, permanent, and free.

## Why this framing is materially easier politically

The previous "censor the bad balance" framing forced the Arbitrum DAO to answer uncomfortable questions it had no appetite for:

- Which dead bridge is next?
- How do you decide whose balance gets censored?
- What's the principle for modifying shared bridge logic for one protocol's benefit?

The escrow-rescue framing replaces those with different questions that have cleaner answers:

- Is Multichain provably dead? (Factual. Three-year dormancy + well-documented team disappearance is strong evidence.)
- Is the rescue amount determinable with certainty? (Yes — it's the on-chain router balance.)
- Is there collateral damage to legitimate users? (No — they were migrated first.)
- Does this set a precedent for DAO custody of escrow? (This is a real question, and probably the main objection, but it's a one-shot action with a high evidentiary bar rather than an ongoing policy.)

There is still a novel component being proposed. But the surface area shrinks from "modify shared infrastructure forever" to "exercise a one-time recovery power with a clear factual precondition." That matters.

## Three things still to watch

**Dormancy can break during execution.** If the attacker wakes between the migration (Phase 1) and the rescue (Phase 2) and starts a withdrawal, they could finalize before the rescue lands. Mitigation: keep the reactive gateway-patch AIP drafted and ready as a belt-and-suspenders fallback, even if it's never needed.

**Evidentiary bar for "provably dead."** Arbitrum will reasonably want some combination of on-chain dormancy proof, legal/public-record evidence of Multichain's operational collapse, and probably an independent audit attesting to the state. Not a blocker, but adds scope.

**The new precedent is about escrow custody, not token censorship.** That's a real thing to think through. The best answer is that the action is legible and narrow: a one-time transfer with a published precondition and a public action contract, not a general power. Framing matters. The Maintenance Upgrades Working Group at the Arbitrum Foundation is likely the right channel.

## How the odds actually shift (honest version)

An earlier draft of this memo suggested the escrow-rescue framing improved the bespoke component's odds from 15–30% to 30–45%. That was too optimistic, and a subsequent precedent search has been corrected for.

What the precedent search found:
- Zero direct precedent across all of Arbitrum's `gov-action-contracts/` — none of the existing action contracts ever transferred value out of a bridge escrow.
- Zero precedent across comparable L2s (Optimism, Base, Polygon zkEVM, zkSync, Starknet, Linea, Mantle).
- Across the entire Multichain aftermath ($200M+ stranded across many chains, 2.5+ years), no chain has executed an on-chain governance rescue. Fantom went the Singapore court route; others simply absorbed the loss.
- The closest Arbitrum analogue — AIP topic 29503, the USDT legacy-gateway deprecation — specifically confronted a stranded escrow of ~$140k and explicitly chose not to rescue it. That is an *unfavorable* baseline against which Inverse would be asking for ~13x more.

Corrected estimate: the bespoke rescue component sits around 10–20%, not 30–45%. The delegate conversation will revolve around the USDT precedent, and Inverse will need to articulate sharp, specific distinctions:

- Tether had an operating company, active issuance, and a plausible alternative redemption path. Multichain has none of those — the team has dissolved, keys are gone, and there is no counterparty Arbitrum could point a user toward.
- Tether's stranded balance was small relative to Tether's capacity to self-remediate. Multichain cannot self-remediate at any size.
- Tether's users had no organized harmed class. Multichain's users have a clear one, and Inverse is prepared to distribute recovered funds transparently.

Those are real and articulable distinctions, but they are not guaranteed to land with every delegate, and the USDT vote is recent enough to weigh heavily.

## Role in the overall plan

Given the unprecedented nature of the rescue action and the unfavorable USDT baseline, the rescue should not be treated as the primary plan. The recommended strategic posture is documented separately in `STRATEGY.md`: Inverse executes a robust primary plan (migrate legit holders, pre-load a reactive defense, hold a modest self-insurance reserve, reissue to victims) that succeeds on its own merits, and then files the rescue as an opportunistic stretch goal that refunds the reserves if it passes and costs nothing meaningful if it doesn't.

## What isn't changed

Everything else in the research record stands. The full technical rejection of token-beacon rewrites, router-only disables, L1-only unilateral fixes, and variant mint-and-drain schemes is unaffected — those remain dead. The escrow-rescue path is the one narrow technical opening that opens up once the attacker's dormancy is treated as a stated precondition rather than a hope; whether Arbitrum's DAO walks through it is a political judgment the research cannot settle.
