# DOLA and Multichain: consolidated summary

**State snapshot:** 2026-07-31, Arbitrum block `489736745`

## What is where

BSC users hold `1,793,864.391064841026826353` DOLA issued by Multichain at `0x2f29bc0ffaf9bff337b31cbe6cb5fb3bf12e5840`. That contract is an `AnyswapV6ERC20` with `underlying() == address(0)`. Its holders therefore do not have an onchain redemption right against collateral held by the BSC token contract.

The corresponding real collateral is on Arbitrum. The Multichain `anyDOLA` custody contract at `0x0615dbba33fe61a31c7ed131bda6655ed76748b1` holds exactly:

`1,899,702.791056052107486162` canonical Arbitrum DOLA.

The canonical Arbitrum DOLA is `0x6a7661795c374c0bfc635934efaddff3a7ee23b6`. It represents Ethereum DOLA escrowed by Arbitrum's L1 Standard ERC-20 Gateway.

## Correction to the earlier research

`0x0615...48b1` is not the Multichain router. It is the `anyDOLA` token and custody contract on Arbitrum. Its `underlying()` is canonical Arbitrum DOLA.

The contract's vault and sole minter is Multichain Router V6 at `0xcB9f441FFAE898e7A2f32143Fd79ac899517a9Dc`. That router's current `mpc()` authority is `0xD7ADbfC92d0250f9B1a08e0a32A84137b68A9964`.

## Why Multichain still controls the collateral

The deployed contracts provide this path:

1. The MPC calls `AnyswapV6Router.anySwapInUnderlying(...)`.
2. The router mints `anyDOLA` to a selected recipient.
3. The router calls `anyDOLA.withdrawVault(...)`.
4. `anyDOLA` burns the temporary wrapper and transfers canonical Arbitrum DOLA to that recipient.

A Foundry `eth_call` simulation of this path succeeded when sent from the current MPC and reverted with `AnyswapV6Router: FORBIDDEN` from an arbitrary address. This establishes a presently valid contract-level control path. It does not establish who currently possesses or can exercise the MPC signing authority.

Once released, the canonical Arbitrum DOLA can be withdrawn through the legacy Arbitrum Standard ERC-20 Gateway. A direct call to the legacy L2 gateway does not depend on the current gateway-router mapping. Changing the router mapping alone therefore does not neutralize the existing claim.

## Current bridge state

| Item | Amount (DOLA) |
|---|---:|
| BSC Multichain wrapper supply | `1,793,864.391064841026826353` |
| Canonical Arbitrum DOLA held by `anyDOLA` | `1,899,702.791056052107486162` |
| Total canonical Arbitrum DOLA supply | `1,924,094.289641336370430383` |
| Canonical Arbitrum DOLA outside `anyDOLA` | `24,391.498585284262944221` |
| Ethereum DOLA held by the L1 gateway | `1,924,094.389641336370430484` |

The `anyDOLA` balance exceeds the BSC wrapper supply by `105,838.399991211080659809` DOLA. The repository does not yet establish which other destination-chain liabilities or bridge-accounting entries explain that difference. The complete creditor set must be determined before restitution.

## Technically established conclusions

- Multichain's deployed MPC-controlled contracts retain a valid path to release the `1.8997M` canonical Arbitrum DOLA.
- The released DOLA remains a live claim on Ethereum gateway escrow.
- Registering a new custom gateway changes future routing but does not disable the legacy direct-withdrawal path.
- The DOLA L2 proxy has no callable per-proxy beacon setter. Its shared beacon cannot be reassigned for DOLA alone through the deployed proxy.
- Arbitrum governance can conditionally neutralize the legacy claim by upgrading the legacy L1 gateway's finalization logic for DOLA. An L2-side block can be added as defense in depth.
- Arbitrum governance could conditionally add and execute a one-shot escrow-transfer mechanism, but no direct precedent for such a bridge-escrow transfer was found in the reviewed material.
- Inverse cannot unilaterally seize the Ethereum gateway escrow or blacklist old DOLA through the current Ethereum DOLA contract.
- A full Ethereum DOLA migration is technically possible but changes the token relied upon by every existing integration.

## Decision boundary

If the requirement is that replacement DOLA create no possible duplicate claim, restitution must wait until one of the following is true:

1. the legacy withdrawal claim is technically neutralized;
2. the attributable gateway escrow is recovered; or
3. the entire possible duplicate claim is separately backed.

A reserve based only on an estimated probability of MPC activity does not satisfy a strict no-duplicate-claim requirement.

See [`TECHNICAL_OPTIONS.md`](TECHNICAL_OPTIONS.md) for the concrete actions and [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) for unresolved work.
