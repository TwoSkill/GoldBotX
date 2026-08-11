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
   string    m_last_reason;

   bool Reject(const string reason)
     {
      m_last_reason=reason;
      return false;
     }

   string RiskDayKey(void) const
     {
      return StringFormat("GBX_%s_%I64d_risk_day",m_config.symbol,m_config.magic_number);
     }

   string RiskEquityKey(void) const
     {
      return StringFormat("GBX_%s_%I64d_day_equity",m_config.symbol,m_config.magic_number);
     }

   void StoreDailyRiskState(void) const
     {
      GlobalVariableSet(RiskDayKey(),(double)m_risk_day);
      GlobalVariableSet(RiskEquityKey(),m_day_start_equity);
     }

   bool LoadDailyRiskState(const datetime today)
     {
      if(!GlobalVariableCheck(RiskDayKey()) || !GlobalVariableCheck(RiskEquityKey()))
         return false;

      const datetime saved_day=(datetime)GlobalVariableGet(RiskDayKey());
      const double saved_equity=GlobalVariableGet(RiskEquityKey());
      if(saved_day!=today || saved_equity<=0.0)
         return false;

      m_risk_day=saved_day;
      m_day_start_equity=saved_equity;
      return true;
     }

   bool DailyLossLimitReached(void)
     {
      const datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
      if(today!=m_risk_day)
        {
         m_risk_day=today;
         m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
         StoreDailyRiskState();
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

   bool HasOppositePosition(const ENUM_GBX_ACTION action) const
     {
      for(int i=0;i<PositionsTotal();i++)
        {
         if(PositionGetSymbol(i) != m_config.symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_config.magic_number)
            continue;

         const long position_type=PositionGetInteger(POSITION_TYPE);
         if(action==GBX_ACTION_BUY && position_type==POSITION_TYPE_SELL)
            return true;
         if(action==GBX_ACTION_SELL && position_type==POSITION_TYPE_BUY)
            return true;
        }
      return false;
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
      m_last_reason="";
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      const datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
      if(!LoadDailyRiskState(today))
        {
         m_risk_day=today;
         m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
         StoreDailyRiskState();
        }
      m_last_reason="";
      return true;
     }

   bool BuildTradePlan(const GBXDecision &decision,
                       const GBXMarketState &market,
                       const GBXDataSnapshot &data,
                       GBXTradePlan &plan)
     {
      GBXInitializeTradePlan(plan);
      m_last_reason="";

      if(decision.action!=GBX_ACTION_BUY && decision.action!=GBX_ACTION_SELL)
         return Reject("Risk plan skipped: decision is not BUY or SELL.");
      if(DailyLossLimitReached())
         return Reject("Risk plan rejected: daily loss limit reached.");

      const int open_positions=OpenPositionsCount();
      if(open_positions>=m_config.max_open_positions)
         return Reject("Risk plan rejected: maximum open positions reached.");
      if(!m_config.allow_hedging && HasOppositePosition(decision.action))
         return Reject("Risk plan rejected: opposite position exists and hedging is disabled.");
      if(open_positions>0 && !m_config.allow_pyramiding)
         return Reject("Risk plan rejected: pyramiding is disabled.");
      if(open_positions>0 && !market.can_add_position)
         return Reject("Risk plan rejected: market quality does not allow adding another position.");

      double risk_percent=MathMin(m_config.max_risk_per_trade_percent,
                                  m_config.risk_per_trade_percent*market.risk_multiplier*ProfileMultiplier());
      const double remaining_budget=m_config.max_aggregate_risk_percent-
                                   open_positions*m_config.max_risk_per_trade_percent;
      risk_percent=MathMin(risk_percent,remaining_budget);
      if(risk_percent<=0.0)
         return Reject("Risk plan rejected: aggregate risk budget is exhausted.");

      plan.action=decision.action;
      plan.is_addition=open_positions>0;
      plan.risk_percent=risk_percent;
      plan.entry_price=(decision.action==GBX_ACTION_BUY ? data.quote.ask : data.quote.bid);

      const bool use_strategy_targets=(decision.has_price_targets &&
                                       decision.preferred_stop_loss>0.0 &&
                                       decision.preferred_take_profit>0.0);

      if(use_strategy_targets)
        {
         plan.stop_loss=decision.preferred_stop_loss;
         plan.take_profit=decision.preferred_take_profit;

         if(decision.action==GBX_ACTION_BUY && (plan.stop_loss>=plan.entry_price || plan.take_profit<=plan.entry_price))
            return Reject("Risk plan rejected: strategy BUY targets are not valid around current entry.");
         if(decision.action==GBX_ACTION_SELL && (plan.stop_loss<=plan.entry_price || plan.take_profit>=plan.entry_price))
            return Reject("Risk plan rejected: strategy SELL targets are not valid around current entry.");

         const double risk_distance=MathAbs(plan.entry_price-plan.stop_loss);
         const double reward_distance=MathAbs(plan.take_profit-plan.entry_price);
         if(risk_distance<=0.0 || reward_distance<=0.0)
            return Reject("Risk plan rejected: strategy target distances are invalid.");

         plan.planned_reward_risk=reward_distance/risk_distance;
         if(plan.planned_reward_risk<1.10)
            return Reject("Risk plan rejected: strategy reward/risk is too low.");
        }
      else
        {
         if(data.indicators.atr<=0.0)
            return Reject("Risk plan rejected: ATR is not available for dynamic stop calculation.");

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
        }

      plan.volume=CalculateVolume(plan.entry_price,plan.stop_loss,plan.risk_percent);
      if(plan.volume<=0.0)
         return Reject("Risk plan rejected: calculated volume is below broker minimum for the configured risk.");

      plan.rationale=decision.reason;
      m_last_reason="Risk plan accepted.";
      return true;
     }

   string LastReason(void) const
     {
      return m_last_reason;
     }
  };

#endif
