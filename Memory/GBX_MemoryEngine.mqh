#ifndef GBX_MEMORY_ENGINE_MQH
#define GBX_MEMORY_ENGINE_MQH

#include "../Core/GBX_Types.mqh"

class CGBXMemoryEngine
  {
private:
   GBXConfig m_config;
   datetime  m_last_recorded_bar;

public:
   CGBXMemoryEngine(void)
     {
      GBXInitializeConfig(m_config);
      m_last_recorded_bar=0;
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      return true;
     }

   void RecordDecision(const GBXDecision &decision,const GBXMarketState &market,const datetime bar_time)
     {
      if(bar_time==0 || bar_time==m_last_recorded_bar)
         return;

      const int handle=FileOpen("GoldBotX_Decisions.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return;

      FileSeek(handle,0,SEEK_END);
      FileWrite(handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                m_config.symbol,
                EnumToString(decision.action),
                EnumToString(decision.strategy),
                DoubleToString(decision.confidence,2),
                DoubleToString(decision.quality,2),
                EnumToString(market.regime),
                decision.reason);
      FileClose(handle);
      m_last_recorded_bar=bar_time;
     }
  };

#endif
