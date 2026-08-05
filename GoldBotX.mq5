#property copyright "GoldBot X"
#property version   "0.2.1"
#property strict

#include "Core/GBX_Core.mqh"
#include "Data/GBX_DataEngine.mqh"
#include "Feature/GBX_FeatureEngine.mqh"

input group "GoldBot X — Core"
input long            InpMagicNumber             = 26080501;
input ENUM_TIMEFRAMES InpPrimaryTimeframe        = PERIOD_M5;
input ENUM_TIMEFRAMES InpContextTimeframe        = PERIOD_H1;
input bool            InpEnableTrading           = false;
input bool            InpDebugLogging            = false;
input int             InpMaxSpreadPoints         = 50;

input group "GoldBot X — Autonomous Risk"
input ENUM_GBX_RISK_PROFILE InpRiskProfile             = GBX_RISK_BALANCED;
input double                InpRiskPerTradePercent     = 0.50;
input double                InpMaxRiskPerTradePercent  = 0.75;
input double                InpMaxAggregateRiskPercent = 2.00;
input double                InpDailyLossLimitPercent   = 3.00;
input int                   InpMaxOpenPositions        = 3;
input bool                  InpAllowPyramiding         = true;
input bool                  InpAllowHedging            = false;
input double                InpMinQualityScore         = 70.0;
input double                InpMinConfidence           = 65.0;

CGBXCore       g_core;
CGBXDataEngine    g_data;
CGBXFeatureEngine g_features;
GBXConfig         g_config;

void BuildConfiguration(GBXConfig &config)
  {
   GBXInitializeConfig(config);
   config.symbol                      = _Symbol;
   config.primary_timeframe           = InpPrimaryTimeframe;
   config.context_timeframe           = InpContextTimeframe;
   config.magic_number                = InpMagicNumber;
   config.trading_enabled             = InpEnableTrading;
   config.debug_logging               = InpDebugLogging;
   config.risk_profile                = InpRiskProfile;
   config.risk_per_trade_percent      = InpRiskPerTradePercent;
   config.max_risk_per_trade_percent  = InpMaxRiskPerTradePercent;
   config.max_aggregate_risk_percent  = InpMaxAggregateRiskPercent;
   config.daily_loss_limit_percent    = InpDailyLossLimitPercent;
   config.max_open_positions          = InpMaxOpenPositions;
   config.max_spread_points           = InpMaxSpreadPoints;
   config.allow_pyramiding            = InpAllowPyramiding;
   config.allow_hedging               = InpAllowHedging;
   config.min_quality_score           = InpMinQualityScore;
   config.min_confidence              = InpMinConfidence;
  }

int OnInit()
  {
   BuildConfiguration(g_config);

   if(!g_core.Initialize(g_config))
      return INIT_FAILED;

   if(!g_data.Initialize(g_config))
     {
      g_core.Shutdown(REASON_INITFAILED);
      return INIT_FAILED;
     }

   if(!g_features.Initialize(g_config))
     {
      g_data.Shutdown();
      g_core.Shutdown(REASON_INITFAILED);
      return INIT_FAILED;
     }

   EventSetTimer(GBX_TIMER_SECONDS);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_data.Shutdown();
   g_core.Shutdown(reason);
  }

void RefreshAnalysisPipeline(void)
  {
   if(!g_data.Refresh())
      return;

   GBXDataSnapshot data = g_data.GetSnapshot();
   g_features.Refresh(data);
  }

void OnTick()
  {
   g_core.OnTick();
   RefreshAnalysisPipeline();
  }

void OnTimer()
  {
   g_core.OnTimer();
   RefreshAnalysisPipeline();
  }
