#ifndef GBX_MEMORY_ENGINE_MQH
#define GBX_MEMORY_ENGINE_MQH

#include "../Core/GBX_Types.mqh"

class CGBXMemoryEngine
  {
private:
   GBXConfig m_config;
   datetime  m_last_recorded_bar;

   int OpenCsv(const string filename,const string header)
     {
      const int handle=FileOpen(filename,FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return INVALID_HANDLE;

      const bool write_header=(FileSize(handle)==0);
      FileSeek(handle,0,SEEK_END);
      if(write_header)
         FileWrite(handle,header);
      return handle;
     }

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

      const bool write_header=(FileSize(handle)==0);
      FileSeek(handle,0,SEEK_END);

      if(write_header)
         FileWrite(handle,"time","symbol","action","strategy","signal_class","confidence","quality","regime","session","liquidity","sl","tp","rr","reason");

      FileWrite(handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                m_config.symbol,
                EnumToString(decision.action),
                EnumToString(decision.strategy),
                EnumToString(decision.signal_class),
                DoubleToString(decision.confidence,2),
                DoubleToString(decision.quality,2),
                EnumToString(market.regime),
                EnumToString(market.session),
                DoubleToString(market.liquidity_score,2),
                DoubleToString(decision.preferred_stop_loss,5),
                DoubleToString(decision.preferred_take_profit,5),
                DoubleToString(decision.preferred_reward_risk,2),
                decision.reason);
      FileClose(handle);
      m_last_recorded_bar=bar_time;
     }

   void RecordTradePlan(const GBXTradePlan &plan,const bool accepted,const string reason)
     {
      const int handle=FileOpen("GoldBotX_Plans.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return;

      const bool write_header=(FileSize(handle)==0);
      FileSeek(handle,0,SEEK_END);
      if(write_header)
         FileWrite(handle,"time","symbol","accepted","action","signal_class","addition","volume","risk_percent","entry","sl","tp","rr","reason");

      FileWrite(handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                m_config.symbol,
                (accepted ? "true" : "false"),
                EnumToString(plan.action),
                EnumToString(plan.signal_class),
                (plan.is_addition ? "true" : "false"),
                DoubleToString(plan.volume,3),
                DoubleToString(plan.risk_percent,2),
                DoubleToString(plan.entry_price,5),
                DoubleToString(plan.stop_loss,5),
                DoubleToString(plan.take_profit,5),
                DoubleToString(plan.planned_reward_risk,2),
                reason);
      FileClose(handle);
     }

   void RecordExecution(const GBXTradePlan &plan,const string result)
     {
      const int handle=FileOpen("GoldBotX_Executions.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return;

      const bool write_header=(FileSize(handle)==0);
      FileSeek(handle,0,SEEK_END);
      if(write_header)
         FileWrite(handle,"time","symbol","action","signal_class","volume","risk_percent","entry","sl","tp","rr","result");

      FileWrite(handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                m_config.symbol,
                EnumToString(plan.action),
                EnumToString(plan.signal_class),
                DoubleToString(plan.volume,3),
                DoubleToString(plan.risk_percent,2),
                DoubleToString(plan.entry_price,5),
                DoubleToString(plan.stop_loss,5),
                DoubleToString(plan.take_profit,5),
                DoubleToString(plan.planned_reward_risk,2),
                result);
      FileClose(handle);
     }
  };

#endif
