# DOLA / Multichain Restitution Research

Date: April 14, 2026

## Scope

This memo summarizes the research completed so far on whether Inverse DAO could make whole holders of Multichain-linked DOLA on chains such as BSC without exposing the protocol to double-claim risk if the old Arbitrum-side balance is ever redeemed back to Ethereum mainnet.

The core question is:

Can Inverse safely reissue DOLA to affected holders if Multichain-controlled funds on Arbitrum might later be bridged back to mainnet and redeemed for real canonical DOLA?

## Local files reviewed

- `message.txt`
- `DOLA Multichain Hack Analysis.pdf`

The local write-up correctly separated:

- recovery of the trapped Arbitrum-side balance, and
- forward migration away from Multichain

It also correctly identified the critical unresolved issue: whether the old Arbitrum-side balance can be neutralized onchain, rather than merely deprecated socially or economically.

## Verified onchain findings

### 1. BSC DOLA is a Multichain wrapper, not canonical Inverse DOLA

Token:

- BSC DOLA: `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840`

Verified contract type:

- `AnyswapV6ERC20`

Important contract properties:

- `underlying() = 0x0000000000000000000000000000000000000000`
- `vault() = 0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7`
- `owner() = 0xF7Da4bC9B7A6bB3653221aE333a9d2a2C2d5BdA7`
- `getAllMinters() = [0x58892974758A4013377A45fad698D2FF1F08d98E]`

Interpretation:

- this token is a Multichain-issued synthetic wrapper,
- it is not directly redeemable via an underlying token held by the BSC wrapper itself, because `underlying = 0x0`,
- and it is not controlled by Inverse governance.

### 2. The queried BSC holder balances

BSC DOLA balances have been verified.

### 3. BSC wrapper supply

Verified total supply of BSC DOLA:

- `1,793,864.391064841026826353`

### 4. Arbitrum DOLA is the canonical Arbitrum bridge representation

Token:

- Arbitrum DOLA: `0x6a7661795c374c0bfc635934efaddff3a7ee23b6`

Verified contract type:

- `StandardArbERC20`

Verified properties:

- `l1Address() = 0x865377367054516e17014CcdED1e7d814EDC9ce4`
- `l2Gateway() = 0x09e9222E96E7B4AE2a407B98d48e330053351EEe`
- `totalSupply() = 1,935,009.923641336370430383`

Interpretation:

- this is the canonical Arbitrum bridge token representing L1 DOLA escrowed in the Arbitrum canonical bridge,
- not a Multichain token.

### 5. Multichain router balance on Arbitrum

Multichain router address discussed in the memo:

- `0x0615dbba33fe61a31c7ed131bda6655ed76748b1`

Verified Arbitrum DOLA balance:

- `1,899,702.791056052107486162`

This is the critical trapped / dangerous balance.

### 6. Remaining Arbitrum DOLA outside the Multichain router

Computed from total supply minus router balance:

- `35,307.132585284262944221`

So almost the entire live Arbitrum DOLA supply is concentrated in the Multichain router balance.

### 7. Canonical Ethereum DOLA

L1 DOLA:

- `0x865377367054516e17014CcdED1e7d814EDC9ce4`

Verified contract model:

- immutable token contract with operator / minter controls

Verified operator:

- `operator() = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B`

Inverse docs identify that address as:

- `Treasury`

Interpretation:

- Inverse can, if governance approves, mint new canonical DOLA or add new minters.
- The issue is not issuance authority.
- The issue is avoiding a second live claim from the legacy Arbitrum bridge balance.

## Arbitrum bridge architecture findings

### 1. Standard bridge mechanics

Arbitrum docs confirm the standard ERC-20 bridge model:

- L1 token is escrowed on Ethereum.
- Matching L2 token is minted on Arbitrum.
- Withdrawal burns L2 balance and releases the L1 escrow after the normal withdrawal flow.

That is exactly why the old Arbitrum DOLA balance matters: it is a live claim on canonical mainnet DOLA escrow unless the old withdrawal path is disabled.

Source:

- <https://docs.arbitrum.io/how-arbitrum-works/deep-dives/token-bridging>

### 2. Arbitrum DOLA token upgradeability

The Arbitrum DOLA token is a beacon proxy.

Verified:

- proxy beacon slot points to `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`
- beacon implementation is `0x3f770Ac673856F105b586bb393d122721265aD46`
- beacon owner is `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827`

Interpretation:

- there is an Arbitrum-side upgrade lever in principle,
- but it is not under Inverse control.

### 3. Historical upgrades of the Arbitrum DOLA L2 gateway

Gateway proxy:

- `0x09e9222E96E7B4AE2a407B98d48e330053351EEe`

Verified `Upgraded(address)` events show the following implementation history:

1. `0x4bF6365278F340E759e7BB4732fE8B507784eAEB`
   - block `28753`
   - date `2021-06-26 14:01:05 UTC`
   - tx `0x4e12ef6c0cb9089632488f4796b6c46818908d29b4547432506dfd28e0e9017b`
   - unverified

2. `0x370ED500E9FEBC1ab05aC0A1617F8775aB80c48e`
   - block `224775`
   - date `2021-08-26 16:19:50 UTC`
   - tx `0x4493b489b9d332078d3dc0ead005a04be3be264a4f2bc32949c19529455804c6`
   - unverified

3. `0xEdE95739749BfA021134E41F520d784c99323D6B`
   - block `226784`
   - date `2021-08-30 17:47:17 UTC`
   - tx `0xaa2a503ca6469c771da72d0f04e2afcbe342d9491f620c6b0f7a553c972602da`
   - verified `L2ERC20Gateway`

4. `0x1DCf7D03574fbC7C205F41f2e116eE094a652e93`
   - block `19739408`
   - date `2022-08-08 17:33:55 UTC`
   - tx `0x1608ac4dc927c1b322d906419400226634fbf6e68e3fec72316d2e0a3b76c141`
   - verified `L2ERC20Gateway`

Limitations:

- the first two implementations are not verified on Arbiscan,
- so their exact source diffs are not recoverable from explorer data alone,
- but their bytecode size and function selector surface still allow some bounded inference.

#### `0x4bF6...` -> `0x370E...`

This looks like a relatively small early bridge-framework update.

Observed facts:

- bytecode shrank from about `6980` bytes to about `6800` bytes,
- the older implementation exposed a selector matching `gasReserveIfCallRevert()`,
- that selector disappears in `0x370E...`,
- the core gateway surface remained largely the same.

Best inference:

- this upgrade likely removed or simplified an older gas-reserve / revert-handling path tied to legacy bridge callback behavior,
- but it does not look like a major change to the gateway's basic withdrawal or deposit flow.

#### `0x370E...` -> `0xEdE9...`

This was the first clearly major change.

Observed facts:

- bytecode dropped sharply from about `6800` bytes to about `5730` bytes,
- the earlier bytecode surface included a selector matching `onTokenTransfer(address,uint256,bytes)`,
- that callback surface disappears in `0xEdE9...`.

The verified `0xEdE9...` source shows:

- the gateway rejects non-empty `_extraData` in `outboundTransfer(...)` with `EXTRA_DATA_DISABLED`,
- `finalizeInboundTransfer(...)` explicitly discards `callHookData`,
- the bridge logic is noticeably slimmer,
- the token metadata parser still uses the older permissive `BytesParserWithDefault` behavior.

Best inference:

- this upgrade removed older callback / callhook style behavior and simplified the bridge logic materially,
- but it still did not introduce any token-specific freeze or redemption-disable primitive.

#### `0xEdE9...` -> `0x1DCf...`

This is the only upgrade where exact source-level changes were diffed.

Substantive changes:

1. Counterpart authentication was tightened.

- In `0xEdE9...`, `onlyCounterpartGateway` accepted either:
  - `msg.sender == counterpartGateway`, or
  - `undoL1ToL2Alias(msg.sender) == counterpartGateway`
- In `0x1DCf...`, it was changed to require:
  - `msg.sender == applyL1ToL2Alias(counterpartGateway)`

Practical effect:

- inbound messages must now come through the canonical aliased L1-to-L2 sender path.

2. `StandardArbERC20` metadata handling became stricter.

- `0xEdE9...` used `BytesParserWithDefault`, which defaulted missing metadata to fallback values.
- `0x1DCf...` switched to `BytesParser` plus `ignoreName`, `ignoreSymbol`, and `ignoreDecimals` flags.

Practical effect:

- the Arbitrum token now mirrors L1 metadata behavior more faithfully,
- and `name()`, `symbol()`, or `decimals()` can revert when the corresponding L1 getter is absent, instead of silently defaulting.

3. `ITokenGateway` added `getOutboundCalldata(...)`.

Practical effect:

- this is mainly interface standardization and tooling surface,
- not a change to the core redemption model.

4. General cleanup / modernization.

- interface pragma cleanup,
- minor modifier / formatting cleanup,
- richer metadata / devdoc / userdoc output in the verified bundle.

Bottom line on upgrade history:

- `4bF6 -> 370E`: small early cleanup
- `370E -> EdE9`: major simplification, especially removal of old callback-style behavior
- `EdE9 -> 1DCf`: correctness hardening and metadata fidelity cleanup

Most important conclusion for the DOLA restitution question:

- none of these historical upgrades introduced a per-token freeze mechanism,
- none created an obvious one-token kill switch for outbound redemption,
- and the upgrade history looks like bridge framework maintenance, not precedent for trapping one token's live L2 balance.

### 4. L2 gateway behavior

The standard `L2ArbitrumGateway` code was inspected.

Critical finding:

- `outboundTransfer(...)` is public and can be used whether the caller is the router or a direct caller.
- If the caller is not the router, the gateway uses `msg.sender` as `_from`.
- The gateway then calls `bridgeBurn(...)` on the L2 token and triggers L2-to-L1 withdrawal messaging.

Why this matters:

- even if router mappings are changed, a holder of legacy Arbitrum DOLA can still use the old L2 gateway directly unless the gateway or token logic itself is changed.

This is the main reason ordinary gateway migration is not enough.

## Why a simple custom-gateway migration is not enough

Arbitrum docs support:

- registering a token to a custom gateway,
- and updating the router mapping via `setGateway`

That can change the canonical bridge path going forward.

However, that does **not** by itself stop the existing old Arbitrum DOLA from doing this:

1. call old L2 gateway directly,
2. burn old Arbitrum DOLA,
3. release escrowed canonical DOLA on Ethereum mainnet.

Therefore:

- migrating DOLA to a custom gateway does not remove the old claim,
- and reissuing DOLA before eliminating that old claim creates a double-claim / bad-debt scenario.

## Double-claim / bad-debt logic

If Inverse reissues replacement DOLA while the old Arbitrum bridge claim remains live, there are then two claims:

- claim A: replacement DOLA issued by Inverse to victims
- claim B: legacy Arbitrum DOLA still redeemable to Ethereum escrow

If Multichain or any party controlling the old Arbitrum balance later redeems that balance, the protocol has effectively honored both claims.

Under Inverse DAO's stated standard, this is unacceptable.

Conclusion:

- If the old Arbitrum DOLA can still redeem to L1, reissue is unsafe.

## USDT legacy bridge precedent

This was investigated specifically to see whether it is equivalent to what DOLA needs.

### 1. The relevant proposal

Proposal:

- `[Constitutional] AIP: Disable Legacy Tether Bridge`

Forum link:

- <https://forum.arbitrum.foundation/t/constitutional-aip-disable-legacy-tether-bridge/29503>

Important dates from public materials:

- audit summary dated March 12, 2025
- forum proposal dated June 25, 2025

### 2. What `DisableGatewayAction` actually does

Source inspected:

- `DisableGatewayAction.sol`

The action:

- builds a gateway array where each gateway is `address(1)`,
- then calls `L1GatewayRouter.setGateways(...)`.

In router code:

- `address(1)` is the sentinel `DISABLED`.
- `getGateway()` then returns `address(0)` for that token.

Effect:

- router-mediated bridge operations revert,
- and the disabled mapping is propagated to the L2 router as well.

### 3. Why the USDT case is not equivalent to DOLA

The USDT forum discussion makes clear:

- Tether had already upgraded the token side to `USDT0`.
- The DAO action was described as disabling / deactivating the legacy bridge for users.
- Arbitrum stated the legacy path already did not work as expected and that deposits would auto-withdraw back.

So the USDT action was an offboarding / router shutoff for a system that had already been externally migrated.

It did **not**:

- seize balances,
- freeze an L2 token contract,
- or prove that an existing live L2 claim on canonical L1 escrow can be neutralized.

Most importantly for DOLA:

- the USDT action only showed a router-level disable,
- while DOLA needs the direct old withdrawal path itself neutralized.

### 4. Bottom line on precedent

The USDT precedent is relevant only in this narrow sense:

- Arbitrum governance has shown willingness to ship token-specific bridge offboarding logic in shared bridge infrastructure.

It is **not** equivalent to the DOLA problem, because:

- DOLA's problem is a live legacy claim already sitting inside the canonical bridge path.

## Feasibility assessment so far

### What is clearly feasible

- Inverse can technically reissue canonical DOLA if governance approves.
- Inverse can snapshot affected holders on BSC and other impacted chains.
- Inverse can migrate future crosschain usage to safer systems.

### What is not sufficient

- social deprecation of old Multichain-linked DOLA
- ordinary gateway migration
- router remapping alone

None of those remove the risk that the old Arbitrum balance later redeems to mainnet.

### What would actually be sufficient

To satisfy the "no bad debt if Multichain ever moves again" requirement, the old Arbitrum claim must stop being redeemable to Ethereum mainnet.

That likely requires a bespoke Arbitrum-side change, such as:

- disabling the old gateway's direct outbound path for DOLA,
- or changing token / gateway logic so legacy Arbitrum DOLA can no longer burn for L1 release,
- or some equivalent DOLA-specific bridge-disable upgrade.

This is much stronger than the USDT `DisableGatewayAction`.

### Practical conclusion at this stage

If Arbitrum is unwilling to do a bespoke DOLA-specific bridge disable that actually blocks redemption of the old Arbitrum balance, then there is no practical path that meets Inverse DAO's stated zero-bad-debt requirement.

If Arbitrum is willing to do that bespoke work, then a path may exist, but it would be:

- custom,
- governance-heavy,
- and substantially more invasive than the USDT precedent.

## Key numeric summary

- BSC DOLA holder queried: `452,065.815694043047087335`
- BSC DOLA total supply: `1,793,864.391064841026826353`
- Arbitrum DOLA total supply: `1,935,009.923641336370430383`
- Arbitrum DOLA at Multichain router: `1,899,702.791056052107486162`
- Arbitrum DOLA outside router: `35,307.132585284262944221`

Comparison:

- The trapped Arbitrum router balance exceeds the entire BSC wrapper supply by `105,838.399991211080659809`.

So the Arbitrum-side claim is absolutely large enough to matter economically.

## Sources used

### Inverse

- Inverse smart contracts: <https://docs.inverse.finance/inverse-finance/inverse-finance/technical/smart-contracts>
- DOLA cross-chain guide: <https://docs.inverse.finance/inverse-finance/inverse-finance/products/tokens/dola/dola-cross-chain-guide>

### Arbitrum

- Arbitrum token bridging docs: <https://docs.arbitrum.io/how-arbitrum-works/deep-dives/token-bridging>
- USDT disable-gateway audit summary: <https://docs.arbitrum.io/assets/files/2025-03-offchain-disablegateway-action-securityreview-11ed2e1370d062c2ade5e5d6b085a8f3.pdf>
- USDT forum proposal: <https://forum.arbitrum.foundation/t/constitutional-aip-disable-legacy-tether-bridge/29503>
- `DisableGatewayAction.sol`: <https://github.com/ArbitrumFoundation/governance/blob/main/src/gov-action-contracts/token-bridge/DisableGatewayAction.sol>

### Explorers / verified contract sources

- BSC DOLA token: <https://bscscan.com/token/0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840>
- Arbitrum DOLA token: <https://arbiscan.io/token/0x6a7661795c374c0bfc635934efaddff3a7ee23b6>
- Multichain router on Arbitrum: <https://arbiscan.io/address/0x0615dbba33fe61a31c7ed131bda6655ed76748b1>
- L1GatewayRouter: <https://etherscan.io/address/0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef#code>

### Local files

- `message.txt`
- `DOLA Multichain Hack Analysis.pdf`

## Open next question

The next useful research step is narrower:

What exact Arbitrum-side code change would actually be sufficient to prevent legacy Arbitrum DOLA from redeeming to Ethereum mainnet?

That is now the critical technical question.
