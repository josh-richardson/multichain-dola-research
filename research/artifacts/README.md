# Artifact manifest

These files are supporting evidence and originating context. They are not canonical conclusions.

| File | Purpose | Notes |
|---|---|---|
| `dola-l1.json` | Verified Ethereum DOLA source bundle | Explorer-format source response |
| `l1router.json` | L1 gateway router proxy source bundle | Explorer-format source response |
| `l1router_impl.txt` | L1 gateway router implementation source | Despite the extension, contains structured explorer source |
| `l2gateway.json` | L2 standard gateway implementation source | Used for direct-call and `bridgeBurn` analysis |
| `DOLA Multichain Hack Analysis.pdf` | Originating model conversation | Contains preliminary analysis; superseded by canonical research documents |
| `arbitrum-upgrades.pdf` | Trail of Bits Arbitrum upgrades report | General governance-upgrade reference, not proof of a DOLA-specific action |
| `message.txt` | Original recovery idea and links | Uses the now-corrected description of `0x0615...` as a router |

The `impls/` directory at repository root contains explorer responses for historical L2 gateway implementations. `0x370E...json` records that source was not verified; it should not be treated as a source bundle.
