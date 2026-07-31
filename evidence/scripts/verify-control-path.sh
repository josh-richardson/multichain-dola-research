#!/usr/bin/env bash
set -euo pipefail

arb_rpc="${ARB_RPC:-https://arbitrum-one-rpc.publicnode.com}"
multichain_router=0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc
any_dola=0x0615dbba33fe61a31c7ed131bda6655ed76748b1
recipient=0x1111111111111111111111111111111111111111
test_tx_hash=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

mpc=$(cast call "$multichain_router" 'mpc()(address)' --rpc-url "$arb_rpc")

echo "configured_mpc=$mpc"
echo "simulating one-DOLA release from configured MPC"
cast call "$multichain_router" \
  'anySwapInUnderlying(bytes32,address,address,uint256,uint256)' \
  "$test_tx_hash" \
  "$any_dola" \
  "$recipient" \
  1000000000000000000 \
  56 \
  --from "$mpc" \
  --rpc-url "$arb_rpc"

echo "simulating the same call from an arbitrary address; a FORBIDDEN revert is expected"
if cast call "$multichain_router" \
  'anySwapInUnderlying(bytes32,address,address,uint256,uint256)' \
  "$test_tx_hash" \
  "$any_dola" \
  "$recipient" \
  1000000000000000000 \
  56 \
  --from "$recipient" \
  --rpc-url "$arb_rpc" 2>&1; then
  echo "unexpected success from arbitrary caller" >&2
  exit 1
else
  echo "arbitrary caller rejected as expected"
fi
