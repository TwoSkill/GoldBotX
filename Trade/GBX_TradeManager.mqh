#ifndef GBX_TRADE_MANAGER_MQH
#define GBX_TRADE_MANAGER_MQH

#include <Trade/Trade.mqh>
#include "../Core/GBX_Types.mqh"
#include "../Data/GBX_DataTypes.mqh"

class CGBXTradeManager
  {
private:
   GBXConfig m_config;
   CTrade    m_trade;
   string    m_last_result;

   double NormalizePriceToTick(const double price) const
     {
      const double tick_size=SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_SIZE);
      const int digits=(int)SymbolInfoInteger(m_config.symbol,SYMBOL_DIGITS);
      if(tick_size<=0.0)
         return NormalizeDouble(price,digits);
      return NormalizeDouble(MathRound(price/tick_size)*tick_size,digits);
     }

   bool StopCanBeModified(const long type,const double current,const double new_sl) const
     {
      const double point=SymbolInfoDouble(m_config.symbol,SYMBOL_POINT);
      if(point<=0.0 || current<=0.0 || new_sl<=0.0)
         return false;

      const double stop_distance=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
      const double freeze_distance=SymbolInfoInteger(m_config.symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;
      const double minimum_distance=MathMax(stop_distance,freeze_distance);

      if(type==POSITION_TYPE_BUY)
         return new_sl<current-minimum_distance;
      if(type==POSITION_TYPE_SELL)
         return new_sl>current+minimum_distance;
      return false;
     }

public:
   CGBXTradeManager(void)
     {
      GBXInitializeConfig(m_config);
      m_last_result="";
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      m_trade.SetExpertMagicNumber(m_config.magic_number);
      m_trade.SetTypeFillingBySymbol(m_config.symbol);
      m_last_result="";
      return true;
     }

   void Manage(const GBXDataSnapshot &data,const GBXMarketState &market)
     {
      if(!m_config.trading_enabled || m_config.dry_run)
         return;
      if(!data.ready || data.indicators.atr<=0.0)
         return;

      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         const string symbol=PositionGetSymbol(i);
         if(symbol!=m_config.symbol || PositionGetInteger(POSITION_MAGIC)!=m_config.magic_number)
            continue;

         const ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
         const long type=PositionGetInteger(POSITION_TYPE);
         const double open=PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl=PositionGetDouble(POSITION_SL);
         const double tp=PositionGetDouble(POSITION_TP);
         const double current=(type==POSITION_TYPE_BUY ? data.quote.bid : data.quote.ask);
         const double risk=MathAbs(open-sl);
         if(ticket==0 || risk<=0.0)
            continue;

         const double profit_distance=(type==POSITION_TYPE_BUY ? current-open : open-current);
         double new_sl=sl;

         if(profit_distance>=risk && market.confidence>=m_config.min_confidence)
           {
            if(type==POSITION_TYPE_BUY)
               new_sl=MathMax(new_sl,open);
            else
               new_sl=(new_sl==0.0 ? open : MathMin(new_sl,open));
           }

         if(profit_distance>=risk*1.50 && market.confidence>=m_config.min_confidence)
           {
            const double trail=(type==POSITION_TYPE_BUY ? current-data.indicators.atr : current+data.indicators.atr);
            if(type==POSITION_TYPE_BUY)
               new_sl=MathMax(new_sl,trail);
            else
               new_sl=(new_sl==0.0 ? trail : MathMin(new_sl,trail));
           }

         new_sl=NormalizePriceToTick(new_sl);
         if(new_sl==sl || !StopCanBeModified(type,current,new_sl))
            continue;

         if(type==POSITION_TYPE_BUY && new_sl<sl)
            continue;
         if(type==POSITION_TYPE_SELL && sl>0.0 && new_sl>sl)
            continue;

         const bool modified=m_trade.PositionModify(ticket,new_sl,tp);
         const uint retcode=m_trade.ResultRetcode();
         m_last_result=StringFormat("POSITION_MODIFY ticket=%I64d modified=%s retcode=%u description=%s sl=%.5f tp=%.5f",
                                    (long)ticket,
                                    (modified ? "true" : "false"),
                                    retcode,
                                    m_trade.ResultRetcodeDescription(),
                                    new_sl,
                                    tp);
        }
     }

   string LastResult(void) const
     {
      return m_last_result;
     }
  };

#endif
