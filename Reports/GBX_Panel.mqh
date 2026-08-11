#ifndef GBX_PANEL_MQH
#define GBX_PANEL_MQH

#include "../Core/GBX_Types.mqh"
#include "../Data/GBX_DataTypes.mqh"

class CGBXPanel
  {
private:
   string m_name;

   int OpenPositions(const GBXConfig &config) const
     {
      int count=0;
      for(int i=0;i<PositionsTotal();i++)
        {
         if(PositionGetSymbol(i)==config.symbol &&
            PositionGetInteger(POSITION_MAGIC)==config.magic_number)
            count++;
        }
      return count;
     }

public:
   CGBXPanel(void)
     {
      m_name="GoldBotX_StatusPanel";
     }

   void Initialize(void)
     {
      if(ObjectFind(0,m_name)<0)
        {
         ObjectCreate(0,m_name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,m_name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,m_name,OBJPROP_XDISTANCE,12);
         ObjectSetInteger(0,m_name,OBJPROP_YDISTANCE,18);
         ObjectSetInteger(0,m_name,OBJPROP_FONTSIZE,10);
         ObjectSetString(0,m_name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(0,m_name,OBJPROP_SELECTABLE,false);
        }
     }

   void Update(const GBXConfig &config,
               const GBXDataSnapshot &data,
               const GBXMarketState &market,
               const GBXDecision &decision,
               const string last_execution)
     {
      Initialize();

      const string trading=(config.trading_enabled ? "ENABLED" : "DISABLED");
      const string dry_run=(config.dry_run ? "ON" : "OFF");
      string targets="";
      if(decision.has_price_targets)
         targets=StringFormat("\nTargets: SL %.5f   TP %.5f   RR %.2f",
                              decision.preferred_stop_loss,
                              decision.preferred_take_profit,
                              decision.preferred_reward_risk);

      const string text=StringFormat(
         "GoldBot X\nTrading: %s   Dry Run: %s\nSymbol: %s   TF: %s\nSpread: %.1f\nSession: %s\nRegime: %s\nDirection: %s\nQuality: %.1f   Confidence: %.1f\nRisk multiplier: %.2f   ATR: %.5f\nOpen positions: %d/%d\nSignal: %s%s\nReason: %s\nExecution: %s",
         trading,dry_run,config.symbol,EnumToString(config.primary_timeframe),
         data.quote.spread_points,EnumToString(market.session),EnumToString(market.regime),
         EnumToString(market.direction),market.quality,market.confidence,
         market.risk_multiplier,data.indicators.atr,
         OpenPositions(config),config.max_open_positions,
         EnumToString(decision.action),targets,decision.reason,last_execution);

      ObjectSetString(0,m_name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,m_name,OBJPROP_COLOR,(config.trading_enabled ? clrLime : clrOrange));
     }

   void Remove(void)
     {
      ObjectDelete(0,m_name);
     }
  };

#endif
