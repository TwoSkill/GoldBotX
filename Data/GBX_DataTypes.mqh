#ifndef GBX_DATA_TYPES_MQH
#define GBX_DATA_TYPES_MQH

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
   GBXIndicatorData indicators;
   bool             ready;
   datetime         updated_at;
  };

void GBXInitializeDataSnapshot(GBXDataSnapshot &snapshot)
  {
   snapshot.quote.time          = 0;
   snapshot.quote.bid           = 0.0;
   snapshot.quote.ask           = 0.0;
   snapshot.quote.mid           = 0.0;
   snapshot.quote.spread_points = 0.0;
   snapshot.quote.tick_volume   = 0;

   snapshot.primary_bar.time        = 0;
   snapshot.primary_bar.open        = 0.0;
   snapshot.primary_bar.high        = 0.0;
   snapshot.primary_bar.low         = 0.0;
   snapshot.primary_bar.close       = 0.0;
   snapshot.primary_bar.tick_volume = 0;
   snapshot.primary_bar.body        = 0.0;
   snapshot.primary_bar.upper_wick  = 0.0;
   snapshot.primary_bar.lower_wick  = 0.0;
   snapshot.primary_bar.range       = 0.0;

   snapshot.context_bar = snapshot.primary_bar;

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
   snapshot.ready                    = false;
   snapshot.updated_at               = 0;
  }

#endif
