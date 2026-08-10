#property copyright "GoldBot X"
#property version   "0.2.1"
#property strict

#include "Core/GBX_Core.mqh"
#include "Data/GBX_DataEngine.mqh"
#include "Feature/GBX_FeatureEngine.mqh"
#include "Analyzer/GBX_AnalyzerEngine.mqh"
#include "Classifier/GBX_MarketClassifier.mqh"
#include "Strategy/GBX_StrategySelector.mqh"
#include "Decision/GBX_DecisionEngine.mqh"
#include "Risk/GBX_RiskManager.mqh"
#include "Execution/GBX_ExecutionEngine.mqh"
#include "Trade/GBX_TradeManager.mqh"
#include "Memory/GBX_MemoryEngine.mqh"
#include "Reports/GBX_ReportEngine.mqh"

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
CGBXFeatureEngine  g_features;
CGBXAnalyzerEngine   g_analyzers;
CGBXMarketClassifier g_classifier;
CGBXStrategySelector  g_strategy_selector;
CGBXDecisionEngine    g_decision_engine;
CGBXRiskManager       g_risk_manager;
CGBXExecutionEngine   g_execution_engine;
CGBXTradeManager      g_trade_manager;
CGBXMemoryEngine      g_memory_engine;
CGBXReportEngine      g_report_engine;
GBXConfig             g_config;
datetime              g_last_analysis_bar = 0;

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

   if(!g_analyzers.Initialize(g_config))
     {
      g_data.Shutdown();
      g_core.Shutdown(REASON_INITFAILED);
      return INIT_FAILED;
     }

   if(!g_classifier.Initialize(g_config))
     {
      g_data.Shutdown();
      g_core.Shutdown(REASON_INITFAILED);
      return INIT_FAILED;
     }

   if(!g_strategy_selector.Initialize(g_config) || !g_decision_engine.Initialize(g_config) ||
      !g_risk_manager.Initialize(g_config) || !g_execution_engine.Initialize(g_config) ||
      !g_trade_manager.Initialize(g_config) || !g_memory_engine.Initialize(g_config) ||
      !g_report_engine.Initialize(g_config))
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
   const datetime current_bar = iTime(_Symbol,InpPrimaryTimeframe,0);
   if(current_bar == 0 || current_bar == g_last_analysis_bar)
      return;

   if(!g_data.Refresh())
      return;

   g_last_analysis_bar = current_bar;

   GBXDataSnapshot data = g_data.GetSnapshot();
   if(!g_features.Refresh(data))
      return;

   GBXFeatureSnapshot features = g_features.GetSnapshot();
   if(!g_analyzers.Refresh(data,features))
      return;

   GBXAnalysisSnapshot analysis = g_analyzers.GetSnapshot();
   if(!g_classifier.Refresh(data,features,analysis))
      return;

   GBXMarketState market = g_classifier.GetState();
   g_strategy_selector.Refresh(market);

   GBXStrategySelection strategy = g_strategy_selector.GetSelection();
   g_decision_engine.Refresh(market,strategy);

   GBXDecision decision = g_decision_engine.GetDecision();
   g_memory_engine.RecordDecision(decision,market,data.primary_bar.time);
   g_report_engine.UpdateDailyReport(market);
   g_trade_manager.Manage(data,market);

   GBXTradePlan plan;
   if(g_risk_manager.BuildTradePlan(decision,market,data,plan) &&
      g_config.trading_enabled)
      g_execution_engine.Execute(plan);
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
