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

   int VolumeDigits(const double step) const
     {
      double value=step;
      int digits=0;
      while(value<1.0 && digits<8)
        {
         value*=10.0;
         digits++;
        }
      return digits;
     }

   double NormalizeVolume(const double volume) const
     {
      const double step=SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_STEP);
      if(step<=0.0)
         return 0.0;
      return NormalizeDouble(MathFloor(volume/step)*step,VolumeDigits(step));
     }

   double NormalizePriceToTick(const double price) const
     {
      const double tick_size=SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_SIZE);
      const int digits=(int)SymbolInfoInteger(m_config.symbol,SYMBOL_DIGITS);
      if(tick_size<=0.0)
         return NormalizeDouble(price,digits);
      return NormalizeDouble(MathRound(price/tick_size)*tick_size,digits);
     }

   ENUM_ORDER_TYPE_FILLING ResolveFillingMode(void) const
     {
      const long filling=(long)SymbolInfoInteger(m_config.symbol,SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
         return ORDER_FILLING_FOK;
      if((filling & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
         return ORDER_FILLING_IOC;
      return ORDER_FILLING_RETURN;
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

      const double point=SymbolInfoDouble(m_config.symbol,SYMBOL_POINT);
      const double tick_size=SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_SIZE);
      const double tick_value=SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_VALUE);
      const double bid=SymbolInfoDouble(m_config.symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(m_config.symbol,SYMBOL_ASK);
      if(point<=0.0 || tick_size<=0.0 || tick_value<=0.0 || bid<=0.0 || ask<=0.0)
        {
         reason="INVALID_SYMBOL_PRICE_DATA";
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
      const double step=SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_STEP);
      if(minimum<=0.0 || maximum<=0.0 || step<=0.0)
        {
         reason="INVALID_VOLUME_RULES";
         return false;
        }
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
      if(MathAbs(plan.volume-NormalizeVolume(plan.volume))>step*0.001)
        {
         reason="INVALID_VOLUME_STEP";
         return false;
        }

      if(MathAbs(plan.stop_loss-NormalizePriceToTick(plan.stop_loss))>tick_size*0.10 ||
         MathAbs(plan.take_profit-NormalizePriceToTick(plan.take_profit))>tick_size*0.10)
        {
         reason="INVALID_PRICE_TICK_SIZE";
         return false;
        }

      const double stop_distance=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
      const double freeze_distance=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;
      const double minimum_distance=MathMax(stop_distance,freeze_distance);

      if(plan.action==GBX_ACTION_BUY &&
         (plan.stop_loss>=bid-minimum_distance || plan.take_profit<=ask+minimum_distance))
        {
         reason=(freeze_distance>0.0 ? "INVALID_STOPS_OR_FREEZE_LEVEL" : "INVALID_STOPS");
         return false;
        }
      if(plan.action==GBX_ACTION_SELL &&
         (plan.stop_loss<=ask+minimum_distance || plan.take_profit>=bid-minimum_distance))
        {
         reason=(freeze_distance>0.0 ? "INVALID_STOPS_OR_FREEZE_LEVEL" : "INVALID_STOPS");
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

      MqlTradeRequest request;
      MqlTradeCheckResult check;
      ZeroMemory(request);
      ZeroMemory(check);
      request.action=TRADE_ACTION_DEAL;
      request.symbol=m_config.symbol;
      request.magic=m_config.magic_number;
      request.volume=plan.volume;
      request.type=order_type;
      request.price=price;
      request.sl=plan.stop_loss;
      request.tp=plan.take_profit;
      request.deviation=20;
      request.type_filling=ResolveFillingMode();

      if(!OrderCheck(request,check))
        {
         reason=StringFormat("ORDER_CHECK_FAILED retcode=%u comment=%s",check.retcode,check.comment);
         return false;
        }
      if(check.retcode!=TRADE_RETCODE_DONE && check.retcode!=TRADE_RETCODE_PLACED)
        {
         reason=StringFormat("ORDER_CHECK_REJECTED retcode=%u comment=%s",check.retcode,check.comment);
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
         m_last_result=StringFormat("DRY_RUN_VALIDATED signal=%s volume=%.3f risk=%.2f entry=%.5f sl=%.5f tp=%.5f rr=%.2f",
                                    EnumToString(plan.signal_class),plan.volume,plan.risk_percent,
                                    plan.entry_price,plan.stop_loss,plan.take_profit,plan.planned_reward_risk);
         return false;
        }

      bool submitted=false;
      if(plan.action==GBX_ACTION_BUY)
         submitted=m_trade.Buy(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");
      else if(plan.action==GBX_ACTION_SELL)
         submitted=m_trade.Sell(plan.volume,m_config.symbol,0.0,plan.stop_loss,plan.take_profit,"GoldBot X");

      const uint retcode=m_trade.ResultRetcode();
      m_last_result=StringFormat("retcode=%u description=%s deal=%I64d order=%I64d price=%.5f volume=%.3f",
                                 retcode,
                                 m_trade.ResultRetcodeDescription(),
                                 (long)m_trade.ResultDeal(),
                                 (long)m_trade.ResultOrder(),
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
