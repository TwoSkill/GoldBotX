#ifndef GBX_DIAGNOSTICS_MQH
#define GBX_DIAGNOSTICS_MQH

#include "GBX_Logger.mqh"
#include "GBX_Types.mqh"
#include "../Data/GBX_DataTypes.mqh"

class CGBXDiagnostics
  {
private:
   CGBXLogger m_logger;
   string     m_last_reason;
   string     m_last_execution;

public:
   CGBXDiagnostics(void)
     {
      m_last_reason="";
      m_last_execution="";
     }

   void Initialize(const GBXConfig &config)
     {
      m_logger.Configure(config.debug_logging);
      m_last_reason="";
      m_last_execution="";
     }

   void MarketDecision(const GBXDecision &decision,
                       const GBXMarketState &market,
                       const GBXDataSnapshot &data)
     {
      m_last_reason=decision.reason;
      m_logger.Info(StringFormat("MARKET DECISION symbol=%s tf=%s regime=%s direction=%s quality=%.2f confidence=%.2f spread=%.1f risk_multiplier=%.2f decision=%s reason=%s",
                                 _Symbol,
                                 EnumToString(PERIOD_CURRENT),
                                 EnumToString(market.regime),
                                 EnumToString(market.direction),
                                 market.quality,
                                 market.confidence,
                                 data.quote.spread_points,
                                 market.risk_multiplier,
                                 EnumToString(decision.action),
                                 decision.reason));
     }

   void TradePlanRejected(const GBXTradePlan &plan,const string reason)
     {
      m_last_reason=reason;
      m_logger.Warning(StringFormat("TRADE PLAN REJECTED action=%s entry=%.5f sl=%.5f tp=%.5f volume=%.3f risk=%.2f reason=%s",
                                    EnumToString(plan.action),
                                    plan.entry_price,
                                    plan.stop_loss,
                                    plan.take_profit,
                                    plan.volume,
                                    plan.risk_percent,
                                    reason));
     }

   void ExecutionResult(const string result)
     {
      m_last_execution=result;
      m_logger.Info("EXECUTION "+result);
     }

   string LastReason(void) const
     {
      return m_last_reason;
     }

   string LastExecution(void) const
     {
      return m_last_execution;
     }
  };

#endif
