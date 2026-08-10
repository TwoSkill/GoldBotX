#ifndef GBX_REPORT_ENGINE_MQH
#define GBX_REPORT_ENGINE_MQH

#include "../Core/GBX_Types.mqh"

class CGBXReportEngine
  {
private:
   GBXConfig m_config;
   datetime  m_last_report_day;

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
      FileWrite(handle,"Symbol: "+m_config.symbol);
      FileWrite(handle,"Balance: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
      FileWrite(handle,"Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
      FileWrite(handle,"Market regime: "+EnumToString(market.regime));
      FileWrite(handle,"Quality: "+DoubleToString(market.quality,2));
      FileWrite(handle,"Confidence: "+DoubleToString(market.confidence,2));
      FileClose(handle);
      m_last_report_day=today;
     }
  };

#endif
