#ifndef GBX_RISK_MANAGER_MQH
#define GBX_RISK_MANAGER_MQH

#include "../Core/GBX_Types.mqh"
#include "../Data/GBX_DataTypes.mqh"

class CGBXRiskManager
  {
private:
   GBXConfig m_config;
   datetime  m_risk_day;
   double    m_day_start_equity;

   bool DailyLossLimitReached(void)
     {
      const datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
      if(today!=m_risk_day)
        {
         m_risk_day=today;
         m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
        }

      if(m_day_start_equity<=0.0)
         return true;

      const double loss_percent=(m_day_start_equity-AccountInfoDouble(ACCOUNT_EQUITY))/
                                m_day_start_equity*100.0;
      return loss_percent>=m_config.daily_loss_limit_percent;
     }

   double ProfileMultiplier(void) const
     {
      if(m_config.risk_profile==GBX_RISK_CONSERVATIVE)
         return 0.70;
      if(m_config.risk_profile==GBX_RISK_AGGRESSIVE)
         return 1.20;
      return 1.00;
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

   int OpenPositionsCount(void) const
     {
      int count=0;
      for(int i=0;i<PositionsTotal();i++)
        {
         if(PositionGetSymbol(i) != m_config.symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) == m_config.magic_number)
            count++;
        }
      return count;
     }

   double CalculateVolume(const double entry,const double stop,const double risk_percent) const
     {
      const double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
      const double risk_money = equity*risk_percent/100.0;
      const double tick_size  = SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_SIZE);
      const double tick_value = SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_VALUE);
      const double step       = SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_STEP);
      const double minimum    = SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_MIN);
      const double maximum    = SymbolInfoDouble(m_config.symbol,SYMBOL_VOLUME_MAX);
      const double distance   = MathAbs(entry-stop);

      if(risk_money<=0.0 || tick_size<=0.0 || tick_value<=0.0 || step<=0.0 || distance<=0.0)
         return 0.0;

      double volume=risk_money/((distance/tick_size)*tick_value);
      volume=MathFloor(volume/step)*step;

      // Never increase volume to the broker minimum: that would exceed the risk budget.
      if(volume<minimum)
         return 0.0;

      volume=MathMin(maximum,volume);
      return NormalizeDouble(volume,VolumeDigits(step));
     }

public:
   CGBXRiskManager(void)
     {
      GBXInitializeConfig(m_config);
      m_risk_day=0;
      m_day_start_equity=0.0;
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      m_risk_day=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
      m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
      return true;
     }

   bool BuildTradePlan(const GBXDecision &decision,
                       const GBXMarketState &market,
                       const GBXDataSnapshot &data,
                       GBXTradePlan &plan)
     {
      GBXInitializeTradePlan(plan);

      if(decision.action!=GBX_ACTION_BUY && decision.action!=GBX_ACTION_SELL)
         return false;
      if(DailyLossLimitReached())
         return false;

      const int open_positions=OpenPositionsCount();
      if(open_positions>=m_config.max_open_positions)
         return false;
      if(open_positions>0 && (!m_config.allow_pyramiding || !market.can_add_position))
         return false;

      double risk_percent=MathMin(m_config.max_risk_per_trade_percent,
                                  m_config.risk_per_trade_percent*market.risk_multiplier*ProfileMultiplier());
      const double remaining_budget=m_config.max_aggregate_risk_percent-
                                   open_positions*m_config.max_risk_per_trade_percent;
      risk_percent=MathMin(risk_percent,remaining_budget);
      if(risk_percent<=0.0 || data.indicators.atr<=0.0)
         return false;

      plan.action=decision.action;
      plan.is_addition=open_positions>0;
      plan.risk_percent=risk_percent;
      plan.entry_price=(decision.action==GBX_ACTION_BUY ? data.quote.ask : data.quote.bid);

      const double stop_distance=MathMax(data.indicators.atr*0.75,data.primary_bar.range*1.10);
      if(decision.action==GBX_ACTION_BUY)
        {
         plan.stop_loss=MathMin(data.primary_bar.low,data.primary_bar.close)-stop_distance;
         plan.take_profit=plan.entry_price+(plan.entry_price-plan.stop_loss)*2.20;
        }
      else
        {
         plan.stop_loss=MathMax(data.primary_bar.high,data.primary_bar.close)+stop_distance;
         plan.take_profit=plan.entry_price-(plan.stop_loss-plan.entry_price)*2.20;
        }

      plan.planned_reward_risk=2.20;
      plan.volume=CalculateVolume(plan.entry_price,plan.stop_loss,plan.risk_percent);
      plan.rationale=decision.reason;
      return plan.volume>0.0;
     }
  };

#endif
