# SUPERSEDED: Boring and Sky precedent discourse memo

> Historical precedent analysis. Verified mechanics are consolidated in `../GOVERNANCE.md`; predictions are not canonical.

Date: 2026-04-14
Author: research agent
Scope: Assess whether the Boring (topic 29206) and Sky (topic 28617) Arbitrum custom-gateway precedents materially change the political feasibility of an Inverse-Finance-authored Arbitrum Constitutional AIP to neutralize the legacy Multichain-held DOLA claim on L1 escrow.
Method: Discourse JSON API pulls of both topics (47 posts on Boring, 103 posts on Sky), cross-referenced with Tally result posts and prior research in this repo.

---

## 1. Boring proposal summary

### Header

- Title: `[CONSTITUTIONAL] Register $BORING in the Arbitrum generic-custom gateway`
- URL: <https://forum.arbitrum.foundation/t/constitutional-register-boring-in-the-arbitrum-generic-custom-gateway/29206>
- Proposer: `@didi` (Superfluid Foundation / SuperBoring); technical co-author `@hellwolf` (Superfluid co-founder).
- Forum post created: 2025-05-13.
- Snapshot temp-check: passed (forum-referenced, near-unanimous support).
- Tally onchain final result (post #46, 2025-08-14): Quorum reached (213.04M of 204.86M required). FOR 212.95M (99.9%), AGAINST 42.11k, ABSTAIN 89.48k. **Passed.**
- Wall-clock: forum post 2025-05-13 → Snapshot July 2025 → Tally vote ended 2025-08-14. Roughly 3 months forum→execution, slower than notional because early engagement was sparse and quorum/process discussion dominated.
- OCL engagement: `@offchainlabs` (post #35, 2025-07-31) confirmed Tally payload matched spec. `@krst` (L2BEAT, post #34) drove the onchain submission in coordination with the Foundation after the Foundation prepped/greenlit the payload.

### Technical shape

- A single call to `L1GatewayRouter.setGateways(tokens, gateways, ...)` that maps L1 BORING (`0x0Bc4dF77353ae96f31bC82bC2536bb23B2009919`) to the Arbitrum generic-custom gateway, with the L2 counterpart pairing to the pre-deployed L2 BORING Super Token at the same address.
- BORING is a non-upgradable L1 ERC-20 that predates the `isArbitrumEnabled()` hook, so the token-initiated permissionless `setGateway` path was unavailable and DAO action via `L1UpgradeExecutor` was the only route. This is identical to the DOLA situation in principle.
- Execution contract address not independently extracted from thread; OCL-prepared payload lives in the Tally proposal (proposal ID `2646816212452902696` on the Arbitrum Core Governor `0xf07DeD9dC292157749B6Fd268E37DF6EA38395B9`).

### Objections and how they were addressed

- Precedent/process objection (AranaDigital #11, UADP/AbdullahUmar #7, SEEDGov #16, L2BEAT #33, Lampros #15, Hawheik #17, Tane #22, Griff #26, Bob-Rossi #31): near-universal complaint that a routine router mapping should not require a Constitutional AIP. **Did not cost votes** — the same delegates voted FOR while calling for a streamlined process (Maintenance Upgrades Working Group, `krst`).
- Endorsement framing (Danielo #6): explicit request that the proposal include language that the DAO is not endorsing $BORING, just performing a permissionless-in-spirit operation. Adopted implicitly by several voters (Hawheik #17, Lampros #32) who separated "enabling infra" from "endorsing token."
- Technical-risk objection: essentially zero. No delegate argued the `setGateway` mapping introduces risk to other tokens on the shared bridge.
- Token ownership / escrow control / malicious-token / migration of existing escrow: **none raised**, because BORING had no prior Arbitrum escrow to migrate. This is the central gap vs. DOLA.
- Delegate dissent: on Tally, AGAINST 42.11k / 213M (~0.02%). No substantive dissenting post in thread.

### Author framing that worked

- Explicit "routine administrative" framing in post #1 (one paragraph motivation, one paragraph spec, "we assume the process of token registration to be well known").
- SuperBoring volume metrics and prior Base deployment cited (post #3) when delegates asked for more context.
- No attempt to frame as novel; heavy use of "same as RARI, same as Sky" pattern-matching.

---

## 2. Sky (USDS / sUSDS) proposal summary

### Header

- Title: `[CONSTITUTIONAL] Proposal: For Arbitrum DAO to register the Sky Custom Gateway contracts in the Router`
- URL: <https://forum.arbitrum.foundation/t/constitutional-proposal-for-arbitrum-dao-to-register-the-sky-custom-gateway-contracts-in-the-router/28617>
- Proposer: `@SpikeWatanabe.eth` (StableLab, authoring on behalf of Sky / Maker). Sponsored onchain by `@karpatkey`.
- Forum post: 2025-03-03.
- Snapshot temp-check: passed (March 2025).
- Tally first attempt: cancelled 2025-06-12 due to an ETH value unit-mismatch bug (820,000,000,000,000 ETH instead of 0.00082 ETH — post-mortem in post #81). Re-submitted with `value = 0` per Arbitrum Foundation guidance (post #82, `@Arbitrum`).
- Tally onchain final result (post #105, 2025-07-03): Quorum reached (234.71M of 222.41M). FOR 217.67M (92.7%), AGAINST 27.23k (0.0%), ABSTAIN 17.04M (7.3%). **Passed.**
- Wall-clock: 2025-03-03 forum → 2025-07-03 Tally pass ≈ 4 months.
- OCL engagement: `@offchainlabs` post #83 (2025-06-19) published the registered custom gateway address `0x84b9700E28B23F873b82c1BEb23d86C091b6079E` for USDS (`0xdC035D45d973E3EC169d2276DDab16f1e407384F`) and sUSDS (`0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD`), explicitly noting custom gateways are "fully trusted with user balances of the specific tokens routed through them so this is a sensitive role." `@Arbitrum` Foundation (post #82) actively shaped the payload.

### Technical shape

- `L1GatewayRouter.setGateways(...)` call registering the Sky-owned L1 custom gateway for USDS and sUSDS.
- Sky-operated gateway: **Sky retains full unilateral control over the custom gateway and the tokens**; Arbitrum DAO retains only the ability to unmap (revert to default gateway). SpikeWatanabe #22: "Custom gateways are operated by Sky Ecosystem and its governance, so Arbitrum DAO doesn't have a direct role in their operation or upgrades. However, Arbitrum DAO retains full authority to list these custom gateways—and can revert to the standard gateway on the Arbitrum Router contract at any time."
- Audited by ChainSecurity (Oct 2024) + Cantina (Oct 2024) + Certora formal verification. Sky paid for a separate governance-action audit themselves (Jose_StableLab #10).

### Objections and how they were addressed

- Precedent risk (GensDAO #26, Frisson #39): "Does this set a precedent? Are we ready to handle such requests?" Answered mainly by saying "we already did RARI, Sky, and the standard gateway is unfit when token is upgradable." Accepted by voters without further friction.
- Token ownership / escrow control (0xDonPepe #2, GensDAO #26, WinVerse #19): "What guarantees are there that SKY cannot arbitrarily modify gateways, such as freezing funds, without DAO approval?" Answered explicitly: Sky fully controls the custom gateway and tokens; DAO's remedy is the revert-to-default mapping. Delegates **accepted this**, which is the most important political signal in either thread — the DAO was comfortable wiring a bespoke, externally-controlled contract into shared bridge infrastructure so long as the DAO's unmapping lever remained.
- Malicious-token handling: not substantively raised. The assumption throughout was "Sky is Sky, Maker's reputation carries this."
- Migration of existing escrow: **not raised, because USDS/sUSDS had no pre-existing standard-gateway escrow on Arbitrum** — Sky had not yet onboarded through the default gateway. Users bridging before approval were directed to other routes; the Arbitrum team disabled bridging USDS/sUSDS through the Arbitrum Bridge UI *specifically* to prevent standard-gateway escrow from accruing before Sky's custom gateway was registered (see proposal #1 rationale). **This is the critical negative for DOLA**: the DAO has never approved a gateway migration that had to deal with live existing escrow.
- Delegate dissent: substantively none. paulofonseca #90 voted AGAINST on the first (cancelled) onchain attempt purely as a coordination vote against the buggy payload; switched FOR on the corrected re-submission (#91).
- Process framing echo: same "please streamline this" complaint as Boring, from L2BEAT, Lampros, SEEDGov, 404DAO (who proposed a DAO-Approved Token List UI feature), Michigan Blockchain, Tane, Blockworks.

### Author framing that worked

- Framed explicitly as parallel to RARI (`BlockworksResearch` #3: "we've done something similar before with the Rari protocol"; `@Tane` #15: "no brainer... DAI already registered"). The RARI precedent did an enormous amount of work.
- Emphasized existing audit stack (ChainSecurity, Cantina, Certora) up front in Q&A (#22), converting "what if exploit?" into "here are three audits."
- Business value framing (Spark Liquidity Layer, Spark Savings, $100M USDS + $100M sUSDS already deployed) gave delegates an affirmative case beyond "please do this routine thing."
- Clean separation of "what Sky controls" vs. "what Arbitrum DAO controls" — articulated in #22 and accepted without further pushback.

---

## 3. Comparison to the DOLA ask

Where Inverse fits cleanly in the precedent envelope:

1. **Constitutional classification**: both Boring and Sky confirm that `setGateways` calls on `L1GatewayRouter` are routed as Constitutional AIPs. DOLA's research already assumed this (`governance.md` §1.2) — now empirically confirmed twice in the past 12 months.
2. **Permissionless-in-spirit framing**: DOLA's L1 token predates Arbitrum hooks in exactly the same way BORING's did. The "the token was deployed before the self-register hook existed, so we need the DAO" framing is a direct copy of Boring post #1 and will receive the same reception.
3. **DAO-operated action, project-paid audits**: Sky paid for the Sky-side audits plus a governance-action audit; OCL provided the GAC and documentation but asked Sky to validate the payload. Inverse must plan for the same cost ownership.
4. **Foundation and OCL engagement is obtainable**: in both threads `@offchainlabs` posted to confirm payload correctness, `@Arbitrum` (Foundation) shaped the payload to reduce complexity. Neither proposer was left to drive onchain submission alone. Inverse should expect similar hand-holding, conditional on Inverse having pre-audited artifacts.

Where Inverse overreaches the precedents — and these are the decisive gaps:

1. **Dead protocol, not live protocol.** Boring and Sky are active, growing products with ongoing demand. Inverse's narrative is "clean up a 3-year-old dead bridge after Multichain's collapse." Delegates expressed appetite for **infra-enabling** routine actions; they did not express appetite for **cleanup** of a specific project's legacy mess. The question "what's in it for Arbitrum?" is affirmatively answered in both precedents (TVL, volume, stablecoin UX) and is affirmatively unanswered in DOLA's case.
2. **Pre-existing standard-gateway escrow.** Neither precedent touched a token with material pre-existing escrow on the default gateway. Sky explicitly prevented this by having the Foundation disable USDS/sUSDS through the bridge UI before registration. DOLA already has ~1.935M escrowed at `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`. Neither thread provides **any** template for how to handle that — no delegate, proposer, OCL, or Foundation post discussed sweeping, freezing, or migrating pre-existing escrow on the default L1 standard gateway.
3. **`setGateway` alone does not solve DOLA's problem.** Per `option-d-custom-gateway.md` §3, the L1 standard gateway's `finalizeInboundTransfer` does not consult the router — it trusts only its immutable L2 counterpart. So even a perfect DOLA-registration-to-custom-gateway AIP leaves the old L2 DOLA redeemable via the old L2 standard gateway's direct `outboundTransfer`. Boring and Sky never had to ask for the *second* component that would make the registration effective for a pre-existing-escrow token. That second component — a DOLA-scoped modification to shared L2 gateway logic, the L2 DOLA beacon, or an escrow sweep via upgrade of the old standard gateway — has **no precedent** in these threads.
4. **Inverse-controlled vs. project-controlled gateway.** Sky explicitly retains sole operational control of its custom gateway; Boring uses the *shared* Arbitrum generic-custom gateway. The DOLA research's preferred path (a bespoke DOLA gateway plus a legacy-path-disable) mirrors the Sky ownership model more than the Boring shared-gateway model, which is fine — but the legacy-path-disable is the novel ask.
5. **Malicious-actor context.** The current controller of the ~1.9M DOLA at the Multichain router is an adversarial party (Multichain / liquidator / unknown MPC successor). Boring and Sky had no malicious-holder narrative. A clean "malicious actor holds a live claim on canonical L1 DOLA" framing has never been adjudicated by this DAO. Closest cousin is USDT `DisableGatewayAction`, and that proposal sidestepped the malicious-holder case by asserting Tether had already neutralized the path externally.

---

## 4. Net effect on political odds

Quantitative read, split by component:

- **Component A — `setGateway` registration of a new DOLA custom gateway.**
  - Before Boring/Sky: odds of passing on its own merits ≈ 60–70% (RARI was the only concrete precedent, process was novel).
  - After Boring (213M FOR, 42k AGAINST; 99.98% in favor) and Sky (217.67M FOR on re-submission): odds ≈ **85–95%**.
  - Both precedents passed easily with near-unanimous delegate support. Delegates now explicitly frame gateway registrations as "rubber-stamp infra ops that ought to be delegated to an AAE." Inverse can copy the Boring post #1 / Sky post #1 structure almost verbatim for this component.
  - Caveat: quorum was hit both times but only barely (Boring 213M vs 204M needed; Sky 234M vs 222M). Delegate fatigue is real; a single-purpose routine AIP still has quorum risk. USDS/sUSDS and Boring both cleared it, so DOLA likely will too, but this is not a layup.

- **Component B — the bespoke bridge-logic intervention (disable old L2 gateway for DOLA, or upgrade L2 beacon, or sweep old L1 escrow).**
  - Before Boring/Sky: odds ≈ 15–30% per the parent research. USDT was the nearest precedent; USDT neither seized balances nor neutralized a live direct-withdrawal path.
  - After Boring/Sky: **essentially unchanged, 15–30%.** These threads do not address the second component at all. There is no delegate quote that reads "we'd be willing to disable a legacy withdrawal path for a specific token," and no Foundation/OCL quote that reads "we'd author an action touching the shared L2 standard gateway or a token-specific beacon for a third party's cleanup." The precedents are silent on this dimension.
  - More specifically, the Sky thread establishes that the DAO is comfortable with *adding* bespoke token-specific infrastructure that is **externally-owned and isolable** (Sky can do what it wants inside its own custom gateway, and the DAO's only lever is unmap). DOLA's component B is the inverse: it asks the DAO to **modify** or **intervene in** shared, DAO-owned infrastructure in a way that has ongoing, permanent effects on a pre-existing legacy state. That pattern was not tested.

- **Joint proposal (A+B bundled).** The sub-odds do not multiply cleanly because a bundled proposal rises or falls together. Realistic odds for the joint proposal ≈ **15–25%** — dominated by component B and slightly depressed by the "you're asking for a novel intervention under cover of a routine one" framing risk. Bundling may actively hurt if delegates interpret A as a Trojan horse for B.

Net effect of Boring/Sky on DOLA odds overall: **modestly positive but narrowly so.** The precedents confirm that Inverse has a very-likely-to-pass path for the routine half and do not move the needle on the hard half. If Inverse can find a way to neutralize the legacy claim L1-side unilaterally (Option C family — operator-level moves on canonical DOLA), the combined outcome is much better than the joint Arbitrum AIP. If Inverse must go to Arbitrum for the bespoke intervention, Boring/Sky are worth citing but don't substantially de-risk the ask.

Additional political dynamics visible in the threads that shift odds at the margin:

- **Maintenance Upgrades Working Group** (`@krst`, L2BEAT, announced around Boring post #34): a nascent effort to delegate routine gateway ops to an AAE. If stood up in time, could reduce DOLA's component A to a non-vote. This materially helps Inverse *only* for component A.
- **Sky's cancelled-and-resubmitted Tally proposal** (post #80–82): shows the DAO and Foundation are forgiving of payload mistakes, but also shows the cost of those mistakes (6+ weeks of delay). Inverse must budget for at least one payload-correction cycle.
- **Griff (post #23, Sky)** and multiple delegates called for OCL to drive these proposals rather than projects. OCL is demonstrably unwilling to do that — they gate on project-paid audit and project-prepared payload. Inverse should not expect OCL to propose on their behalf.
- **No delegate in either thread engaged with precedent risk seriously** — GensDAO's questions in Sky #26 were the closest, and they were answered with a one-paragraph reply and accepted. This is weakly positive for DOLA: the DAO is not looking hard for precedent risks in gateway proposals.

---

## 5. Framing and drafting guidance for Inverse's eventual proposal

Drawing directly from what worked in these threads:

1. **Lead with the routine component, not the novel one.** Open the proposal with the `setGateway` registration (copy Boring post #1's one-paragraph abstract) and place the bespoke legacy-claim-neutralization lower in Specifications. Do not title it "Disable DOLA legacy bridge" in Tether style — that signals the novel ask. A title like "Register DOLA custom gateway and retire legacy escrow path" keeps pattern-matching to Boring/Sky active.
2. **Pre-wire OCL and Foundation engagement before filing.** Both Boring (`@krst` #34) and Sky (`@SpikeWatanabe` #22, `@Jose_StableLab` #10) took this to OCL privately first and arrived at the forum with GAC + audits in hand. File nothing until:
   - OCL has scoped the governance action contract(s),
   - Inverse has engaged a separate firm for audit of both the Inverse-side and the governance-action side (ChainSecurity, Cantina, and Certora are the three names that build credibility with this DAO),
   - The Foundation has greenlit the payload shape,
   - L2BEAT (`@krst`) is briefed as a natural ally who has supported every similar proposal and explicitly drives them onchain.
3. **Pre-empt the "what's in it for Arbitrum?" objection.** Boring's strongest defense was SuperBoring's existing volume. Sky's was Spark Liquidity Layer. Inverse's equivalents are thin — frame the ecosystem benefit around (i) removing a 1.9M DOLA systemic overhang that threatens cross-chain stablecoin credibility on Arbitrum, (ii) clearing the path for a future healthy DOLA deployment on Arbitrum, (iii) setting a clean precedent for post-exploit hygiene that strengthens Arbitrum's L2 legitimacy vs. peers. Do not leave this section thin.
4. **Explicitly state non-endorsement and DAO-retained levers.** Take Danielo's Boring #6 request as written: state that the DAO is not endorsing DOLA as a token, merely performing an infrastructure hygiene operation. Mirror Sky #22's structure: "after this proposal, Arbitrum DAO retains the ability to [revert] [disable] [unmap] the DOLA mapping at any time, without Inverse's consent."
5. **Address pre-existing escrow head-on.** This is the unique risk nothing in the precedents pre-answers. Inverse must proactively:
   - Identify the exact balance and its controller(s) (already done: 1,899,702.79 DOLA at `0x0615dbba33fe61a31c7ed131bda6655ed76748b1`).
   - Show that the legacy claim is real, time-bounded, and adversarial (not a live protocol's).
   - Propose a specific, auditable mechanism for neutralizing it (preferred in the research: Option C L1-side operator move; fallback: an L2 gateway token-scoped revert or beacon upgrade that reverts `bridgeBurn` for DOLA).
   - Cite the USDT `DisableGatewayAction` precedent for "Arbitrum DAO will ship token-specific logic into shared bridge infrastructure" — it's the closest analogue and already cited in `governance.md`.
6. **Invoke Boring, Sky, and RARI by name.** All three threads engage in heavy pattern-matching to RARI. Adding DOLA as the fourth on a list of four is cheap and raises the "this is routine" frame. Expect `@krst`, `@Euphoria`/Lampros, `@Tane`, `@Jose_StableLab`, and `@Hawheik` to pattern-match on their own.
7. **Budget 3–4 months forum→execution, plus a payload-correction cycle.** Boring: ~3 months. Sky: ~4 months with a cancelled-and-resubmitted onchain proposal due to a unit-mismatch bug. DOLA's action will be more complex than Sky's, so 4–5 months minimum.
8. **Be ready for delegate complaint about the Constitutional bar.** Do not argue against it — acknowledge and endorse the Maintenance Upgrades Working Group in the same breath (quote `@krst` from Boring #34 and Sky #66). This was a tonal requirement delegates rewarded in both threads.
9. **Do not frame as an emergency / Security Council fast-track.** The Council avoids dead-bridge cleanups (see `governance.md` §1.4) and neither Boring nor Sky took that route. Filing SC-first would be a novel escalation on top of an already-novel substantive ask.
10. **Prepare the post-mortem of Inverse's Multichain exposure in advance.** Sky's post #81 post-mortem about the payload error is a model of tone. Inverse should have its "here's what happened, here's what we did, here's who's affected" summary on the transparency page and linked from the forum post so delegates do not have to read external news.

---

## Sources

- Discourse JSON API, topic 29206 (Boring), 47 posts fetched 2026-04-14.
- Discourse JSON API, topic 28617 (Sky), 103 posts fetched 2026-04-14.
- Tally result posts: Boring #46 (2025-08-14), Sky #105 (2025-07-03).
- OCL confirmation posts: Boring #35 (2025-07-31), Sky #83 (2025-06-19).
- Arbitrum Foundation post: Sky #82 (2025-06-17).
- Cross-references: `/private/tmp/tmp.flesh.7gbC/research/DOLA_multichain_research.md`, `/private/tmp/tmp.flesh.7gbC/research/feasibility/governance.md`, `/private/tmp/tmp.flesh.7gbC/research/feasibility/option-d-custom-gateway.md`, `/private/tmp/tmp.flesh.7gbC/research/recent_proposals/props.md`.
