#ifndef GBX_STRATEGY_SELECTOR_MQH
#define GBX_STRATEGY_SELECTOR_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"

class CGBXStrategySelector
  {
private:
   GBXConfig            m_config;
   GBXStrategySelection m_selection;
   CGBXLogger           m_logger;

public:
   CGBXStrategySelector(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeStrategySelection(m_selection);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(config.debug_logging);
      GBXInitializeStrategySelection(m_selection);
      m_logger.Info("Strategy Selector initialized.");
      return true;
     }

   bool Refresh(const GBXMarketState &market)
     {
      GBXInitializeStrategySelection(m_selection);

      if(!market.is_tradeable)
        {
         m_selection.rationale = "Market quality or confidence is below the trading threshold.";
         return true;
        }

      if(market.regime == GBX_REGIME_BULLISH_TREND ||
         market.regime == GBX_REGIME_BEARISH_TREND ||
         market.regime == GBX_REGIME_FORMING_TREND)
        {
         m_selection.strategy  = GBX_STRATEGY_TREND_FOLLOWING;
         m_selection.score     = market.quality;
         m_selection.rationale = "Aligned trend and structure support a trend-following approach.";
         return true;
        }

      if(market.regime == GBX_REGIME_CLEAN_RANGE)
        {
         m_selection.strategy  = GBX_STRATEGY_RANGE_SCALPING;
         m_selection.score     = market.quality;
         m_selection.rationale = "Clean range identified; range logic will validate the entry side.";
         return true;
        }

      m_selection.rationale = "No strategy has a sufficient statistical advantage.";
      return true;
     }

   GBXStrategySelection GetSelection(void) const
     {
      return m_selection;
     }
  };

#endif
