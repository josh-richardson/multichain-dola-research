# Multichain DOLA research

This repository documents the Multichain-linked DOLA liabilities on BSC and the canonical DOLA held under Multichain control on Arbitrum.

Start here:

- [`research/SUMMARY.md`](research/SUMMARY.md) - concise statement of the problem and current conclusions
- [`research/FACTS.md`](research/FACTS.md) - verified contracts, balances, and control paths
- [`research/TECHNICAL_OPTIONS.md`](research/TECHNICAL_OPTIONS.md) - actions that are technically possible, their required authorities, and their limitations
- [`research/GOVERNANCE.md`](research/GOVERNANCE.md) - governance mechanics and relevant precedents, without predictions about how a DAO will vote
- [`research/OPEN_QUESTIONS.md`](research/OPEN_QUESTIONS.md) - work that remains unresolved
- [`research/REPRODUCIBILITY.md`](research/REPRODUCIBILITY.md) - commands used to refresh the onchain state

Raw explorer responses, verified source bundles, and source PDFs are retained under [`research/artifacts/`](research/artifacts/). Earlier working memos are retained under [`research/archive/`](research/archive/) but are superseded by the canonical documents above.

## Evidence standard

The canonical documents distinguish:

- **Verified onchain** - read directly from deployed contracts at a stated block.
- **Verified source** - established from verified deployed contract source.
- **Technically demonstrated** - reproduced with a call, simulation, trace, or source-level proof.
- **Derived** - arithmetic or logic using verified inputs.
- **Conditional** - possible only if the stated authority takes the stated action.
- **Unresolved** - not yet established.

Political probability estimates and predictions about how a DAO, delegate, court, or key holder might behave are intentionally excluded.
