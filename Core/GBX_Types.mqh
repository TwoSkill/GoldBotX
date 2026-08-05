#ifndef GBX_TYPES_MQH
#define GBX_TYPES_MQH

#include "GBX_Enums.mqh"

struct GBXConfig
  {
   string          symbol;
   ENUM_TIMEFRAMES primary_timeframe;
   ENUM_TIMEFRAMES context_timeframe;
   long            magic_number;
   bool            trading_enabled;
   bool            debug_logging;
   double          risk_per_trade_percent;
   double          daily_loss_limit_percent;
   int             max_open_positions;
   int             max_spread_points;
  };

struct GBXRuntimeState
  {
   bool      initialized;
   datetime  started_at;
   datetime  last_tick_at;
   ulong     tick_count;
   double    bid;
   double    ask;
   double    mid;
   double    spread_points;
  };

struct GBXMarketState
  {
   ENUM_GBX_MARKET_REGIME regime;
   ENUM_GBX_DIRECTION     direction;
   ENUM_GBX_SESSION       session;
   double                 trend_score;
   double                 structure_score;
   double                 momentum_score;
   double                 volatility_score;
   double                 liquidity_score;
   double                 confidence;
   double                 quality;
  };

struct GBXDecision
  {
   ENUM_GBX_ACTION action;
   double          confidence;
   double          quality;
   string          reason;
  };

void GBXInitializeConfig(GBXConfig &config)
  {
   config.symbol                   = _Symbol;
   config.primary_timeframe        = PERIOD_M5;
   config.context_timeframe        = PERIOD_H1;
   config.magic_number             = 26080501;
   config.trading_enabled          = false;
   config.debug_logging            = false;
   config.risk_per_trade_percent   = 0.50;
   config.daily_loss_limit_percent = 2.00;
   config.max_open_positions       = 1;
   config.max_spread_points        = 50;
  }

void GBXInitializeRuntimeState(GBXRuntimeState &state)
  {
   state.initialized   = false;
   state.started_at    = 0;
   state.last_tick_at  = 0;
   state.tick_count    = 0;
   state.bid           = 0.0;
   state.ask           = 0.0;
   state.mid           = 0.0;
   state.spread_points = 0.0;
  }

void GBXInitializeMarketState(GBXMarketState &state)
  {
   state.regime           = GBX_REGIME_UNKNOWN;
   state.direction        = GBX_DIRECTION_NEUTRAL;
   state.session          = GBX_SESSION_NONE;
   state.trend_score      = 0.0;
   state.structure_score  = 0.0;
   state.momentum_score   = 0.0;
   state.volatility_score = 0.0;
   state.liquidity_score  = 0.0;
   state.confidence       = 0.0;
   state.quality          = 0.0;
  }

#endif
