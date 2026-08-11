#ifndef GBX_RANGE_STRATEGY_MQH
#define GBX_RANGE_STRATEGY_MQH

#include "../Core/GBX_Types.mqh"
#include "../Data/GBX_DataTypes.mqh"

class CGBXRangeStrategy
  {
private:
   GBXConfig m_config;
   string    m_last_reason;

   double NormalizePrice(const double price) const
     {
      const int digits=(int)SymbolInfoInteger(m_config.symbol,SYMBOL_DIGITS);
      return NormalizeDouble(price,digits);
     }

   void SetWait(GBXDecision &decision,
                const GBXMarketState &market,
                const GBXStrategySelection &selection,
                const string reason)
     {
      GBXInitializeDecision(decision);
      decision.action     = GBX_ACTION_WAIT;
      decision.strategy   = selection.strategy;
      decision.confidence = market.confidence;
      decision.quality    = market.quality;
      decision.reason     = reason;
      m_last_reason       = reason;
     }

   bool FindRange(double &support,double &resistance)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates,true);

      const int requested=24;
      const int copied=CopyRates(m_config.symbol,m_config.primary_timeframe,1,requested,rates);
      if(copied<12)
        {
         m_last_reason="WAIT: not enough closed candles to validate the clean range.";
         return false;
        }

      support=rates[0].low;
      resistance=rates[0].high;
      for(int i=1;i<copied;i++)
        {
         support=MathMin(support,rates[i].low);
         resistance=MathMax(resistance,rates[i].high);
        }

      if(resistance<=support)
        {
         m_last_reason="WAIT: invalid range boundaries.";
         return false;
        }

      return true;
     }

   bool RewardRiskOk(const ENUM_GBX_ACTION action,
                     const double entry,
                     const double stop_loss,
                     const double take_profit,
                     double &reward_risk)
     {
      const double risk=MathAbs(entry-stop_loss);
      const double reward=MathAbs(take_profit-entry);
      if(risk<=0.0 || reward<=0.0)
        {
         reward_risk=0.0;
         return false;
        }

      reward_risk=reward/risk;
      if(action==GBX_ACTION_BUY && (stop_loss>=entry || take_profit<=entry))
         return false;
      if(action==GBX_ACTION_SELL && (stop_loss<=entry || take_profit>=entry))
         return false;

      return reward_risk>=1.15;
     }

public:
   CGBXRangeStrategy(void)
     {
      GBXInitializeConfig(m_config);
      m_last_reason="";
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config=config;
      m_last_reason="";
      return true;
     }

   bool Refresh(const GBXDataSnapshot &data,
                const GBXMarketState &market,
                const GBXStrategySelection &selection,
                GBXDecision &decision)
     {
      if(selection.strategy!=GBX_STRATEGY_RANGE_SCALPING)
         return true;

      if(!market.is_tradeable)
        {
         SetWait(decision,market,selection,"WAIT: range strategy blocked because market is not tradeable.");
         return true;
        }

      if(data.indicators.atr<=0.0 || data.quote.ask<=0.0 || data.quote.bid<=0.0)
        {
         SetWait(decision,market,selection,"WAIT: range strategy needs valid ATR and quote data.");
         return true;
        }

      double support=0.0;
      double resistance=0.0;
      if(!FindRange(support,resistance))
        {
         SetWait(decision,market,selection,m_last_reason);
         return true;
        }

      const double atr=data.indicators.atr;
      const double width=resistance-support;
      if(width<atr*1.60)
        {
         SetWait(decision,market,selection,"WAIT: clean range exists but is too narrow after spread and stop distance.");
         return true;
        }

      const double edge=MathMax(atr*0.45,width*0.18);
      const bool near_support=(data.primary_bar.close<=support+edge);
      const bool near_resistance=(data.primary_bar.close>=resistance-edge);
      const double body=MathMax(data.primary_bar.body,_Point);
      const bool bullish_rejection=(data.primary_bar.close>=data.primary_bar.open || data.primary_bar.lower_wick>=body*1.25);
      const bool bearish_rejection=(data.primary_bar.close<=data.primary_bar.open || data.primary_bar.upper_wick>=body*1.25);

      ENUM_GBX_ACTION action=GBX_ACTION_WAIT;
      double entry=0.0;
      double stop_loss=0.0;
      double take_profit=0.0;
      string side="";

      if(near_support && bullish_rejection)
        {
         action=GBX_ACTION_BUY;
         entry=data.quote.ask;
         stop_loss=MathMin(data.primary_bar.low,support)-atr*0.35;
         take_profit=resistance-edge*0.35;
         side="BUY";
        }
      else if(near_resistance && bearish_rejection)
        {
         action=GBX_ACTION_SELL;
         entry=data.quote.bid;
         stop_loss=MathMax(data.primary_bar.high,resistance)+atr*0.35;
         take_profit=support+edge*0.35;
         side="SELL";
        }
      else
        {
         SetWait(decision,market,selection,
                 StringFormat("WAIT: clean range found, but price is not at a validated edge. support=%.5f resistance=%.5f close=%.5f",
                              support,resistance,data.primary_bar.close));
         return true;
        }

      double reward_risk=0.0;
      if(!RewardRiskOk(action,entry,stop_loss,take_profit,reward_risk))
        {
         SetWait(decision,market,selection,
                 StringFormat("WAIT: range %s rejected because reward/risk is too weak. entry=%.5f sl=%.5f tp=%.5f rr=%.2f",
                              side,entry,stop_loss,take_profit,reward_risk));
         return true;
        }

      GBXInitializeDecision(decision);
      decision.action                = action;
      decision.strategy              = selection.strategy;
      decision.confidence            = MathMin(95.0,MathMax(market.confidence,selection.score)+3.0);
      decision.quality               = MathMin(95.0,MathMax(market.quality,selection.score)+3.0);
      decision.reason                = StringFormat("%s: clean range edge validated. support=%.5f resistance=%.5f rr=%.2f",
                                                    side,support,resistance,reward_risk);
      decision.has_price_targets     = true;
      decision.preferred_stop_loss   = NormalizePrice(stop_loss);
      decision.preferred_take_profit = NormalizePrice(take_profit);
      decision.preferred_reward_risk = reward_risk;
      m_last_reason                  = decision.reason;
      return true;
     }

   string LastReason(void) const
     {
      return m_last_reason;
     }
  };

#endif
