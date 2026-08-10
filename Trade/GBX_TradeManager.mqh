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

public:
   CGBXTradeManager(void)
     {
      GBXInitializeConfig(m_config);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      m_trade.SetExpertMagicNumber(m_config.magic_number);
      return true;
     }

   void Manage(const GBXDataSnapshot &data,const GBXMarketState &market)
     {
      if(!data.ready || data.indicators.atr<=0.0)
         return;

      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         const string symbol=PositionGetSymbol(i);
         if(symbol!=m_config.symbol || PositionGetInteger(POSITION_MAGIC)!=m_config.magic_number)
            continue;

         const long type=PositionGetInteger(POSITION_TYPE);
         const double open=PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl=PositionGetDouble(POSITION_SL);
         const double tp=PositionGetDouble(POSITION_TP);
         const double current=(type==POSITION_TYPE_BUY ? data.quote.bid : data.quote.ask);
         const double risk=MathAbs(open-sl);
         if(risk<=0.0)
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

         if(new_sl!=sl)
            m_trade.PositionModify(symbol,new_sl,tp);
        }
     }
  };

#endif
