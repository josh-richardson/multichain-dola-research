# Feasibility Memo — Option C: L1-Side Escrow Neutralization

Date: 2026-04-14
Author: Inverse restitution research (for joshua@richardson.tech)
Scope: Can Inverse unilaterally, from L1 only, neutralize the legacy Arbitrum bridge claim on L1 DOLA escrow without any Arbitrum-side cooperation?

---

## Summary (verdict)

**Option C is not viable as an L1-only unilateral action.**

- **C1 (Escrow drain)** — **Not possible.** The L1 DOLA ERC20 gives the operator/minters *no* ability to seize, freeze, or move third-party balances. There is no `transferFrom(anyone, ...)` primitive, no pause, no blacklist, no rescue function. The escrow (the L1 `L1ERC20Gateway` at `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC`) holds the DOLA as a legitimate ERC20 balance. Moving it requires the gateway itself to call `transfer`/`approve`, and that gateway is controlled by the Arbitrum DAO (transparent proxy admin), not Inverse.
- **C2 (Transfer blacklist via upgrade)** — **Not possible.** L1 DOLA is a plain, non-proxied Solidity 0.5.16 ERC20. No upgrade mechanism exists. No governance-added transfer hook exists. The contract is immutable for logic purposes.
- **C3 (Full token migration)** — **Technically possible, economically catastrophic.** Inverse *can* deploy a new DOLA, mint to legitimate holders via snapshot, and abandon the old DOLA. But this breaks every DeFi integration of L1 DOLA (Curve, Balancer, FiRM collateral/debt accounting, Feds, Aave-like markets, Fed PCV, OTC positions, multisigs, CEXes). It is a protocol-wide redeploy event and is not meaningfully "unilateral" except in the narrow legal sense that no Arbitrum vote is required.

**Bottom line on unilaterality:** There is no L1-only path that both (a) preserves L1 DOLA as currently integrated and (b) neutralizes the Arbitrum escrow claim. The minimum unilateral L1 change that actually neutralizes the claim is a full token migration (C3), and that is a worse outcome than simply accepting that Arbitrum cooperation is required.

---

## 1. L1 DOLA upgradeability and operator powers

Source: `/private/tmp/tmp.flesh.7gbC/research/artifacts/dola-l1.json`
Token: `0x865377367054516e17014CcdED1e7d814EDC9ce4`

### Upgradeability

**L1 DOLA is NOT upgradeable.** The verified source is a single-contract, Solidity 0.5.16 `ERC20` with no `delegatecall`, no proxy hooks, no implementation slot, no beacon. The bytecode at the address *is* the logic. There is no governance-controlled lever that can change `_transfer`, add pausing, or add a blacklist.

### Complete operator / minter power enumeration

From the contract source, the full surface is:

| Function | Who | What it does |
|---|---|---|
| `setPendingOperator(address)` | `onlyOperator` | Nominates a new operator |
| `claimOperator()` | pending operator | Accepts operator role |
| `addMinter(address)` | `onlyOperator` | Grants mint right to an address |
| `removeMinter(address)` | `onlyOperator` | Revokes mint right |
| `mint(address, uint)` | operator OR minter | Creates new DOLA to `to` |
| `burn(uint)` | anyone (self) | Burns `msg.sender`'s own DOLA |

**What the operator CANNOT do:**

- Cannot pause (no pause function, no pause variable, no pauser role).
- Cannot blacklist (no blacklist mapping, no transfer hook).
- Cannot freeze a specific address (no such primitive).
- Cannot `transferFrom` arbitrary addresses (no admin approval, no seizure function).
- Cannot burn another user's balance. `burn(uint)` always burns `msg.sender`. There is no `burnFrom`, no admin burn.
- Cannot rescue escrowed tokens.
- Cannot upgrade logic.

The only offensive powers are **inflationary** (mint, add minter). There is no *subtractive* or *restrictive* primitive against holders.

This is verified by direct reading of the attached verified source; no remote verification was done (contract is immutable so source alone is authoritative).

---

## 2. L1 escrow sizing

Verified onchain via `https://ethereum-rpc.publicnode.com` on 2026-04-14:

- `L1GatewayRouter.getGateway(DOLA_L1)` = `0xa3A7B6F88361F48403514059F1F16C8E78d60EeC` (L1 StandardERC20Gateway for DOLA)
- `DOLA_L1.balanceOf(gateway)` = **1,935,010.023641336370430484 DOLA**
- `DOLA_L1.totalSupply()` = 136,098,118.240939048310629383 DOLA
- Arbitrum L2 DOLA `totalSupply()` = 1,935,009.923641336370430383 DOLA (from prior research)

Observations:

1. The L1 escrow (1,935,010) *exactly matches* L2 total supply (within rounding — the tiny ~0.1 delta is consistent with L2 dust burned outside the gateway path, or unresolved in-flight messages). The canonical Arbitrum bridge accounting is consistent: every L2 DOLA has a matching L1 escrow claim.
2. The Multichain router on Arbitrum holds ~1,899,703 L2 DOLA, which is 98.2% of the entire L2 supply. If compromised, Multichain could burn all of it and redeem 1.9M L1 DOLA from this escrow.
3. **The escrow is fully collateralized.** The previous memo's implicit concern — that maybe the L1 escrow is smaller than the L2 supply, capping damage — is NOT the case. Full redemption is possible and fully funded.
4. The escrow is a trivial 1.4% of L1 DOLA total supply. Losing it would not materially inflate DOLA if Inverse had to write it off, but it *would* create double-claim bad debt if replacement DOLA is also minted.

---

## 3. C1 — Escrow drain by operator

**Verdict: IMPOSSIBLE on L1 without Arbitrum cooperation or a token-level primitive that does not exist.**

### Mechanics check

The L1 StandardERC20Gateway holds DOLA as a normal ERC20 balance. ERC20 semantics: only the holder can `transfer`, or an approved spender can `transferFrom`. The gateway has not approved anyone, and DOLA has no admin-override transfer path.

Therefore moving that balance requires *the gateway itself* to execute a transfer. Options:

1. **Upgrade the gateway to add a drain path.** The gateway at `0xa3A7...EeC` is an OZ transparent proxy (confirmed: selectors `upgradeTo`, `changeAdmin`, `admin`, `implementation`). Its proxy admin is the Arbitrum DAO multisig / upgrade executor. **Not Inverse-controllable.**
2. **Get the gateway to voluntarily transfer out.** This is what a legitimate L2-to-L1 withdrawal does (after the L2 outbound message). It cannot be triggered from L1.
3. **Token-level rug.** Would require a `seize` or admin-transfer function in DOLA. **Does not exist and cannot be added** (DOLA is immutable, see §1).

### Indirect attempts that also fail

- Inverse adds itself as minter and mints a matching supply to cover the escrow: this does not drain the escrow, it only inflates, and the 1.9M double-claim is still live.
- Inverse mints tokens and tries to front-run a withdrawal: the gateway would still release its existing 1.9M on withdrawal regardless of new mints elsewhere.

**C1 is not feasible.**

---

## 4. C2 — Transfer blacklist via token upgrade

**Verdict: IMPOSSIBLE. L1 DOLA is not upgradeable.**

A conditional revert like `if (from == gateway && to == legacyRecipient) revert()` would require replacing the DOLA bytecode. That requires either:

- a proxy (there is none), or
- an EIP-7702-style code override (not applicable to a contract account), or
- an EVM upgrade that allows arbitrary bytecode replacement (does not exist on mainnet).

Technically "C2" reduces to "deploy new DOLA", which is C3.

---

## 5. C3 — Token migration + minter swap

**Verdict: Technically possible, but catastrophic blast radius. Not a realistic Option C.**

### What it would require

1. Deploy `DOLAv2` with the same operator/minter model.
2. Snapshot all legitimate L1 DOLA holders (everywhere DOLA is credited: wallets, LP shares, FiRM, Feds, lending markets, CEXes, bridges other than the frozen Arbitrum one).
3. Coordinate 1:1 reissuance of DOLAv2 to each legitimate holder.
4. Redeploy or upgrade every Fed (Curve Fed, Convex Fed, FiRM Fed at `0x2b34548b865ad66a2b046cb82e59ee43f75b90fd`, any AMM Feds) to reference DOLAv2.
5. Unwind every Curve/Balancer/Uniswap pool containing L1 DOLA (DOLA/FRAXBP, DOLA/3pool, DOLA-sUSDe, DOLA-sUSDS, DOLA-scrvUSD, Balancer DOLA/USDC, etc.) and redeploy in DOLAv2.
6. Coordinate with CEX listings, aggregators (1inch/Paraswap), price feeds (Chainlink, if any), DEX routers, and every integration that hardcodes `0x86537...`.
7. Handle in-flight cross-chain messages (Optimism, Base, Arbitrum legitimate path post-migration, etc.) that reference the old DOLA address.

### Known major L1 DOLA integrations (non-exhaustive — unverified scope)

From Inverse docs and prior research (all *unverified* here except the FiRM Fed address):

- **FiRM Fed**: `0x2b34548b865ad66a2b046cb82e59ee43f75b90fd`
- **FiRM markets using DOLA debt**:
  - Convex DOLA-sUSDe `0xb427fc22561f3963b04202f9bb5bcebd76c14a99`
  - Yearn DOLA-sUSDe `0x4e264618dc015219cd83dbc53b31251d73c2db1a`
  - Convex DOLA-sUSDS `0xD68d3a44d46dd50BFeBa8Cca544717B76e7C4b29`
  - Yearn DOLA-sUSDS `0x4A33baFA8a31E4ec9649f65646022cAD1957808b`
  - Convex DOLA-wstUSR `0xe4D47Ef77AC2C3FA4019Cd169Ac1Dd9E27cb12E4`
  - Yearn DOLA-wstUSR `0x28684485369f7478f42aAA62660123AB5D573537`
- **Curve DOLA pools**: DOLA-FRAXBP, DOLA-3pool, DOLA-scrvUSD (`0xff17dab22f1e61078aba2623c89ce6110e878b3c`), DOLA-sUSDS (`0x8b83c4aa949254895507d09365229bc3a8c7f710`), DOLA-sUSDe
- **Balancer**: historical DOLA-USDC stableswap (BIP-148)
- **Bridges**: canonical Arbitrum escrow (the one we're trying to neutralize), any Optimism/Base standard bridge escrows, LayerZero OFT adapters if any, Wormhole wrappers if any
- **Treasury / multisigs**: the `0x926d...9D5B` Treasury and associated sub-treasuries

### Blast radius

- **DAO-level disruption**: Every Fed must be paused, drained, migrated, reseeded. Every FiRM market has DOLA debt denominated in old DOLA; switching collateral/debt-token reference mid-flight is extremely dangerous (MEV, oracle desync, liquidation cascades).
- **External disruption**: LPs in Curve/Balancer need to withdraw old DOLA and deposit new DOLA. Price oracles and routing infrastructure need updating. CEXes need to pause/relabel/re-list.
- **Trust damage**: A "migration because legacy claim is still outstanding" message signals that Inverse is willing to devalue its own token by edict. Even if done correctly, this sets a governance precedent with systemic costs.
- **Cost**: weeks to months of coordination; substantial gas; probable short-term peg deviation; likely net TVL outflow.

### Does it actually neutralize the claim?

**Only economically, not cryptographically.** The old L1 DOLA at `0x86537...` still exists. The 1.9M sitting in the Arbitrum escrow can still be released to whoever redeems via L2. They receive "old DOLA" — which is still an ERC20, still has the ticker "DOLA" on block explorers until explorers are updated, and may still have residual liquidity (e.g. leftover LPs that didn't migrate, OTC desks). It is *valueless only if* Inverse succeeds in moving 100% of legitimate economic activity to DOLAv2. Any residual market for old DOLA becomes a leaked value channel.

In practice this is probably "close enough" in the sense that a Multichain hacker with 1.9M old DOLA would struggle to dump it for meaningful value. But it is not a clean cryptographic neutralization — it is an economic one.

**C3 is technically possible but a protocol-level event that is more disruptive than accepting Arbitrum-cooperative options.**

---

## 6. Comparison to Arbitrum-cooperative options (A / B / D)

(Summarized from prior research; not re-derived here.)

| Option | What it does | Arbitrum cooperation | L1 DOLA migration required | Residual risk |
|---|---|---|---|---|
| A (router disable) | `setGateway(DOLA, address(1))` | Arbitrum governance vote | No | HIGH — direct L2 gateway path still works, does not neutralize claim |
| B (L2 token upgrade) | Upgrade Arbitrum DOLA beacon to block `bridgeBurn` from Multichain router | Arbitrum governance + beacon owner cooperation | No | LOW — surgically disables redemption |
| C1 (L1 drain) | Seize escrow | N/A — impossible | N/A | N/A |
| C2 (L1 blacklist upgrade) | Upgrade DOLA to block gateway transfers | N/A — impossible | N/A | N/A |
| C3 (L1 migration) | New DOLA | None needed | YES, everywhere | MEDIUM — residual leak via any surviving old-DOLA liquidity |
| D (custom L1 gateway + Arbitrum outbox filter) | Bespoke outbox message filter or custom L1 gateway that rejects specific withdrawal messages | Arbitrum cooperation likely required | No | LOW but complex |

**C3 is the only Option C that technically works, and it is strictly worse than B (L2 token upgrade) if Arbitrum is willing to cooperate**, because B:

- leaves L1 DOLA untouched,
- preserves every DeFi integration,
- targets only the specific attacker pathway,
- does not require snapshotting or reissuing anything.

C3 only becomes the preferred option if Arbitrum governance definitively refuses B-style cooperation AND Inverse accepts writing off/reissuing every L1 integration.

---

## 7. Recommendation

**Drop Option C from the active proposal set, but keep C3 as a documented "nuclear fallback."**

Rationale:

1. C1 and C2 are impossible. They should not be argued further; they waste governance and audit cycles.
2. C3 is possible but strictly dominated by any Arbitrum-cooperative solution (A/B/D) on every axis except Arbitrum-vote-independence.
3. C3 retains optionality as a *credible threat* for negotiations with Arbitrum: "if Arbitrum will not ship a DOLA-specific bridge disable, Inverse will migrate L1 DOLA and leave the escrow stranded, which makes the Arbitrum bridge escrow a dead balance and slightly embarrasses the shared bridge." That threat is only credible if the DAO is actually willing to pay the migration cost.
4. The real technical work should focus on Option B (L2 DOLA logic upgrade via the beacon at `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`, owned by `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`) and engaging with the Arbitrum DAO to either execute that upgrade or ship a DOLA-specific bridge-disable action.

### Minimum L1-only change that actually neutralizes the claim

There is no minimum L1 change that preserves the existing L1 DOLA address. The only L1-only path is C3 — full token migration — which is not "minimum" in any meaningful sense. State plainly: **there is no unilateral, non-disruptive L1 path to neutralize the Arbitrum escrow claim.**

---

## Unverified claims flagged

- FiRM market addresses and Curve/Balancer pool list are taken from Inverse docs / public search and were not independently balance-checked for this memo. They are illustrative of blast radius, not authoritative.
- The proxy admin of the L1 gateway is inferred from selector pattern (OZ transparent proxy); actual `admin()` was not called via eth_call (would have required an eth_call with zero `from` spoof due to transparent proxy admin-protection, not done here). Prior Arbitrum docs confirm Arbitrum DAO owns this upgrade path.
- The ~0.1 DOLA delta between L1 escrow and L2 supply was not root-caused. Immaterial to the memo's conclusions.
- No verification was done that DOLA is referenced by any Chainlink or other oracle; if it is, that expands C3's blast radius.
