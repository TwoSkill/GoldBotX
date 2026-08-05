# GoldBot X

GoldBot X is a modular MT5 Expert Advisor that classifies market context before deciding whether to trade.

Its autonomous operating contract is:

- classify trend, range, compression, volatility, session and market favorability;
- calculate dynamic stop loss and take profit from volatility, structure and liquidity;
- manage open trades actively with break-even, partial exits, adaptive trailing and early exits;
- allow up to three concurrent positions when independent, high-quality opportunities fit the portfolio risk budget;
- permit additions only after confirmation, never to average a losing position;
- prevent martingale, grid recovery and arbitrary hedging;
- use a risk budget across all open positions instead of treating each trade in isolation;
- learn statistically from decisions and outcomes while keeping strategy and code changes supervised.

The current implementation contains the Core and Data Engine. Trading remains disabled until the analysis, decision, risk and execution modules are complete and tested.
