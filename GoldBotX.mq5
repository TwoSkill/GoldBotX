#property copyright "GoldBot X"
#property version   "0.1.0"
#property strict

#include "Core/GBX_Core.mqh"

input group "GoldBot X — Core"
input long            InpMagicNumber             = 26080501;
input ENUM_TIMEFRAMES InpPrimaryTimeframe        = PERIOD_M5;
input ENUM_TIMEFRAMES InpContextTimeframe        = PERIOD_H1;
input bool            InpEnableTrading           = false;
input bool            InpDebugLogging            = false;
input double          InpRiskPerTradePercent     = 0.50;
input double          InpDailyLossLimitPercent   = 2.00;
input int             InpMaxOpenPositions        = 1;
input int             InpMaxSpreadPoints         = 50;

CGBXCore g_core;

void BuildConfiguration(GBXConfig &config)
  {
   GBXInitializeConfig(config);
   config.symbol                   = _Symbol;
   config.primary_timeframe        = InpPrimaryTimeframe;
   config.context_timeframe        = InpContextTimeframe;
   config.magic_number             = InpMagicNumber;
   config.trading_enabled          = InpEnableTrading;
   config.debug_logging            = InpDebugLogging;
   config.risk_per_trade_percent   = InpRiskPerTradePercent;
   config.daily_loss_limit_percent = InpDailyLossLimitPercent;
   config.max_open_positions       = InpMaxOpenPositions;
   config.max_spread_points        = InpMaxSpreadPoints;
  }

int OnInit()
  {
   GBXConfig config;
   BuildConfiguration(config);

   if(!g_core.Initialize(config))
      return INIT_FAILED;

   EventSetTimer(GBX_TIMER_SECONDS);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_core.Shutdown(reason);
  }

void OnTick()
  {
   g_core.OnTick();
  }

void OnTimer()
  {
   g_core.OnTimer();
  }
