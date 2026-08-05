#ifndef GBX_DATA_TYPES_MQH
#define GBX_DATA_TYPES_MQH

#define GBX_STANDARD_TIMEFRAME_COUNT 21

struct GBXQuoteData
  {
   datetime time;
   double   bid;
   double   ask;
   double   mid;
   double   spread_points;
   long     tick_volume;
  };

struct GBXBarData
  {
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   long     tick_volume;
   double   body;
   double   upper_wick;
   double   lower_wick;
   double   range;
  };

struct GBXTimeframeData
  {
   ENUM_TIMEFRAMES timeframe;
   GBXBarData      last_closed_bar;
   bool            available;
  };

struct GBXIndicatorData
  {
   double adx;
   double plus_di;
   double minus_di;
   double atr;
   double rsi;
   double ema_fast;
   double ema_slow;
   double sma;
   double fractal_high;
   double fractal_low;
  };

struct GBXDataSnapshot
  {
   GBXQuoteData     quote;
   GBXBarData       primary_bar;
   GBXBarData       context_bar;
   GBXTimeframeData timeframes[GBX_STANDARD_TIMEFRAME_COUNT];
   GBXIndicatorData indicators;
   bool             ready;
   datetime         updated_at;
  };

ENUM_TIMEFRAMES GBXStandardTimeframeAt(const int index)
  {
   switch(index)
     {
      case 0:  return PERIOD_M1;
      case 1:  return PERIOD_M2;
      case 2:  return PERIOD_M3;
      case 3:  return PERIOD_M4;
      case 4:  return PERIOD_M5;
      case 5:  return PERIOD_M6;
      case 6:  return PERIOD_M10;
      case 7:  return PERIOD_M12;
      case 8:  return PERIOD_M15;
      case 9:  return PERIOD_M20;
      case 10: return PERIOD_M30;
      case 11: return PERIOD_H1;
      case 12: return PERIOD_H2;
      case 13: return PERIOD_H3;
      case 14: return PERIOD_H4;
      case 15: return PERIOD_H6;
      case 16: return PERIOD_H8;
      case 17: return PERIOD_H12;
      case 18: return PERIOD_D1;
      case 19: return PERIOD_W1;
      case 20: return PERIOD_MN1;
     }
   return PERIOD_CURRENT;
  }

void GBXInitializeBarData(GBXBarData &bar)
  {
   bar.time        = 0;
   bar.open        = 0.0;
   bar.high        = 0.0;
   bar.low         = 0.0;
   bar.close       = 0.0;
   bar.tick_volume = 0;
   bar.body        = 0.0;
   bar.upper_wick  = 0.0;
   bar.lower_wick  = 0.0;
   bar.range       = 0.0;
  }

void GBXInitializeDataSnapshot(GBXDataSnapshot &snapshot)
  {
   snapshot.quote.time          = 0;
   snapshot.quote.bid           = 0.0;
   snapshot.quote.ask           = 0.0;
   snapshot.quote.mid           = 0.0;
   snapshot.quote.spread_points = 0.0;
   snapshot.quote.tick_volume   = 0;

   GBXInitializeBarData(snapshot.primary_bar);
   GBXInitializeBarData(snapshot.context_bar);

   for(int i=0;i<GBX_STANDARD_TIMEFRAME_COUNT;i++)
     {
      snapshot.timeframes[i].timeframe = GBXStandardTimeframeAt(i);
      GBXInitializeBarData(snapshot.timeframes[i].last_closed_bar);
      snapshot.timeframes[i].available = false;
     }

   snapshot.indicators.adx          = 0.0;
   snapshot.indicators.plus_di      = 0.0;
   snapshot.indicators.minus_di     = 0.0;
   snapshot.indicators.atr          = 0.0;
   snapshot.indicators.rsi          = 0.0;
   snapshot.indicators.ema_fast     = 0.0;
   snapshot.indicators.ema_slow     = 0.0;
   snapshot.indicators.sma          = 0.0;
   snapshot.indicators.fractal_high = 0.0;
   snapshot.indicators.fractal_low  = 0.0;
   snapshot.ready                   = false;
   snapshot.updated_at              = 0;
  }

#endif
