# SUPERSEDED: UpgradeExecutor and per-proxy beacon spike

> Historical technical investigation. Its per-proxy negative proof is summarized in `../TECHNICAL_OPTIONS.md`.

- **Date:** 2026-04-14
- **Author:** joshua@richardson.tech
- **L2 UpgradeExecutor:** `0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827` (Arbitrum One)
- **Shared beacon (StandardArbERC20):** `0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333`
- **Beacon implementation:** `0x3f770Ac673856F105b586bb393d122721265aD46`
- **L2 DOLA BeaconProxy:** `0x6a7661795c374c0bfc635934efaddff3a7ee23b6`
- **L2ERC20Gateway proxy:** `0x09e9222E96E7B4AE2a407B98d48e330053351EEe`
- **L2ERC20Gateway ProxyAdmin:** `0xd570ace65c43af47101fc6250fd6fc63d1c22a86` (owner: UpgradeExecutor)

## TL;DR (verdict)

**Per-proxy beacon rewrite is NOT possible.** The Arbitrum DOLA L2 token lives behind a `ClonableBeaconProxy` which is a minimal OpenZeppelin `BeaconProxy` (OZ ^3.4) with no admin, no setter, no fallback-reachable `_setBeacon`. UpgradeExecutor can call arbitrary targets, but the target itself exposes no function that writes the EIP-1967 beacon slot. On-chain bytecode confirms: the runtime has only the Proxy fallback plus the beacon-slot SLOAD helper; nothing else.

---

## 1. UpgradeExecutor capabilities

Source: `https://github.com/OffchainLabs/upgrade-executor` at `src/UpgradeExecutor.sol` (cloned to `/tmp/spike/upgrade-executor/src/UpgradeExecutor.sol`).

Two entrypoints, both `onlyRole(EXECUTOR_ROLE) nonReentrant`:

```solidity
// lines 57-69
function execute(address upgrade, bytes memory upgradeCallData)
    public
    payable
    onlyRole(EXECUTOR_ROLE)
    nonReentrant
{
    address(upgrade).functionDelegateCall(
        upgradeCallData, "UpgradeExecutor: inner delegate call failed without reason"
    );
    emit UpgradeExecuted(upgrade, msg.value, upgradeCallData);
}

// lines 73-85
function executeCall(address target, bytes memory targetCallData)
    public
    payable
    onlyRole(EXECUTOR_ROLE)
    nonReentrant
{
    address(target).functionCallWithValue(
        targetCallData, msg.value, "UpgradeExecutor: inner call failed without reason"
    );
    emit TargetCallExecuted(target, msg.value, targetCallData);
}
```

Interpretation:

- `execute(...)` — `DELEGATECALL` into a gov-action contract. The action contract executes in UpgradeExecutor's storage/context, so any downstream call it makes has `msg.sender == UpgradeExecutor`.
- `executeCall(...)` — ordinary `CALL` to any `target` with arbitrary calldata. Again `msg.sender == UpgradeExecutor`.

**Therefore UpgradeExecutor CAN make any call as `0xCF57...A827` into any contract.** The question reduces to whether the receiving contract accepts a beacon-rewrite from this caller. On-chain, UpgradeExecutor holds:

- `owner()` of the shared beacon `0xe72ba9...` (confirmed via `cast call`: returns `0xCF57...A827`).
- `owner()` of the L2ERC20Gateway `ProxyAdmin` `0xd570...2a86` (confirmed: returns `0xCF57...A827`).

So UpgradeExecutor can freely `upgradeTo` the shared beacon and `upgrade`/`upgradeAndCall` the L2ERC20Gateway. Neither of these is a *per-token* beacon swap.

---

## 2. ClonableBeaconProxy / L2 DOLA proxy structure

### 2a. Source: `ClonableBeaconProxy`

File: `/tmp/spike/token-bridge-contracts/contracts/tokenbridge/libraries/ClonableBeaconProxy.sol` (OffchainLabs `token-bridge-contracts`):

```solidity
// lines 13-15
contract ClonableBeaconProxy is BeaconProxy {
    constructor() BeaconProxy(ProxySetter(msg.sender).beacon(), "") {}
}
```

That is the entire contract. No admin storage, no setter, no initialiser, no upgrade hook, no selfdestruct. It only extends OZ `BeaconProxy`.

### 2b. Source: OZ `BeaconProxy` (v3.4.2)

File: `/tmp/spike/oz342/package/proxy/BeaconProxy.sol`:

```solidity
// lines 17-22
contract BeaconProxy is Proxy {
    bytes32 private constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

// lines 35-38
    constructor(address beacon, bytes memory data) public payable {
        assert(_BEACON_SLOT == bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
        _setBeacon(beacon, data);
    }

// lines 68-87
    function _setBeacon(address beacon, bytes memory data) internal virtual {
        ...
        assembly { sstore(slot, beacon) }
        ...
    }
```

`_setBeacon` is `internal`. It is called *only* from the constructor. `BeaconProxy` defines no external or public function. The contract inherits from `Proxy`, which has only the fallback/receive delegatecall machinery. `ClonableBeaconProxy` adds nothing. **There is no runtime path that writes `_BEACON_SLOT`.**

### 2c. On-chain bytecode evidence for `0x6a7661...23b6`

`cast code 0x6a7661795c374c0bfc635934efaddff3a7ee23b6 --rpc-url https://arb1.arbitrum.io/rpc`:

```
60806040523661001357610011610017565b005b6100115b61001f61002f56
5b61002f61002a61013c565b6101af565b565b3b151590565b6060610042
84610031565b61007d5760405162461bcd60e51b815260040180806020018
...
7fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
549056fe416464726573733a2064656c65676174652063616c6c20746f206e
6f6e2d636f6e7472616374
```

This is identical to the OZ 3.4 `BeaconProxy` runtime. Observations:

- Dispatch: CALLDATASIZE jump to fallback — **no function selector table**.
- The only push-32 constant of interest is the EIP-1967 beacon slot `a3f0...3d50`, referenced by `SLOAD` (opcode `54`) within `_beacon()`.
- Error string is `"Address: delegate call to non-contract"` (OZ v3.4 `Address.functionDelegateCall`).
- No `SSTORE` to the beacon slot anywhere in runtime.

`cast storage 0x6a7661...23b6 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50` returns:
```
0x000000000000000000000000e72ba9418b5f2ce0a6a40501fe77c6839aa37333
```
— confirming the beacon pointer.

The EIP-1967 admin slot (`0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`) and implementation slot (`0x360894...82bbc`) were not probed because `ClonableBeaconProxy` does not use them; there is no admin. (Storage reads would return zero.)

Arbiscan verification: the contract shows as an unverified minimal BeaconProxy deployed by the Arbitrum `BeaconProxyFactory` at `0x09e9222E...` via `createProxy(salt)` (see `BeaconProxyFactory.createProxy` in `ClonableBeaconProxy.sol` lines 37-42). There is nothing to verify beyond what is shown here.

### 2d. Behaviour delegated through to the implementation (`StandardArbERC20`)

File: `/tmp/spike/token-bridge-contracts/contracts/tokenbridge/arbitrum/StandardArbERC20.sol`. Writes only `availableGetters` (line 74) and inherited balances/allowances/`l2Gateway`/`l1Address`. There is no function whose body would call `sstore(_BEACON_SLOT, ...)`. Even if UpgradeExecutor could make the proxy delegatecall into a custom implementation, the proxy's fallback routes to `IBeacon(beacon).implementation()` on every call; there is no way to reach a custom "set-my-beacon" codepath because the proxy does not have one, and the implementation chosen is whatever the *current* beacon says.

---

## 3. Verdict on per-proxy beacon rewrite

**No.** The beacon pointer for `0x6a7661...23b6` cannot be changed by UpgradeExecutor (or by anyone) without L2 consensus-level state intervention. Justification:

1. `ClonableBeaconProxy` exposes no external function at all (no selector table); everything falls through to delegatecall.
2. OZ `BeaconProxy._setBeacon` is `internal` and reachable only in the constructor, which ran once at deploy.
3. The implementation (`StandardArbERC20`) does not contain any selfdestruct, any write to `_BEACON_SLOT`, or any admin/upgrade hook — so even delegating into the implementation cannot modify the beacon slot.
4. There is no `selfdestruct` in the proxy (which in any case would not help post-Cancun).
5. Arbitrum Nitro L2 has no analogue of an EIP-xxx state override; state can only be mutated by executed transactions, and no transaction can reach a beacon-write.

This result is independent of what UpgradeExecutor can *call*: there is simply no function at the target address that accepts a beacon write.

---

## 4. Ranked residual options

### Option A — Shared-beacon upgrade with per-token branching (RECOMMENDED for the "keep DOLA off" goal only if DOLA-specific logic is acceptable to the DAO)

Upgrade the shared `StandardArbERC20` beacon (`0xe72ba9...`) via `UpgradeableBeacon.upgradeTo(newImpl)` — this is a single `executeCall` from UpgradeExecutor since it is `owner()` of the beacon. New impl can read its own address (or `l1Address`) and branch. This is **globally visible** — every StandardArbERC20 on Arbitrum uses this beacon. Any logic change applies to all of them. Inspection of the current impl (`0x3f770Ac673856F105b586bb393d122721265aD46`) is possible via Arbiscan; the on-chain contract corresponds to the `StandardArbERC20` source quoted in §2d — it has no per-token hook, but a new impl can introduce one (e.g. `if (l1Address == DOLA_L1) revert` on `bridgeBurn`/`bridgeMint`).

Trade-off: touches *every* standard L2 ERC20 that ever withdraws. Politically offensive.

### Option B — L2ERC20Gateway filter (RECOMMENDED overall)

The L2ERC20Gateway at `0x09e9222E...EEe` is a `TransparentUpgradeableProxy`:

- EIP-1967 admin slot → `0xd570ace65c43af47101fc6250fd6fc63d1c22a86` (a `ProxyAdmin`)
- `ProxyAdmin.owner()` → `0xCF57...A827` (UpgradeExecutor)

So UpgradeExecutor can `ProxyAdmin.upgrade(proxy, newImpl)` / `upgradeAndCall(...)` to atomically replace the gateway implementation. A new impl can add a **one-line guard scoped to DOLA**:

```text
// inside outboundTransfer and inboundEscrowTransfer code paths
if (_l1Token == DOLA_L1 /* or _l2Token == DOLA_L2 */) revert("DOLA_FROZEN");
```

Reference: `L2ArbitrumGateway.outboundTransfer` (lines 133-172) and `L2ArbitrumGateway.finalizeInboundTransfer` (lines 227-269), file `/tmp/spike/token-bridge-contracts/contracts/tokenbridge/arbitrum/gateway/L2ArbitrumGateway.sol`.

Advantages vs Option A:

- Scope-limited by exact token address; other tokens untouched.
- Reversible by another gateway upgrade.
- Sits in infra layer that already has upgrade process; no implementation drift on the StandardArbERC20 beacon.

Disadvantages:

- The gateway is shared bridge infra; any bug risks all standard withdrawals. Mitigated by adding only an if-revert branch.
- Users can still bypass via custom paths? No — `StandardArbERC20.bridgeBurn` has `onlyGateway`, so DOLA burns/mints route exclusively through this gateway.

### Option C — Do nothing at proxy/beacon level, address at L1 / custom gateway

If the goal is only to stop cross-chain *egress* of DOLA to L1, a symmetric filter in `L1ERC20Gateway` is also possible (UpgradeExecutor on L1 has the analogous powers). This is complementary to Option B.

### Option D — Bytecode-at-address replacement

Not feasible. Arbitrum L2 has no host precompile that writes arbitrary code to arbitrary addresses; `UpgradeExecutor` can only send transactions. No CREATE2 collision path because the code at the proxy address is already deployed (EVM forbids re-creating into a non-empty account).

### Option E — selfdestruct the proxy, redeploy fresh

The proxy has no selfdestruct path (nothing in `ClonableBeaconProxy`, `BeaconProxy`, `Proxy`, or the implementation calls `SELFDESTRUCT`). Moreover, post-Cancun SELFDESTRUCT does not clear code. Infeasible.

---

## 5. Recommended path

**Option B (scoped L2ERC20Gateway upgrade).** Concretely:

1. Author a gov-action contract that calls `ProxyAdmin.upgradeAndCall(0x09e9...EEe, newGatewayImpl, "")` where `newGatewayImpl` is a copy of the current `L2ERC20Gateway` impl plus a single early `require(_l1Token != DOLA_L1)` in `outboundTransfer` and `finalizeInboundTransfer`.
2. Submit via the standard Arbitrum governance flow → L2 Timelock → L2 `UpgradeExecutor.execute(actionContract, data)`.
3. As a companion (optional), submit the mirror action on L1 to freeze inbound/outbound on `L1ERC20Gateway`.

**Do not attempt** a per-proxy beacon rewrite: it is physically impossible with the current proxy code.

**Avoid Option A** unless the DAO specifically wants DOLA-aware logic baked into the shared StandardArbERC20 implementation — that couples an unrelated bridge-wide contract to a single token recovery.

---

## Appendix — Commands and data collected

```
# Bytecode (runtime) of DOLA proxy — matches OZ 3.4 BeaconProxy
cast code 0x6a7661795c374c0bfc635934efaddff3a7ee23b6 --rpc-url https://arb1.arbitrum.io/rpc

# EIP-1967 beacon slot — confirms shared beacon
cast storage 0x6a7661795c374c0bfc635934efaddff3a7ee23b6 \
  0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
# → 0x...e72ba9418b5f2ce0a6a40501fe77c6839aa37333

# Beacon owner — UpgradeExecutor
cast call 0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333 "owner()(address)" \
  --rpc-url https://arb1.arbitrum.io/rpc
# → 0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827

# Beacon implementation
cast call 0xe72ba9418b5f2ce0a6a40501fe77c6839aa37333 "implementation()(address)" \
  --rpc-url https://arb1.arbitrum.io/rpc
# → 0x3f770Ac673856F105b586bb393d122721265aD46

# L2ERC20Gateway proxy admin (EIP-1967) and its owner
cast storage 0x09e9222E96E7B4AE2a407B98d48e330053351EEe \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
# → 0x...d570ace65c43af47101fc6250fd6fc63d1c22a86
cast call 0xd570ace65c43af47101fc6250fd6fc63d1c22a86 "owner()(address)" \
  --rpc-url https://arb1.arbitrum.io/rpc
# → 0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827
```

Repositories consulted (cloned under `/tmp/spike/`):

- `https://github.com/OffchainLabs/upgrade-executor` → `upgrade-executor/src/UpgradeExecutor.sol`
- `https://github.com/OffchainLabs/token-bridge-contracts` → `contracts/tokenbridge/libraries/ClonableBeaconProxy.sol`, `contracts/tokenbridge/arbitrum/StandardArbERC20.sol`, `contracts/tokenbridge/arbitrum/gateway/L2ArbitrumGateway.sol`
- `https://github.com/OpenZeppelin/openzeppelin-contracts` (npm `@openzeppelin/contracts@3.4.2`) → `proxy/BeaconProxy.sol`, `proxy/UpgradeableBeacon.sol`
- `https://github.com/ArbitrumFoundation/governance` — consulted for callers; `UpgradeExecutor.sol` itself lives in the `upgrade-executor` repo above, not in `governance/src/`.
