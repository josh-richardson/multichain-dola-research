#!/usr/bin/env bash
set -euo pipefail

arb_rpc="${ARB_RPC:-https://arbitrum-one-rpc.publicnode.com}"
eth_rpc="${ETH_RPC:-https://ethereum-rpc.publicnode.com}"
bsc_rpc="${BSC_RPC:-https://bsc-rpc.publicnode.com}"

arb_dola=0x6a7661795c374c0bfc635934efaddff3a7ee23b6
any_dola=0x0615dbba33fe61a31c7ed131bda6655ed76748b1
multichain_router=0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc
bsc_dola=0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840
eth_dola=0x865377367054516e17014ccded1e7d814edc9ce4
l1_gateway=0xa3a7b6f88361f48403514059f1f16c8e78d60eec

echo "arbitrum_block=$(cast block-number --rpc-url "$arb_rpc")"
echo "anydola_name=$(cast call "$any_dola" 'name()(string)' --rpc-url "$arb_rpc")"
echo "anydola_symbol=$(cast call "$any_dola" 'symbol()(string)' --rpc-url "$arb_rpc")"
echo "anydola_underlying=$(cast call "$any_dola" 'underlying()(address)' --rpc-url "$arb_rpc")"
echo "anydola_vault=$(cast call "$any_dola" 'vault()(address)' --rpc-url "$arb_rpc")"
echo "anydola_minters=$(cast call "$any_dola" 'getAllMinters()(address[])' --rpc-url "$arb_rpc")"
echo "router_mpc=$(cast call "$multichain_router" 'mpc()(address)' --rpc-url "$arb_rpc")"
echo "arb_dola_at_anydola=$(cast call "$arb_dola" 'balanceOf(address)(uint256)' "$any_dola" --rpc-url "$arb_rpc")"
echo "arb_dola_supply=$(cast call "$arb_dola" 'totalSupply()(uint256)' --rpc-url "$arb_rpc")"
echo "ethereum_gateway_dola=$(cast call "$eth_dola" 'balanceOf(address)(uint256)' "$l1_gateway" --rpc-url "$eth_rpc")"
echo "bsc_dola_underlying=$(cast call "$bsc_dola" 'underlying()(address)' --rpc-url "$bsc_rpc")"
echo "bsc_dola_vault=$(cast call "$bsc_dola" 'vault()(address)' --rpc-url "$bsc_rpc")"
echo "bsc_dola_minters=$(cast call "$bsc_dola" 'getAllMinters()(address[])' --rpc-url "$bsc_rpc")"
echo "bsc_dola_supply=$(cast call "$bsc_dola" 'totalSupply()(uint256)' --rpc-url "$bsc_rpc")"
