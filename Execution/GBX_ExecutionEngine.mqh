#ifndef GBX_EXECUTION_ENGINE_MQH
#define GBX_EXECUTION_ENGINE_MQH

#include <Trade/Trade.mqh>
#include "../Core/GBX_Types.mqh"

class CGBXExecutionEngine
  {
private:
   GBXConfig m_config;
   CTrade    m_trade;
   datetime  m_last_execution_bar;

public:
   CGBXExecutionEngine(void)
     {
      GBXInitializeConfig(m_config);
      m_last_execution_bar=0;
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

      const datetime current_bar=iTime(m_config.symbol,m_config.primary_timeframe,0);
      if(current_bar==0 || current_bar==m_last_execution_bar)
         return false;

      bool executed=false;
      if(plan.action==GBX_ACTION_BUY)
         executed=m_trade.Buy(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");
      else if(plan.action==GBX_ACTION_SELL)
         executed=m_trade.Sell(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");

      if(executed)
         m_last_execution_bar=current_bar;
      return executed;
     }

   string LastResult(void) const
     {
      return m_trade.ResultRetcodeDescription();
     }
  };

#endif
