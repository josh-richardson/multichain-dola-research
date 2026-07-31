# SUPERSEDED: DisableGatewayAction verification

> Historical technical verification. The result is summarized in `../GOVERNANCE.md`.

Date: 2026-04-14
Author (analyst): joshua@richardson.tech spike
Target executor: self / Inverse Finance ops
Method: primary-source read of Arbitrum source repos + live mainnet/arb1 RPC probing.
No files under `research/feasibility/` were consulted.

---

## 1. `DisableGatewayAction` exact state changes

Source: `ArbitrumFoundation/governance` → `src/gov-action-contracts/token-bridge/DisableGatewayAction.sol` (31 LOC).

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

contract DisableGatewayAction {
    IL1GatewayRouterGetter public immutable addressRegistry;

    function perform(
        address[] memory _tokens,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost
    ) external payable {
        TokenBridgeActionLib.ensureAllContracts(_tokens);
        address[] memory _gateways = new address[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _gateways[i] = address(1); // DISABLED GATEWAY
        }
        addressRegistry.gatewayRouter().setGateways{...}(
            _tokens, _gateways, _maxGas, _gasPriceBid, _maxSubmissionCost
        );
    }
}
```

It does exactly one thing: calls `L1GatewayRouter.setGateways(tokens, [address(1), …], …)`. Following the router (`contracts/tokenbridge/ethereum/gateway/L1GatewayRouter.sol` + `libraries/gateway/GatewayRouter.sol`):

- L1 state change: `l1TokenToGateway[token] = address(1)` for each token; emits `GatewaySet(token, 0x1)`.
- L2 state change: an L1→L2 retryable is sent calling `L2GatewayRouter.setGateway(tokens, gateways)`. For a disable, the `address(1)` sentinel is forwarded verbatim (the `if (_gateway[i] != address(0) && _gateway[i] != DISABLED) { _gateway[i] = counterpartGateway; }` branch is skipped), so the L2 router also records `l1TokenToGateway[token] = address(1)`.
- Read-side behavior: `GatewayRouter.getGateway(token)` returns `0x0` when the stored value is the DISABLED sentinel, causing `outboundTransferCustomRefund` on the L1 router to call `0x0.outboundTransferCustomRefund{value:…}(…)` — which simply reverts (no code). L2 router `outboundTransfer` similarly calls `0x0`.

Nothing else is touched. The action does NOT:
- upgrade or freeze the L1 or L2 StandardERC20Gateway / custom gateway implementations;
- touch the token contract itself;
- call `finalizeInboundTransfer` or any outbox machinery;
- write token-specific state in the gateway contracts (only in the two *routers*).

## 2. Empirical post-execution state for USDT

Executed tx (verified via `cast logs` on mainnet, topic filter on `GatewaySet(USDT, 0x1)`):

- Tx: `0x81f4da8c5dd87d618e927936c941151689ef674ce2639cd4f0857fa4b75a2861`
- Block: 23,426,867, timestamp 2025-09-23 16:16:47 UTC
- From: `0xA0141D575dbc63a7cF7Af303054279A91D10CC83` (DAO upgrade executor proxy)

Current on-chain state (queried 2026-04-14 via `eth.llamarpc.com` / `arb1.arbitrum.io/rpc`):

| Address | Call | Result |
|---|---|---|
| L1 `L1GatewayRouter` `0x72Ce9c84…7031ef` | `l1TokenToGateway(USDT)` | `0x…01` (DISABLED) |
| L1 `L1GatewayRouter` | `getGateway(USDT)` | `0x0` |
| L2 `L2GatewayRouter` `0x5288c571…4F933` | `l1TokenToGateway(USDT)` | `0x…01` (DISABLED) |
| L2 `L2GatewayRouter` | `getGateway(USDT)` | `0x0` |
| L1 `L1CustomGateway` `0xcEe284F7…7180d` | `balanceOf(USDT, gw)` | **138,945.39 USDT still escrowed** |
| L1 `L1CustomGateway` | `l1ToL2Token(USDT)` | `0xFd086bC7…FCbb9` (unchanged) |
| L2 USDT proxy `0xFd086bC7…FCbb9` | `symbol()` | `"USD₮0"` |
| L2 USDT proxy | `l1Address()` | `0x0` (nulled on upgrade) |
| L2 USDT proxy | `bridgeBurn(x, 1)` | **reverts with `"Only OFT can call"`** |
| L2 USDT proxy | `bridgeMint(x, 1)` | reverts with `"Only OFT can call"` |
| L2 USDT impl (EIP-1967 slot) | | `0x3263cd78…a3f4`, upgraded 2025-01-29 14:54 UTC (tx `0xf9f09cde…`) |

The L2 USDT implementation was replaced by Tether **~8 months before** the DAO ran DisableGatewayAction. In the new implementation, `bridgeBurn` is gated to an OFT adapter, so the legacy L2 `StandardArbERC20Gateway` / `L2CustomGateway.outboundTransfer` path reverts at `outboundEscrowTransfer → IArbToken(l2Token).bridgeBurn(_from, _amount)` (see `L2ArbitrumGateway.sol` line 201). This is what actually severs L2→L1 withdrawability — not the DAO action.

### Post-disable L1 finalizations — do any exist?

Yes. I scanned `WithdrawalFinalized` events on `L1CustomGateway` from block 23,400,000 → 23,750,000 and filtered by `l1Token == USDT` (the token is in the event `data` field, first 32 bytes). Found three relevant hits:

| Block (L1) | Date | Tx | `l2Timestamp` in Outbox proof |
|---|---|---|---|
| 23,422,460 | 2025-09-22 | `0xfdadc051…91b00` | pre-disable |
| 23,578,772 | 2025-10-14 | `0x6202d7f1…75af9` | **2025-01-08 23:32** (decoded from calldata) |
| 23,687,331 | 2025-10-30 | `0x5f210b0b…7afa51` | **2024-05-27 21:06** (decoded from calldata) |

The two **post-disable finalizations succeeded**. Their Outbox proofs reference L2 blocks from *before* the Tether contract upgrade (when `bridgeBurn` still worked). Both `to` = canonical Outbox `0x0B9857ae…4840`; after outbox executeTransaction, the legacy L1 `L1CustomGateway.finalizeInboundTransfer` was called and released the escrowed L1 USDT.

This is the decisive empirical datum. `L1ArbitrumGateway.finalizeInboundTransfer` (base contract at `contracts/tokenbridge/ethereum/gateway/L1ArbitrumGateway.sol`, line 104) has exactly one auth check, `onlyCounterpartGateway`, which verifies the outbox sender is the L2 counterpart gateway. It does NOT consult `L1GatewayRouter.getGateway(token)`. Setting the router mapping to `address(1)` has zero effect on already-in-flight withdrawals.

**So: if legacy L2 USDT supply were still burnable, every single L2 holder could still withdraw to L1 after the DAO action. The action does not neutralize anything on the L1 escrow path.** The only reason it functionally "worked" for USDT is that Tether had pre-emptively bricked `bridgeBurn` in January 2025.

## 3. Pre-action Tether-side mitigation (confirmed)

Timeline (all primary-source verified):

1. **2025-01-29 14:54 UTC** — Tether upgraded the L2 USDT proxy to the USDT0 implementation (`Upgraded(0x3263cd78…a3f4)` event). From this moment, `bridgeBurn`/`bridgeMint` revert with `"Only OFT can call"`, so neither legacy deposits nor legacy withdrawals can proceed. The old L1↔L2 custom gateway pair was silently disconnected from the token.
2. **2025-06-25** — "Constitutional AIP: Disable Legacy Tether Bridge" forum post by Arbitrum Foundation (topic 29503).
3. **2025-09-23 16:16 UTC** — `DisableGatewayAction.perform([USDT], …)` executed on L1.

The AIP thread confirms this sequence explicitly. Key quotes (Discourse JSON, all 20 posts read):

- OP (Arbitrum): *"this proposal seeks to disable the legacy USDT bridge … given the activation of the new USDT0 bridge in January 2025 … once this delay has elapsed, deposits are auto-withdrawn on L1."*
- Arbitrum Foundation (2025-07-23): *"The Tether team, at its discretion, upgraded its token contract to USDT0. This disconnected the token from the native bridge on Arbitrum One, resulting in users who bridged from the L1 not receiving their funds on the L2. Although those funds were recovered, it exposes potential edge cases where, in theory, funds may not be recoverable."* — and: *"Note that using the legacy bridge for USDT deposits currently doesn't work as expected because the legacy bridge automatically withdraws the USDT back to the original address."*
- L2BEAT (Sinkas, 2025-07-09): *"Currently, USDT on Arbitrum has been upgraded to USDT0 … canonically deposited USDT tokens are already minted as USDT0 … this proposal … would essentially be a rubber stamp of a decision that Tether has already made."*
- L2BEAT again: *"There are currently about $140,000 USDT in the gateway, while there's more than $1,000,000,000 in the LayerZero lockbox."* — matches my on-chain read of `138,945.39 USDT` in the legacy escrow.

No post in the thread asserts that the DAO action *alone* would prevent withdrawals; every post treats the legacy bridge as already inert at the token layer. The DAO action is explicitly described as cleanup ("disable … so any transaction submitted … will simply revert"), not as the mechanism that neutralized outstanding L2 balance.

**Crucial analog for DOLA**: Tether, as the token issuer, unilaterally bricked `bridgeBurn` on the L2 token. Multichain's DOLA router is not an equivalently cooperative counterparty — no one can unilaterally drain its 1.9M DOLA or revoke its ability to mint/burn L2-side representations. The USDT story is **not** a precedent that a router-level action suffices; it's a precedent that a token-issuer contract upgrade suffices and the DAO action was ceremonial.

## 4. Sentinel-value consultation in the hot path

Read verbatim from `contracts/tokenbridge/libraries/gateway/GatewayRouter.sol` (governs both L1 and L2 routers):

```solidity
function getGateway(address _token) public view virtual override returns (address gateway) {
    gateway = l1TokenToGateway[_token];
    if (gateway == ZERO_ADDR) gateway = defaultGateway;
    if (gateway == DISABLED || !gateway.isContract()) return ZERO_ADDR;
    return gateway;
}
```

Where is `getGateway` called?

| Contract | Function | Calls `getGateway`? | Effect of sentinel |
|---|---|---|---|
| L1GatewayRouter | `outboundTransfer` / `outboundTransferCustomRefund` | **yes** | resolves to `0x0`, call reverts — blocks new L1→L2 *deposits* only |
| L1GatewayRouter | `calculateL2TokenAddress` | yes | returns `0x0` |
| L1GatewayRouter | `finalizeInboundTransfer` | N/A — router's `finalizeInboundTransfer` is `revert("ONLY_OUTBOUND_ROUTER")` |
| L2GatewayRouter | `outboundTransfer` | yes | resolves to `0x0`, call reverts — blocks router-mediated new L2→L1 *withdrawals* |
| L2GatewayRouter | `calculateL2TokenAddress` | yes | returns `0x0` |
| **L1ArbitrumGateway** (custom or standard) | **`finalizeInboundTransfer`** | **NO** | **no consultation of the router at all** |
| **L2ArbitrumGateway** | **`outboundTransfer`** (direct call, bypassing router) | **NO** | **no consultation of the router at all** |

L1 `L1ArbitrumGateway.finalizeInboundTransfer` only checks `onlyCounterpartGateway` (the outbox sender is the paired L2 gateway) and then runs `inboundEscrowTransfer → IERC20(_l1Token).safeTransfer(_dest, _amount)`.

L2 `L2ArbitrumGateway.outboundTransfer` accepts direct callers. If `msg.sender != router`, it just treats msg.sender as `_from` and proceeds to `calculateL2TokenAddress(_l1Token)` (which calls the gateway's own `l1ToL2Token` mapping, *not* the router) then `outboundEscrowTransfer → bridgeBurn`.

**Therefore: the DISABLED sentinel is consulted only on the router hot path. A holder of legacy L2 USDT today could, in principle, skip the L2 router entirely and call `L2CustomGateway.outboundTransfer(USDT_L1, to, amount, "")` directly. The only reason that fails is that `bridgeBurn` reverts inside the L2 USDT token itself. If the L2 token cooperated, the Outbox message would be posted, wait 7 days, and finalize on L1 because `L1CustomGateway.finalizeInboundTransfer` does not check the router.**

## 5. Feasibility sketch of `DisableGatewayActionV2`

The gateway proxies on L1 and L2 are standard OpenZeppelin `TransparentUpgradeableProxy` controlled by `ProxyAdmin` contracts owned by the L1 UpgradeExecutor (DAO) and L2 UpgradeExecutor respectively. The governance repo already has a generic action for this:

```solidity
// src/gov-action-contracts/gov-upgrade-contracts/upgrade-proxy/ProxyUpgradeAction.sol
contract ProxyUpgradeAction {
    function perform(address admin, address payable target, address newLogic) public payable {
        ProxyAdmin(admin).upgrade(TransparentUpgradeableProxy(target), newLogic);
    }
}
```

…and a `ProxyUpgradeAndCallAction.sol` variant for upgradeAndCall. These are routinely used in AIPs (see `src/gov-action-contracts/AIPs/` — ArbOS11, ArbOS31, AIP4844, NomineeGovernorV2, etc.; many are "ship new logic contract + flip the proxy").

Shape of a plausible `DisableGatewayActionV2` for a single `_l1Token`:

1. Deploy new `L1CustomGateway_Frozen` logic: identical to current `L1CustomGateway` except `finalizeInboundTransfer` and `outboundTransferCustomRefund` both `require(_token != FROZEN_TOKEN)` (immutable, set in constructor).
2. Deploy new `L2CustomGateway_Frozen` logic with same predicate on `outboundTransfer`.
3. Action contract: call `ProxyUpgradeAction.perform(L1ProxyAdmin, L1CustomGatewayProxy, newL1Logic)`; then retryable to L2 calling `ProxyUpgradeAction` on the L2 side.
4. Optionally also call DisableGatewayAction in the same payload for symmetry.

**Precedent and political feasibility**:
- Technical: straightforward; the upgrade paths are exercised in production regularly. Both gateways are proxies under DAO-controlled `ProxyAdmin`s. No new auth surface needed.
- Scope concern: `L1CustomGateway` holds escrow for *many* tokens (ARB, GMX, LDO, etc.), so you cannot blanket-revert; the new logic MUST whitelist frozen tokens precisely. Easy with a constructor-set immutable or a DAO-controlled set.
- Political: Arbitrum DAO has been willing to ship narrow "fix a broken integration" actions before (see AIP-1.1, AIP-4, various AtlasFees actions). The USDT case set no precedent either way because it was framed as "Tether already broke it, we're just tidying up." A DOLA action would need to argue Multichain is defunct and the L2-side claim is unrecoverable by normal means — a less clean story.
- Constitutional: a forced-seizure of an in-flight withdrawal right is politically harder than disabling a router. Expect more vocal opposition from delegates focused on "canonical bridge trust assumptions" (see L2BEAT's recurring framing in topic 29503 and adjacent threads).
- Risk surface: any new logic that reverts on `finalizeInboundTransfer` for some tokens freezes those balances permanently unless a later upgrade unfreezes them — which is actually the *desired* behavior here, but amplifies the "DAO can seize your bridge exit" narrative.

## 6. Verdict

**A light-touch router-level action is operationally sufficient for DOLA *only* if someone can first do what Tether did: upgrade the L2 token contract so `bridgeBurn` reverts for the Multichain-held supply.**

For USDT that was trivially available because Tether owned/controlled the L2 token. For DOLA, the L2 token (assuming it's the standard Arb ERC20 representation at the custom gateway) has `bridgeBurn` callable by the L2 custom gateway, and the holder of record is the Multichain router contract. There is no cooperative token-issuer upgrade that bricks `bridgeBurn` without also affecting honest users — and crucially, bricking `bridgeBurn` does not move the L2 balance; it only freezes it.

Concrete implications:

1. **DisableGatewayAction alone is insufficient for DOLA.** It severs the L1GatewayRouter and L2GatewayRouter `outboundTransfer` path, but a direct call to `L2CustomGateway.outboundTransfer(DOLA_L1, …)` from the Multichain router (or anyone with L2 DOLA) bypasses the router entirely, and the resulting L1 finalization does not consult the router. 1.9M DOLA of L1 escrow remains at risk.

2. **Gateway-implementation surgery *is* required.** Specifically, you need either (a) a new L1CustomGateway logic that refuses `finalizeInboundTransfer` for DOLA, which permanently freezes the 1.9M of L1 DOLA escrow in the gateway (useful only if you then separately rescue it via a different action), or (b) a combined upgrade that repoints escrow: new logic that on `finalizeInboundTransfer(DOLA, …)` transfers to an Inverse recovery address instead of `_to`. Option (b) is the surgical DAO-seizure path that actually recovers funds.

3. **USDT is not a precedent for (a) or (b).** It is a precedent for "token issuer neutralized withdrawability; DAO rubber-stamped with router cleanup."

4. **Post-execution empirical evidence confirms the theoretical reading**: two USDT withdrawals finalized on L1 *after* DisableGatewayAction ran, both for pre-Tether-upgrade outbox entries. The DAO action did not stop them; only the L2 bridgeBurn lockout stops new ones.

### Recommendation

Any Inverse proposal to Arbitrum DAO must ask for at minimum a gateway-implementation upgrade (ProxyUpgradeAction on the L1 and L2 custom gateways). A pure router-disable is cosmetic for this purpose. If the goal is recovery (not just freeze), the action must additionally redirect `finalizeInboundTransfer` for DOLA to an Inverse-controlled address, which is a harder political ask (DAO-seizure of a non-malicious escrow on behalf of a third-party protocol) — but technically routine, and directly analogous to ArbOS upgrade AIPs.

---

### Artifacts / sources

- `ArbitrumFoundation/governance` @ main: `src/gov-action-contracts/token-bridge/DisableGatewayAction.sol`, `TokenBridgeActionLib.sol`, `gov-upgrade-contracts/upgrade-proxy/ProxyUpgradeAction.sol`.
- `OffchainLabs/token-bridge-contracts` @ main: `contracts/tokenbridge/ethereum/gateway/L1GatewayRouter.sol`, `L1ArbitrumGateway.sol`; `contracts/tokenbridge/arbitrum/gateway/L2GatewayRouter.sol`, `L2ArbitrumGateway.sol`; `contracts/tokenbridge/libraries/gateway/GatewayRouter.sol`.
- Forum: `https://forum.arbitrum.foundation/t/constitutional-aip-disable-legacy-tether-bridge/29503.json` (all 20 posts read).
- Mainnet RPC: `https://eth.llamarpc.com`, `https://ethereum-rpc.publicnode.com`.
- Arb1 RPC: `https://arb1.arbitrum.io/rpc`.
- Key addresses verified live:
  - L1 `L1GatewayRouter`: `0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef`
  - L1 `L1CustomGateway`: `0xcEe284F754E854890e311e3280b767F80797180d`
  - L2 `L2GatewayRouter`: `0x5288c571Fd7aD117beA99bF60FE0846C4E84F933`
  - L2 `L2CustomGateway`: `0x096760F208390250649E3e8763348E783AEF5562`
  - L1 USDT: `0xdAC17F958D2ee523a2206206994597C13D831ec7`
  - L2 USDT/USDT0 proxy: `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9`
  - L2 USDT0 implementation (current): `0x3263cd783823d04a6b9819517e0e6840d37ca3f4`
  - DisableGatewayAction contract (ETH L1): `0x8d3425f7039645223517F6F6e60Ef04C28f4188F`
  - DisableGatewayAction execution tx: `0x81f4da8c5dd87d618e927936c941151689ef674ce2639cd4f0857fa4b75a2861` (block 23,426,867, 2025-09-23 16:16 UTC)
  - L2 USDT→USDT0 upgrade tx: `0xf9f09cde4d3daf6b9cb61351ed9cc0a5cf987b5ce6ed4ee1d59e3e01eaf08cf1` (Arb1 block 300,530,396, 2025-01-29 14:54 UTC)
  - Post-disable successful USDT finalizations (from pre-upgrade L2 outbox entries): `0x6202d7f16601bdbd94a8bb18315d0845e3139d2c2b7ebdc7b95d890f09375af9` (2025-10-14, L2 ts 2025-01-08); `0x5f210b0b9bccb01a96616c640e3afd24be13d53efc10d819a380b179b77afa51` (2025-10-30, L2 ts 2024-05-27).
