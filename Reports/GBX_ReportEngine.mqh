#ifndef GBX_REPORT_ENGINE_MQH
#define GBX_REPORT_ENGINE_MQH

#include "../Core/GBX_Types.mqh"

class CGBXReportEngine
  {
private:
   GBXConfig m_config;
   datetime  m_last_report_day;

   int OpenPositions(void) const
     {
      int count=0;
      for(int i=0;i<PositionsTotal();i++)
        {
         if(PositionGetSymbol(i)==m_config.symbol &&
            PositionGetInteger(POSITION_MAGIC)==m_config.magic_number)
            count++;
        }
      return count;
     }

public:
   CGBXReportEngine(void)
     {
      GBXInitializeConfig(m_config);
      m_last_report_day=0;
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      return true;
     }

   void UpdateDailyReport(const GBXMarketState &market)
     {
      const datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
      if(today==m_last_report_day)
         return;

      const int handle=FileOpen("GoldBot_Report.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return;

      FileWrite(handle,"GoldBot X daily state");
      FileWrite(handle,"Updated: "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      FileWrite(handle,"Symbol: "+m_config.symbol);
      FileWrite(handle,"Primary timeframe: "+EnumToString(m_config.primary_timeframe));
      FileWrite(handle,"Context timeframe: "+EnumToString(m_config.context_timeframe));
      FileWrite(handle,"Trading enabled: "+(m_config.trading_enabled ? "true" : "false"));
      FileWrite(handle,"Dry run: "+(m_config.dry_run ? "true" : "false"));
      FileWrite(handle,"Balance: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
      FileWrite(handle,"Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
      FileWrite(handle,"Open positions: "+IntegerToString(OpenPositions())+"/"+IntegerToString(m_config.max_open_positions));
      FileWrite(handle,"Market session: "+EnumToString(market.session));
      FileWrite(handle,"Market regime: "+EnumToString(market.regime));
      FileWrite(handle,"Favorability: "+EnumToString(market.favorability));
      FileWrite(handle,"Quality: "+DoubleToString(market.quality,2));
      FileWrite(handle,"Confidence: "+DoubleToString(market.confidence,2));
      FileWrite(handle,"Risk multiplier: "+DoubleToString(market.risk_multiplier,2));
      FileWrite(handle,"Liquidity: "+DoubleToString(market.liquidity_score,2));
      FileClose(handle);
      m_last_report_day=today;
     }
  };

#endif
