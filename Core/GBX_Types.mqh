#ifndef GBX_TYPES_MQH
#define GBX_TYPES_MQH

#include "GBX_Enums.mqh"

struct GBXConfig
  {
   string                symbol;
   ENUM_TIMEFRAMES       primary_timeframe;
   ENUM_TIMEFRAMES       context_timeframe;
   long                  magic_number;
   bool                  trading_enabled;
   bool                  dry_run;
   bool                  debug_logging;
   ENUM_GBX_RISK_PROFILE risk_profile;
   double                risk_per_trade_percent;
   double                max_risk_per_trade_percent;
   double                max_aggregate_risk_percent;
   double                daily_loss_limit_percent;
   int                   max_open_positions;
   int                   max_spread_points;
   bool                  allow_pyramiding;
   bool                  allow_hedging;
   double                min_quality_score;
   double                min_confidence;
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
   ENUM_GBX_MARKET_REGIME       regime;
   ENUM_GBX_DIRECTION           direction;
   ENUM_GBX_SESSION             session;
   ENUM_GBX_MARKET_FAVORABILITY favorability;
   bool                         is_tradeable;
   bool                         can_add_position;
   double                       trend_score;
   double                       structure_score;
   double                       momentum_score;
   double                       volatility_score;
   double                       liquidity_score;
   double                       confidence;
   double                       quality;
   double                       risk_multiplier;
  };

struct GBXStrategySelection
  {
   ENUM_GBX_STRATEGY strategy;
   double            score;
   string            rationale;
  };

struct GBXDecision
  {
   ENUM_GBX_ACTION   action;
   ENUM_GBX_STRATEGY strategy;
   double            confidence;
   double            quality;
   string            reason;
  };

struct GBXTradePlan
  {
   ENUM_GBX_ACTION action;
   bool            is_addition;
   double          entry_price;
   double          volume;
   double          stop_loss;
   double          take_profit;
   double          risk_percent;
   double          planned_reward_risk;
   string          rationale;
  };

void GBXInitializeConfig(GBXConfig &config)
  {
   config.symbol                      = _Symbol;
   config.primary_timeframe           = PERIOD_M5;
   config.context_timeframe           = PERIOD_H1;
   config.magic_number                = 26080501;
   config.trading_enabled             = false;
   config.dry_run                     = true;
   config.debug_logging               = false;
   config.risk_profile                = GBX_RISK_BALANCED;
   config.risk_per_trade_percent      = 0.50;
   config.max_risk_per_trade_percent  = 0.75;
   config.max_aggregate_risk_percent  = 2.00;
   config.daily_loss_limit_percent    = 3.00;
   config.max_open_positions          = 3;
   config.max_spread_points           = 50;
   config.allow_pyramiding            = true;
   config.allow_hedging               = false;
   config.min_quality_score           = 70.0;
   config.min_confidence              = 65.0;
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
   state.favorability     = GBX_FAVORABILITY_UNKNOWN;
   state.is_tradeable     = false;
   state.can_add_position = false;
   state.trend_score      = 0.0;
   state.structure_score  = 0.0;
   state.momentum_score   = 0.0;
   state.volatility_score = 0.0;
   state.liquidity_score  = 0.0;
   state.confidence       = 0.0;
   state.quality          = 0.0;
   state.risk_multiplier  = 0.0;
  }

void GBXInitializeStrategySelection(GBXStrategySelection &selection)
  {
   selection.strategy  = GBX_STRATEGY_WAIT;
   selection.score     = 0.0;
   selection.rationale = "";
  }

void GBXInitializeDecision(GBXDecision &decision)
  {
   decision.action     = GBX_ACTION_WAIT;
   decision.strategy   = GBX_STRATEGY_WAIT;
   decision.confidence = 0.0;
   decision.quality    = 0.0;
   decision.reason     = "";
  }

void GBXInitializeTradePlan(GBXTradePlan &plan)
  {
   plan.action              = GBX_ACTION_WAIT;
   plan.is_addition         = false;
   plan.entry_price         = 0.0;
   plan.volume              = 0.0;
   plan.stop_loss           = 0.0;
   plan.take_profit         = 0.0;
   plan.risk_percent        = 0.0;
   plan.planned_reward_risk = 0.0;
   plan.rationale           = "";
  }

#endif
