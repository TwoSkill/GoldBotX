#ifndef GBX_EXECUTION_ENGINE_MQH
#define GBX_EXECUTION_ENGINE_MQH

#include <Trade/Trade.mqh>
#include "../Core/GBX_Types.mqh"

class CGBXExecutionEngine
  {
private:
   GBXConfig m_config;
   CTrade    m_trade;

public:
   CGBXExecutionEngine(void)
     {
      GBXInitializeConfig(m_config);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      m_trade.SetExpertMagicNumber(m_config.magic_number);
      m_trade.SetTypeFillingBySymbol(m_config.symbol);
      return true;
     }

   bool Execute(const GBXTradePlan &plan)
     {
      if(!m_config.trading_enabled || plan.volume<=0.0)
         return false;

      if(plan.action==GBX_ACTION_BUY)
         return m_trade.Buy(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");
      if(plan.action==GBX_ACTION_SELL)
         return m_trade.Sell(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");
      return false;
     }

   string LastResult(void) const
     {
      return m_trade.ResultRetcodeDescription();
     }
  };

#endif
