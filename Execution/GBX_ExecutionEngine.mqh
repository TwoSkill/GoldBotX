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
   string    m_last_result;

   bool IsSuccessfulRetcode(const uint retcode) const
     {
      return retcode==TRADE_RETCODE_DONE ||
             retcode==TRADE_RETCODE_PLACED ||
             retcode==TRADE_RETCODE_DONE_PARTIAL;
     }

   bool ValidatePlan(const GBXTradePlan &plan,string &reason)
     {
      reason="";

      if(!m_config.trading_enabled)
        {
         reason="TRADING_DISABLED";
         return false;
        }
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
         reason="EA_TRADE_PERMISSION_DENIED";
         return false;
        }
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
         reason="AUTO_TRADING_DISABLED";
         return false;
        }
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
        {
         reason="ACCOUNT_TRADE_PERMISSION_DENIED";
         return false;
        }
      if(!SymbolSelect(m_config.symbol,true))
        {
         reason="SYMBOL_NOT_SELECTED";
         return false;
        }

      const long trade_mode=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_MODE);
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
        {
         reason="MARKET_CLOSED";
         return false;
        }
      if(plan.action==GBX_ACTION_BUY && trade_mode==SYMBOL_TRADE_MODE_SHORTONLY)
        {
         reason="BUY_NOT_ALLOWED";
         return false;
        }
      if(plan.action==GBX_ACTION_SELL && trade_mode==SYMBOL_TRADE_MODE_LONGONLY)
        {
         reason="SELL_NOT_ALLOWED";
         return false;
        }

      const double minimum=SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_MIN);
      const double maximum=SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_MAX);
      if(plan.volume<minimum)
        {
         reason="VOLUME_BELOW_MINIMUM";
         return false;
        }
      if(plan.volume>maximum)
        {
         reason="INVALID_VOLUME";
         return false;
        }

      const double point=SymbolInfoDouble(m_config.symbol,SYMBOL_POINT);
      const double bid=SymbolInfoDouble(m_config.symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(m_config.symbol,SYMBOL_ASK);
      const double minimum_distance=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;

      if(plan.action==GBX_ACTION_BUY &&
         (plan.stop_loss>=bid-minimum_distance || plan.take_profit<=ask+minimum_distance))
        {
         reason="INVALID_STOPS";
         return false;
        }
      if(plan.action==GBX_ACTION_SELL &&
         (plan.stop_loss<=ask+minimum_distance || plan.take_profit>=bid-minimum_distance))
        {
         reason="INVALID_STOPS";
         return false;
        }

      double margin=0.0;
      const ENUM_ORDER_TYPE order_type=(plan.action==GBX_ACTION_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      const double price=(plan.action==GBX_ACTION_BUY ? ask : bid);
      if(!OrderCalcMargin(order_type,m_config.symbol,plan.volume,price,margin) ||
         margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        {
         reason="INSUFFICIENT_MARGIN";
         return false;
        }
      return true;
     }

public:
   CGBXExecutionEngine(void)
     {
      GBXInitializeConfig(m_config);
      m_last_execution_bar=0;
      m_last_result="";
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
      string reason;
      if(!ValidatePlan(plan,reason))
        {
         m_last_result=reason;
         return false;
        }

      const datetime current_bar=iTime(m_config.symbol,m_config.primary_timeframe,0);
      if(current_bar==0 || current_bar==m_last_execution_bar)
        {
         m_last_result="DUPLICATE_BAR_BLOCKED";
         return false;
        }

      if(m_config.dry_run)
        {
         m_last_result="DRY_RUN_VALIDATED";
         return false;
        }

      bool submitted=false;
      if(plan.action==GBX_ACTION_BUY)
         submitted=m_trade.Buy(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");
      else if(plan.action==GBX_ACTION_SELL)
         submitted=m_trade.Sell(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");

      const uint retcode=m_trade.ResultRetcode();
      m_last_result=StringFormat("retcode=%u description=%s deal=%I64d price=%.5f volume=%.3f",
                                 retcode,
                                 m_trade.ResultRetcodeDescription(),
                                 (long)m_trade.ResultDeal(),
                                 m_trade.ResultPrice(),
                                 m_trade.ResultVolume());

      if(submitted && IsSuccessfulRetcode(retcode))
        {
         m_last_execution_bar=current_bar;
         return true;
        }
      return false;
     }

   string LastResult(void) const
     {
      return m_last_result;
     }
  };

#endif
