#ifndef GBX_DECISION_ENGINE_MQH
#define GBX_DECISION_ENGINE_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"

class CGBXDecisionEngine
  {
private:
   GBXConfig    m_config;
   GBXDecision  m_decision;
   CGBXLogger   m_logger;

   void SetWait(const GBXMarketState &market,
                const GBXStrategySelection &selection,
                const string reason)
     {
      m_decision.action     = GBX_ACTION_WAIT;
      m_decision.strategy   = selection.strategy;
      m_decision.confidence = market.confidence;
      m_decision.quality    = market.quality;
      m_decision.reason     = reason;
     }

public:
   CGBXDecisionEngine(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeDecision(m_decision);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(config.debug_logging);
      GBXInitializeDecision(m_decision);
      m_logger.Info("Decision Engine initialized.");
      return true;
     }

   bool Refresh(const GBXMarketState &market,const GBXStrategySelection &selection)
     {
      GBXInitializeDecision(m_decision);

      if(!market.is_tradeable)
        {
         SetWait(market,selection,"WAIT: market is not currently tradeable.");
         return true;
        }

      if(selection.strategy == GBX_STRATEGY_TREND_FOLLOWING)
        {
         if(market.direction == GBX_DIRECTION_BULLISH)
           {
            m_decision.action     = GBX_ACTION_BUY;
            m_decision.strategy   = selection.strategy;
            m_decision.confidence = market.confidence;
            m_decision.quality    = market.quality;
            m_decision.reason     = "BUY: trend, structure and market quality are aligned.";
            return true;
           }

         if(market.direction == GBX_DIRECTION_BEARISH)
           {
            m_decision.action     = GBX_ACTION_SELL;
            m_decision.strategy   = selection.strategy;
            m_decision.confidence = market.confidence;
            m_decision.quality    = market.quality;
            m_decision.reason     = "SELL: trend, structure and market quality are aligned.";
            return true;
           }
        }

      if(selection.strategy == GBX_STRATEGY_RANGE_SCALPING)
        {
         SetWait(market,selection,"WAIT: range entry side requires dedicated support and resistance validation.");
         return true;
        }

      SetWait(market,selection,selection.rationale);
      return true;
     }

   GBXDecision GetDecision(void) const
     {
      return m_decision;
     }
  };

#endif
