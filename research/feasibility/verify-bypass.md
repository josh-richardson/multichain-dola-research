# Independent Verification: does `setGateway` / `DisableGatewayAction` alone neutralize legacy L2 ERC20 escrow redemption?

Sources read directly (no prior-agent notes consulted):

- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/ethereum/gateway/L1ArbitrumGateway.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/ethereum/gateway/L1ERC20Gateway.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/ethereum/gateway/L1GatewayRouter.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/arbitrum/gateway/L2ArbitrumGateway.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/arbitrum/gateway/L2ERC20Gateway.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/arbitrum/gateway/L2GatewayRouter.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/libraries/gateway/TokenGateway.sol`
- `/tmp/verify-bypass/token-bridge-contracts/contracts/tokenbridge/libraries/gateway/GatewayRouter.sol`
- `/tmp/verify-bypass/gov/governance/src/gov-action-contracts/token-bridge/DisableGatewayAction.sol`

---

## Q1 — Finalize path on L1 (withdraw completion)

**Entrypoint on L1:** `L1ERC20Gateway.finalizeInboundTransfer(address,address,address,uint256,bytes)` which simply calls `super.finalizeInboundTransfer(...)` → `L1ArbitrumGateway.finalizeInboundTransfer(...)`.

From `L1ERC20Gateway.sol` lines 78–87:

```solidity
function finalizeInboundTransfer(
    address _token,
    address _from,
    address _to,
    uint256 _amount,
    bytes calldata _data
) public payable override nonReentrant {
    // the superclass checks onlyCounterpartGateway
    super.finalizeInboundTransfer(_token, _from, _to, _amount, _data);
}
```

From `L1ArbitrumGateway.sol` lines 104–126:

```solidity
function finalizeInboundTransfer(
    address _token,
    address _from,
    address _to,
    uint256 _amount,
    bytes calldata _data
) public payable virtual override onlyCounterpartGateway {
    ...
    inboundEscrowTransfer(_token, _to, _amount);
    emit WithdrawalFinalized(_token, _from, _to, exitNum, _amount);
}
```

`inboundEscrowTransfer` (L1ArbitrumGateway.sol:139–146) is a plain `IERC20.safeTransfer` from the gateway's own escrow to `_to`. No router consult. No token allowlist.

**Modifier (only guard)** — `L1ArbitrumGateway.sol` lines 63–74:

```solidity
modifier onlyCounterpartGateway() override {
    address _inbox = inbox;
    address bridge = address(super.getBridge(_inbox));
    require(msg.sender == bridge, "NOT_FROM_BRIDGE");
    address l2ToL1Sender = super.getL2ToL1Sender(_inbox);
    require(l2ToL1Sender == counterpartGateway, "ONLY_COUNTERPART_GATEWAY");
    _;
}
```

Counterpart source: `counterpartGateway` storage slot set once in `TokenGateway._initialize` (`TokenGateway.sol:36–44`, requires `counterpartGateway == address(0)` to set, i.e. **immutable post-init**). The L1 gateway has no setter for it.

**No router lookup. No `L1GatewayRouter.getGateway(token)` call. No per-token allowlist. No check that the router still maps `_token → this gateway`.** The single gate is the `onlyCounterpartGateway` modifier which only asks: "was this a message from my hardcoded L2 pair, delivered by my hardcoded inbox's bridge?"

---

## Q2 — Outbound path on L2 (withdraw initiation)

`L2ERC20Gateway.sol` does **not** override `outboundTransfer`. The inherited implementation is in `L2ArbitrumGateway.sol` lines 133–172:

```solidity
function outboundTransfer(
    address _l1Token,
    address _to,
    uint256 _amount,
    uint256, /* _maxGas */
    uint256, /* _gasPriceBid */
    bytes calldata _data
) public payable virtual override returns (bytes memory res) {
    require(msg.value == 0, "NO_VALUE");
    address _from;
    bytes memory _extraData;
    {
        if (isRouter(msg.sender)) {
            (_from, _extraData) = GatewayMessageHandler.parseFromRouterToGateway(_data);
        } else {
            _from = msg.sender;
            _extraData = _data;
        }
    }
    require(_extraData.length == 0, "EXTRA_DATA_DISABLED");
    uint256 id;
    {
        address l2Token = calculateL2TokenAddress(_l1Token);
        require(l2Token.isContract(), "TOKEN_NOT_DEPLOYED");
        require(_isValidTokenAddress(_l1Token, l2Token), "NOT_EXPECTED_L1_TOKEN");
        _amount = outboundEscrowTransfer(l2Token, _from, _amount);
        id = triggerWithdrawal(_l1Token, _from, _to, _amount, _extraData);
    }
    return abi.encode(id);
}
```

- **`public payable virtual`, no router-only guard.** The `isRouter(msg.sender)` is a branch to decode `_from`, NOT a gate. Explicit `else { _from = msg.sender; ... }` path.
- **EOA vs contract irrelevant** — no code check on `msg.sender`; `_from = msg.sender` is used directly.
- **No `L2GatewayRouter.getGateway(token)` check.** `calculateL2TokenAddress(_l1Token)` (L2ERC20Gateway.sol:47–60) is a *pure* create2-preimage computation against the gateway's own `beaconProxyFactory`; it does not consult `L2GatewayRouter.l1TokenToGateway`.
- `_isValidTokenAddress` (L2ArbitrumGateway.sol:287–309) staticcalls `IArbToken.l1Address()` on the L2 token and compares to the `_l1Token` arg — a sanity check on the L2 token, not a router lookup.
- `outboundEscrowTransfer` (lines 193–205) calls `IArbToken(_l2Token).bridgeBurn(_from, _amount)` — burns attacker's balance.
- `triggerWithdrawal` → `createOutboundTx` → `sendTxToL1(0, _from, counterpartGateway, _outboundCalldata)` (lines 88–96). The destination is the old gateway's hardcoded `counterpartGateway` — the OLD L1 gateway.

No router-origin check in the outbound path.

---

## Q3 — What does `setGateway` / `setGateways` actually change?

From `L1GatewayRouter.sol` `_setGateways` lines 229–276:

```solidity
for (uint256 i = 0; i < _token.length; i++) {
    l1TokenToGateway[_token[i]] = _gateway[i];
    emit GatewaySet(_token[i], _gateway[i]);
    ...
}
bytes memory data = abi.encodeWithSelector(
    L2GatewayRouter.setGateway.selector,
    _token,
    _gateway
);
return sendTxToL2(inbox, counterpartGateway, _creditBackAddress, ...);
```

And the reader in `GatewayRouter.sol` lines 108–122:

```solidity
function getGateway(address _token) public view virtual override returns (address gateway) {
    gateway = l1TokenToGateway[_token];
    if (gateway == ZERO_ADDR) { gateway = defaultGateway; }
    if (gateway == DISABLED || !gateway.isContract()) { return ZERO_ADDR; }
    return gateway;
}
```

- Storage touched: `l1TokenToGateway` (L1 router) and, via the retryable, `L2GatewayRouter.l1TokenToGateway` (`L2GatewayRouter.sol:51`).
- **No L1 gateway reads this mapping in `finalizeInboundTransfer`** (Q1).
- **No L2 gateway reads this mapping in `outboundTransfer`** (Q2).
- **No auto-cleanup of in-flight state.** Unburned L2 supply on the old gateway, and L1 escrow still sitting in the old L1 gateway, are untouched. There is no callback to either gateway. The router's `getGateway` is consulted only by *new* deposit/withdrawal flows routed through the router itself.

---

## Q4 — Thought experiment: malicious party holds 1.9M legacy L2 DOLA after `setGateways([DOLA_L1], [newCustomGateway], ...)`

**Q4a: Does the L2 gateway succeed in burning & dispatching?** **YES.**

- `L2ArbitrumGateway.outboundTransfer` is `public payable virtual` with no caller gate (L2ArbitrumGateway.sol:133–172).
- `calculateL2TokenAddress(DOLA_L1)` returns the create2 address from the *old* beacon factory — which is the already-deployed legacy L2 DOLA. `l2Token.isContract()` is true.
- `_isValidTokenAddress` staticcalls the legacy L2 DOLA's `l1Address()`; if it returns DOLA_L1, the check passes.
- `IArbToken(_l2Token).bridgeBurn(_from, _amount)` burns attacker's 1.9M.
- `sendTxToL1(0, _from, counterpartGateway, ...)` posts an L2→L1 message whose destination is the OLD L1 gateway (the hardcoded `counterpartGateway`).
- The router mapping change on L1/L2 is not consulted anywhere on this path.

**Q4b: After 7-day challenge + Outbox.executeTransaction, does OLD L1 StandardERC20Gateway release 1.9M L1 DOLA?** **YES.**

- The Outbox delivers the call to `L1ERC20Gateway.finalizeInboundTransfer` (via the bridge).
- `onlyCounterpartGateway` checks: `msg.sender == bridge(inbox)` → true (Outbox routes through the bridge); `getL2ToL1Sender(inbox) == counterpartGateway` → true (the message was posted by the OLD L2 gateway, which is exactly `counterpartGateway` of the OLD L1 gateway) (L1ArbitrumGateway.sol:63–74).
- No router lookup, no per-token allowlist.
- `inboundEscrowTransfer` does `IERC20(DOLA_L1).safeTransfer(_to=attacker, 1_900_000e18)` (L1ArbitrumGateway.sol:139–146).

Both sub-questions: yes.

---

## Q5 — `DisableGatewayAction` effect on the finalize path

`DisableGatewayAction.sol` (governance repo) lines 15–30:

```solidity
function perform(address[] memory _tokens, ...) external payable {
    TokenBridgeActionLib.ensureAllContracts(_tokens);
    address[] memory _gateways = new address[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
        _gateways[i] = address(1); // DISABLED GATEWAY
    }
    addressRegistry.gatewayRouter().setGateways{...}(_tokens, _gateways, ...);
}
```

It calls exactly the same `setGateways` with sentinel `address(1) == DISABLED`. The sentinel is consulted only in `GatewayRouter.getGateway` (GatewayRouter.sol:116) — a router function that returns `ZERO_ADDR` so that *new* router-mediated deposits/withdrawals are blocked. **Neither `L1ArbitrumGateway.finalizeInboundTransfer` nor `L2ArbitrumGateway.outboundTransfer` ever calls `getGateway`, so the sentinel is invisible to both hot paths.**

No `DISABLED` check anywhere in the finalize path. Identical outcome to Q4.

---

## Verdict — INDEPENDENTLY CONFIRMED

The prior agent's three claims are each verified verbatim against the canonical Offchain Labs source:

1. L1 `finalizeInboundTransfer` is guarded **only** by `onlyCounterpartGateway` (inbox + bridge + aliased L2 sender == immutable `counterpartGateway`). No router consult, no per-token allowlist.
2. L2 `outboundTransfer` is `public payable virtual` with no router-only guard. `msg.sender` flows directly into `_from`; EOA or contract doesn't matter. No `L2GatewayRouter.getGateway` consult.
3. `setGateway` / `setGateways` / `DisableGatewayAction` only mutate `l1TokenToGateway` on the routers; that mapping is never read on the hot paths of the old gateways. No cleanup of in-flight escrow or unburned L2 supply.

Post-`setGateway` (or post-`DisableGatewayAction`), any holder of legacy L2 standard-bridge DOLA can still directly invoke the old L2 gateway's `outboundTransfer`, burn their L2 balance, and after the 7d challenge window, redeem L1 escrow from the old L1 gateway. **The prior claim stands.**

---

## What would actually suffice (minimal)

The router action cannot shut down a fully-deployed, separately-proxied legacy gateway. To neutralize the bypass you must stop one of the two in-flight primitives:

- **Preferred: upgrade the legacy L1 StandardERC20Gateway proxy** (via the L1 ProxyAdmin owned by the DAO's L1 UpgradeExecutor) to an implementation whose `finalizeInboundTransfer` either reverts unconditionally for DOLA_L1 (token-blocklist) **or** consults `L1GatewayRouter.getGateway(token)` and rejects if the router no longer points at `address(this)`. Escrow itself can also be swept to a recovery address in the same upgrade. This is a pure L1 action — no L2 retryable required.
- **Or, complementary: upgrade the legacy L2 StandardArbERC20Gateway proxy** (via the L2 ProxyAdmin / UpgradeExecutor) so its `outboundTransfer` reverts — prevents burn+message emission. Works but only addresses new withdrawals; any withdrawal already posted and past the 7d window would still finalize unless the L1 side is also fixed.
- **Or, on the token itself:** if the L2 DOLA proxy is still owned by Inverse/Multichain-relevant admin and they cooperate, pausing `bridgeBurn` would also break the outbound path. Not a unilateral Arbitrum DAO action.

`setGateway` / `DisableGatewayAction` alone: insufficient. The minimal unilateral Arbitrum-DAO fix is an **implementation upgrade of the legacy L1 StandardERC20Gateway proxy** — touch the finalize path itself, not the router.
