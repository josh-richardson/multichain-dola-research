# SUPERSEDED: One-shot bridge escrow rescue precedent research

> Historical precedent analysis. The reviewed precedent boundary is consolidated in `../GOVERNANCE.md`.

**Date:** 2026-04-14
**Prepared for:** Inverse Finance recovery proposal feasibility
**Question:** Has Arbitrum (or comparable L2) governance ever authorized a one-time transfer of value *out of a bridge escrow contract* back to a protocol or affected users?

**Short answer:** No. Not in Arbitrum. Not in any comparable L2 governance that I could locate. The closest analogue is a protocol team counter-exploiting (Jump/Wormhole) or external capital backstopping losses (Binance/Ronin) — neither is a DAO-authorized escrow rescue. For Multichain specifically, zero chains have rescued trapped assets via on-chain governance action; all remediation has been off-chain (lawsuits, liquidation).

---

## 1. Arbitrum DAO findings

### Method
Cloned `ArbitrumFoundation/governance` (main, April 2026) and enumerated every file under `src/gov-action-contracts/`. Read every file named like an AIP action or token-bridge action. Searched the repo for strings `rescue`, `stranded`, `stuck`, `recover`, `sweep`, `transfer`, `safeTransfer` inside the gov-action tree. Cross-referenced with forum search via `forum.arbitrum.foundation/search.json` for the queries in the brief.

### Every action-contract directory in the governance repo
- `AIPs/` — AIP1.1, AIP1.2, AIP4, AIP7, AIP4844, AIPArbOS31, ArbOS11, NomineeGovernorV2Upgrade, SetSeqMaxTimeVariation, SecurityCouncilMgmt, AIPNovaFeeRouting. All are either constitution/governor config changes, ArbOS/WASM module upgrades, 4844 / batch-poster changes, or fee-distributor re-wiring. **None move tokens out of a bridge escrow.**
- `address-registries/` — registry plumbing, no value transfer.
- `arb-precompiles/` — `SetSpeedLimit`, `SetL2BaseFee`, `AddChainOwner`, `ReleaseL1PricerSurplusFundsAction`, etc. `ReleaseL1PricerSurplusFundsAction` is the single "release value" action — and it releases *pricer surplus* via the `ArbOwner` precompile, not escrowed user deposits. Not an escrow rescue.
- `arb-token/MintArbTokenAction` — mints ARB. Not a rescue.
- `arbos-upgrade/` — ArbOS version bumps and WASM module root changes.
- `governance/` — CancelTimelock, CancelTreasuryGovProposal, SetConstitutionHash, SetCoreGovernorQuorum.
- `gov-upgrade-contracts/` — generic `ProxyUpgradeAction`, `ProxyUpgradeAndCallAction`, plus rollup-upgrade variants. Generic machinery; not a rescue.
- `nonemergency/` — `SwitchManagerRolesAction`, `AddNovaKeysetAction`.
- `pause-inbox/` — `PauseInboxAction`, `UnpauseInboxAction`.
- `rollup/` — validator whitelist, pause/unpause rollup, force-confirm assertion.
- `sequencer/` — Add/Remove sequencer, SetMaxTimeVariation.
- `set-outbox/` — Add/Remove/Set outboxes on Bridge. This is the outbox registry on the core Bridge contract, not the ERC-20 token-bridge escrow. No value movement.
- **`token-bridge/`** — the directory with the gateway-facing actions. Full enumeration:
  - `TokenBridgeActionLib.sol` — trivial helper that checks addresses are contracts.
  - `SetGatewayAction.sol` — calls `L1GatewayRouter.setGateways(tokens, gateways, ...)`. Pure routing config.
  - `DisableGatewayAction.sol` — points a token's gateway to `address(1)` (the sentinel "disabled" address). Used in the USDT legacy-gateway cleanup (forum topic 29503). **Does not move escrowed tokens; existing escrow is explicitly left untouched (~$140k USDT remains stuck by design).**
  - `RegisterL2TokenInArbCustomGatewayAction.sol` — custom-gateway token registration.
  - `RegisterAndSetArbCustomGatewayAction.sol` — `forceRegisterTokenToL2` plus `setGateways`. Registration only; no value movement.
- `treasury/` — `TransferERC20FromTreasury`, `TransferArbFromTreasury*`. These move *from the DAO treasury wallet*, not from a gateway escrow. Routine.
- `util/` — `OfficeHoursAction`, `ActionCanExecute`.

### Search results
- `grep -ri "rescue|stranded|stuck|recover|sweep"` under `src/` returned only four hits, all irrelevant: `TokenDistributor.sol` (airdrop sweep), `SetSweepReceiverAction.sol` (redirects airdrop unclaimed to DAO treasury), and two security-council governor files.
- Forum search via Discourse API for "rescue escrow" → zero posts. For "stranded", "locked tokens bridge", "emergency withdrawal", "stuck funds", "recover tokens" → many hits, none of which describe an executed AIP that moved value out of a bridge escrow. The most relevant thread (topic 29503, USDT0 / legacy USDT gateway) **deliberately chose not to rescue escrowed USDT** — the proposal disables deposits and leaves the ~$140k stuck in the gateway untouched.

### Candidates checked and rejected
- **AIP1.2 sweep action** — only moves airdrop unclaimed tokens from a distributor to treasury. Not a bridge contract.
- **ReleaseL1PricerSurplusFundsAction** — releases ArbOS L1-pricing surplus via precompile. Not a bridge.
- **Nova fee-routing AIP** — changes recipient wiring on reward distributors. Not a bridge.
- **USDT0 gateway disable (29503, 2025)** — *strongest tonal case*, but it explicitly does **not** transfer the escrowed USDT. This is the single cleanest statement of the DAO's posture: they confronted the exact shape of the problem (deprecated gateway with orphaned escrow) and declined to touch the funds.

### Answer to framing question 1
**No.** There is no executed Arbitrum AIP, no merged gov-action contract, and no forum thread evidencing an approved one-time transfer from a bridge/gateway escrow to a protocol or users. Arbitrum's only near-miss (the 2025 USDT gateway deprecation) made the opposite choice.

---

## 2. Other L2 findings

### Optimism
- The most-cited "recovery" story is the **Wintermute 20M OP incident (June 2022)**. This was **not an escrow rescue**. 20M OP was sent from the Optimism Foundation's *Partner Fund* to an undeployed Gnosis Safe; an attacker counter-deployed; ~17M was returned by the attacker voluntarily after on-chain negotiation, and Wintermute reimbursed the 2M kept as bounty. No DAO vote moved value out of a bridge.
- "Accelerated Decentralization" (GFX Labs, 2024) proposed *future* Token-House control of the L1 bridge escrow. The L1 bridge escrow was still Foundation-controlled through 2025. There is no record of an executed Token-House vote that withdrew value from `L1StandardBridge` to a protocol.
- Protocol upgrades (Upgrade Proposal #3, #4, bedrock, Granite, etc.) are upgrades of system contracts, not escrow withdrawals.

### Base
- Centralized control by Coinbase via the Optimism Security Council and Base-specific multisig. No community governance body exists that could authorize an escrow rescue. No record of one.

### Polygon zkEVM
- Being sunset in 2026 with a 12-month forced-withdrawal window. Users self-withdraw from escrow; no governance rescue primitive added. Polygon's Security Council can "Emergency State" pause all Agglayer chains but cannot move escrow to a third party.

### zkSync Era
- Token House (ZK token) governance still maturing. No executed escrow-rescue action located.

### Starknet
- Governance scope to date has been Cairo/sequencer/STRK-economics. No bridge-escrow rescue.

### Linea / Mantle
- Both controlled by foundation/Security Council. No community governance precedent of any kind for bridge-escrow rescue.

### Answer to framing question 2
**No.** No comparable L2 governance (not OP, not Base, not Polygon zkEVM, not zkSync, not Starknet, not Linea, not Mantle) has authorized a transfer of value out of a bridge escrow contract to a protocol or users as a one-time governance action.

---

## 3. Multichain-stranded-asset remediations across all chains

This is the most directly relevant comparator for Inverse, and the finding is striking: **no chain has executed an on-chain governance rescue of Multichain-stranded assets**.

- **Fantom Foundation** is the most active remediator. Its approach has been entirely **off-chain legal**: Singapore High Court winding-up petition against Multichain Foundation (default judgment January 30, 2024); third-party liquidator appointment funded partly by Fantom; pursuit of ~$70M for Fantom-side users. This is court-led, not DAO-led.
- **Moonriver, Dogechain, Kava, etc.** — no located governance action.
- **Arbitrum** — the Multichain `anyCall` contracts sit on Arbitrum; no Arbitrum DAO action has addressed them in any way.
- **BNB Chain, Polygon PoS, Ethereum L1** — no governance rescue.

The universal pattern after Multichain: **wait, litigate, and/or socialize losses**. Zero on-chain rescue primitives have been invoked.

### Answer to framing question 3
**No chain has performed a governance-authorized rescue of Multichain-trapped assets.** Fantom's litigation is the high-water mark of remediation efforts.

---

## 4. Closest tonal/adjacent precedents

In descending order of closeness to what Inverse needs:

1. **Arbitrum USDT gateway deprecation (2025, topic 29503).** Same shape of problem (obsolete gateway with orphaned escrow), Arbitrum DAO vote, *explicitly declined to rescue*. Tonally this is the **strongest negative precedent** and matters most for calibrating odds.
2. **Nomad bridge post-exploit redesign (2022).** Not governance-authorized; the Nomad team itself upgraded the bridge to enable pro-rata redemption from recovery pools. Protocol-team action, not DAO action. Shape is adjacent (add one-time redemption path to a bridge) but actor is different (team, not DAO).
3. **Wormhole / Jump (2022).** Jump Crypto replaced 120k ETH out of its own treasury; later counter-exploited the hacker. No governance vote; no escrow withdrawal; VC backstop.
4. **Ronin / Binance (2022).** $150M raised to make users whole; no DAO vote; no escrow withdrawal.
5. **MakerDAO Emergency Shutdown.** Governance-authorized value redistribution, but within Maker's *own* system (vaults, cdps) — not an extraction from a neutral bridge escrow on behalf of a third-party protocol. Shape is different: internal economic wind-down, not cross-protocol rescue.
6. **Optimism Accelerated-Decentralization proposal.** Proposed to *move custody* of the L1 escrow to governance — did not propose moving escrowed value anywhere. Governs the primitive, does not exercise a rescue.
7. **Poly Network.** Attacker returned funds voluntarily. No governance action; irrelevant to the primitive Inverse needs.

There is **no precedent in which a DAO passed a one-time action to transfer tokens out of a canonical bridge-escrow contract to a protocol's treasury to remediate stranded funds.** The closest is "add a one-time admin primitive to a bridge and immediately use it," which is the Nomad team's path — done unilaterally by the team, not by a DAO, and on a bridge the team controlled.

---

## 5. Honest verdict

**Unprecedented.**

I am using that word deliberately, not as hedge. Criteria:
- No Arbitrum DAO-executed action transfers value out of a bridge/gateway escrow. The one time the question was squarely presented (USDT gateway, 2025), the DAO said no by omission — disabled the gateway and abandoned ~$140k.
- No comparable L2 governance body has done it either.
- No chain has used governance to rescue Multichain-trapped assets specifically, despite >2.5 years and >$210M of demonstrated demand.
- The "adjacent" examples (Nomad, Wormhole, Ronin, Maker shutdown) are structurally different actors (team, VC, internal) or different primitives (replacement capital, not escrow extraction).

The reason "unusual" is too mild: I looked specifically for *anything shaped like this* and the closest hit is a DAO vote that confronted the primitive and declined to use it. "Rare" would imply ≥1 example exists; I found zero. A generous reader could argue "Nomad relaunch" counts — but that's a team-controlled bridge with a team-deployed upgrade, not a DAO-authorized rescue, so I exclude it under the brief's strictness clause.

**What is unusual, not unprecedented:** adding a one-shot admin primitive to a governance-controlled contract via upgrade (routine), and moving DAO-treasury funds to reimburse affected users (routine). The unprecedented part is the combination: using DAO power to reach into a canonical bridge escrow and pay out to a third-party protocol.

---

## 6. Implications for Inverse's odds

**Political readout.** Inverse will be asking Arbitrum (or whichever L2 holds the escrow) to do something that body has never done before and has, once, explicitly chosen not to do. Delegates who index on precedent will treat this as a **novel primitive** and default to conservatism. Expect:
- Extended forum discussion and RFC phase before anything touches Tally.
- Demands for legal opinion (the Fantom/Multichain litigation track sets an expectation that off-chain process is the "right" path).
- Security-Council / L2BEAT scrutiny: any action on a gateway contract will be reviewed at a level closer to an ArbOS upgrade than a grant.
- Precedent-setting framing will dominate: "if we do this for Inverse, who's next?"

**What improves odds.**
- Narrow the primitive: a one-shot, self-destructing admin function that targets only the specific stranded amount for the specific affected token/address; not a generic `adminWithdraw`.
- Verifiable external audit plus Security-Council sign-off designed in from proposal day one.
- Off-chain paperwork: clear non-custodial attestation from Inverse, chain-of-custody evidence that the trapped funds are unambiguously Inverse's (this is the single most load-bearing thing — Arbitrum's USDT decision suggests the DAO's instinct is "don't touch funds of unclear provenance").
- Precedent-distinguishing narrative: explain why this is *not* a general rescue primitive (e.g., Multichain-specific, stranded by a defunct third party, no other redemption path exists, specific user-verifiable ownership).
- Pre-socialize with large delegates (L2BEAT, Wintermute, Gauntlet, ARDC) before forum posting.

**What hurts odds.**
- Any framing that reads as "DAO treasury compensates Inverse." Inverse is not asking the DAO to spend; Inverse is asking the DAO to hand Inverse *Inverse's own money*. That framing must be relentless.
- Comparable dollar value to USDT-in-legacy-gateway (~$140k) that the DAO recently chose to leave behind. If the USDT holders didn't get rescue, Inverse needs a clean distinguishing factor (custody-verified ownership; no alternative redemption path; specific end-users harmed).
- Generality: if the proposal even looks like it's creating a reusable rescue pattern, delegates will resist.

**Honest bottom line.** The absence of precedent is not disqualifying, but it materially raises the bar. A well-run precedent-distinguishing proposal with Security-Council design partnership is plausible. A "routine treasury ask" framing will fail. Plan for a 3–6 month cycle and budget serious governance-engineering effort; this is AIP-grade work, not a grant application.

---

## Appendix: Sources

- [ArbitrumFoundation/governance (GitHub)](https://github.com/ArbitrumFoundation/governance) — enumerated `src/gov-action-contracts/` directly
- [Arbitrum forum topic 29503 — legacy USDT gateway disable](https://forum.arbitrum.foundation/t/29503)
- [Arbitrum forum topic 29635 — DIP v1.7 (non-relevant, checked)](https://forum.arbitrum.foundation/t/29635)
- [Arbitrum forum Discourse search API](https://forum.arbitrum.foundation/search.json)
- [Fantom v. Multichain Singapore High Court default judgment coverage — CoinDesk](https://www.coindesk.com/business/2024/03/05/fantom-seeks-money-back-from-multichains-200m-exploit)
- [Fantom Foundation Multichain liquidation — Coinspeaker](https://www.coinspeaker.com/fantom-liquidate-multichain-exploit-70m/)
- [Multichain exploit analysis — Halborn](https://www.halborn.com/blog/post/explained-the-multichain-hack-july-2023)
- [Wintermute / Optimism 20M OP incident — CoinDesk](https://www.coindesk.com/tech/2022/06/09/15m-of-optimism-tokens-stolen-by-an-attacker-after-wintermute-sent-wrong-wallet-address)
- [Wormhole / Jump Crypto replenishment — Decrypt](https://decrypt.co/91962/crypto-bridge-wormhole-replenished-after-hack-320m-ethereum)
- [Ronin / Sky Mavis recovery — Cointelegraph](https://cointelegraph.com/news/sky-mavis-recovers-5-7m-ronin-bridge-hack)
- [Nomad bridge relaunch / recovery — Nomad Medium](https://medium.com/nomad-xyz-blog/the-road-to-recovery-6abe5eec8ff1)
- [Poly Network exploit — Wikipedia](https://en.wikipedia.org/wiki/Poly_Network_exploit)
- [MakerDAO Emergency Shutdown docs](https://docs.makerdao.com/smart-contract-modules/shutdown/the-emergency-shutdown-process-for-multi-collateral-dai-mcd)
- [Optimism Accelerated Decentralization proposal](https://gov.optimism.io/t/accelerated-decentralization-proposal-for-optimism/8875)
- [Polygon zkEVM sunset — L2BEAT](https://l2beat.com/scaling/projects/polygonzkevm)
