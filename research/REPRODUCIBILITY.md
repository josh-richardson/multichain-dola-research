# Reproducing the onchain findings

The commands below use Foundry's `cast`. Public RPC endpoints are examples and can be replaced.

```sh
ARB_RPC=https://arbitrum-one-rpc.publicnode.com
ETH_RPC=https://ethereum-rpc.publicnode.com
BSC_RPC=https://bsc-rpc.publicnode.com

ARB_DOLA=0x6a7661795c374c0bfc635934efaddff3a7ee23b6
ANY_DOLA=0x0615dbba33fe61a31c7ed131bda6655ed76748b1
MULTICHAIN_ROUTER=0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc
BSC_DOLA=0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840
ETH_DOLA=0x865377367054516e17014ccded1e7d814edc9ce4
L1_GATEWAY=0xa3a7b6f88361f48403514059f1f16c8e78d60eec

cast call "$ANY_DOLA" 'name()(string)' --rpc-url "$ARB_RPC"
cast call "$ANY_DOLA" 'symbol()(string)' --rpc-url "$ARB_RPC"
cast call "$ANY_DOLA" 'underlying()(address)' --rpc-url "$ARB_RPC"
cast call "$ANY_DOLA" 'vault()(address)' --rpc-url "$ARB_RPC"
cast call "$ANY_DOLA" 'getAllMinters()(address[])' --rpc-url "$ARB_RPC"

cast call "$MULTICHAIN_ROUTER" 'mpc()(address)' --rpc-url "$ARB_RPC"
cast call "$ARB_DOLA" 'balanceOf(address)(uint256)' "$ANY_DOLA" --rpc-url "$ARB_RPC"
cast call "$ARB_DOLA" 'totalSupply()(uint256)' --rpc-url "$ARB_RPC"

cast call "$ETH_DOLA" 'balanceOf(address)(uint256)' "$L1_GATEWAY" --rpc-url "$ETH_RPC"

cast call "$BSC_DOLA" 'underlying()(address)' --rpc-url "$BSC_RPC"
cast call "$BSC_DOLA" 'vault()(address)' --rpc-url "$BSC_RPC"
cast call "$BSC_DOLA" 'getAllMinters()(address[])' --rpc-url "$BSC_RPC"
cast call "$BSC_DOLA" 'totalSupply()(uint256)' --rpc-url "$BSC_RPC"
```

## Simulating the MPC-controlled release

This is an `eth_call`; it does not create a transaction or change state.

```sh
MPC=$(cast call "$MULTICHAIN_ROUTER" 'mpc()(address)' --rpc-url "$ARB_RPC")
RECIPIENT=0x1111111111111111111111111111111111111111

cast call "$MULTICHAIN_ROUTER" \
  'anySwapInUnderlying(bytes32,address,address,uint256,uint256)' \
  0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  "$ANY_DOLA" \
  "$RECIPIENT" \
  1000000000000000000 \
  56 \
  --from "$MPC" \
  --rpc-url "$ARB_RPC"
```

Repeat with `--from "$RECIPIENT"`; the call should revert with `AnyswapV6Router: FORBIDDEN`.

## Refresh policy

Whenever mutable values are published:

1. record chain ID, block number, timestamp, RPC, call signature, and raw result;
2. update [`FACTS.md`](FACTS.md) and [`SUMMARY.md`](SUMMARY.md) together;
3. retain the prior snapshot rather than silently replacing it;
4. do not present explorer labels as proof of contract authority when direct calls or source are available.
