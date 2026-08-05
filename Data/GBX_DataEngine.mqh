#ifndef GBX_DATA_ENGINE_MQH
#define GBX_DATA_ENGINE_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"
#include "GBX_DataTypes.mqh"

class CGBXDataEngine
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_primary_timeframe;
   ENUM_TIMEFRAMES m_context_timeframe;
   double          m_point;
   int             m_adx_handle;
   int             m_atr_handle;
   int             m_rsi_handle;
   int             m_ema_fast_handle;
   int             m_ema_slow_handle;
   int             m_sma_handle;
   int             m_fractals_handle;
   GBXDataSnapshot m_snapshot;
   CGBXLogger      m_logger;

   bool ReadIndicatorValue(const int handle,const int buffer,double &value)
     {
      double values[];
      ArraySetAsSeries(values,true);

      if(handle == INVALID_HANDLE || CopyBuffer(handle,buffer,1,1,values) != 1)
         return false;

      value = values[0];
      return true;
     }

   void BuildBarData(const MqlRates &rate,GBXBarData &bar)
     {
      bar.time        = rate.time;
      bar.open        = rate.open;
      bar.high        = rate.high;
      bar.low         = rate.low;
      bar.close       = rate.close;
      bar.tick_volume = rate.tick_volume;
      bar.range       = rate.high-rate.low;
      bar.body        = MathAbs(rate.close-rate.open);
      bar.upper_wick  = rate.high-MathMax(rate.open,rate.close);
      bar.lower_wick  = MathMin(rate.open,rate.close)-rate.low;
     }

   bool ReadClosedBar(const ENUM_TIMEFRAMES timeframe,GBXBarData &bar)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates,true);

      if(CopyRates(m_symbol,timeframe,1,1,rates) != 1)
         return false;

      BuildBarData(rates[0],bar);
      return true;
     }

   bool RefreshBars(void)
     {
      return ReadClosedBar(m_primary_timeframe,m_snapshot.primary_bar) &&
             ReadClosedBar(m_context_timeframe,m_snapshot.context_bar);
     }

   void RefreshAllTimeframes(void)
     {
      for(int i=0;i<GBX_STANDARD_TIMEFRAME_COUNT;i++)
        {
         GBXTimeframeData &timeframe_data = m_snapshot.timeframes[i];
         timeframe_data.available = ReadClosedBar(timeframe_data.timeframe,
                                                   timeframe_data.last_closed_bar);
        }
     }

   bool RefreshIndicators(void)
     {
      return ReadIndicatorValue(m_adx_handle,0,m_snapshot.indicators.adx) &&
             ReadIndicatorValue(m_adx_handle,1,m_snapshot.indicators.plus_di) &&
             ReadIndicatorValue(m_adx_handle,2,m_snapshot.indicators.minus_di) &&
             ReadIndicatorValue(m_atr_handle,0,m_snapshot.indicators.atr) &&
             ReadIndicatorValue(m_rsi_handle,0,m_snapshot.indicators.rsi) &&
             ReadIndicatorValue(m_ema_fast_handle,0,m_snapshot.indicators.ema_fast) &&
             ReadIndicatorValue(m_ema_slow_handle,0,m_snapshot.indicators.ema_slow) &&
             ReadIndicatorValue(m_sma_handle,0,m_snapshot.indicators.sma) &&
             ReadIndicatorValue(m_fractals_handle,0,m_snapshot.indicators.fractal_high) &&
             ReadIndicatorValue(m_fractals_handle,1,m_snapshot.indicators.fractal_low);
     }

   void ReleaseHandle(int &handle)
     {
      if(handle != INVALID_HANDLE)
         IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }

public:
   CGBXDataEngine(void)
     {
      m_adx_handle       = INVALID_HANDLE;
      m_atr_handle       = INVALID_HANDLE;
      m_rsi_handle       = INVALID_HANDLE;
      m_ema_fast_handle  = INVALID_HANDLE;
      m_ema_slow_handle  = INVALID_HANDLE;
      m_sma_handle       = INVALID_HANDLE;
      m_fractals_handle  = INVALID_HANDLE;
      m_point            = 0.0;
      GBXInitializeDataSnapshot(m_snapshot);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_symbol            = config.symbol;
      m_primary_timeframe = config.primary_timeframe;
      m_context_timeframe = config.context_timeframe;
      m_point             = SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      m_logger.Configure(config.debug_logging);

      m_adx_handle      = iADX(m_symbol,m_primary_timeframe,14);
      m_atr_handle      = iATR(m_symbol,m_primary_timeframe,14);
      m_rsi_handle      = iRSI(m_symbol,m_primary_timeframe,14,PRICE_CLOSE);
      m_ema_fast_handle = iMA(m_symbol,m_primary_timeframe,20,0,MODE_EMA,PRICE_CLOSE);
      m_ema_slow_handle = iMA(m_symbol,m_primary_timeframe,50,0,MODE_EMA,PRICE_CLOSE);
      m_sma_handle      = iMA(m_symbol,m_primary_timeframe,20,0,MODE_SMA,PRICE_CLOSE);
      m_fractals_handle = iFractals(m_symbol,m_primary_timeframe);

      if(m_adx_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE ||
         m_rsi_handle == INVALID_HANDLE || m_ema_fast_handle == INVALID_HANDLE ||
         m_ema_slow_handle == INVALID_HANDLE || m_sma_handle == INVALID_HANDLE ||
         m_fractals_handle == INVALID_HANDLE)
        {
         m_logger.Error("Unable to create one or more market-data indicators.");
         Shutdown();
         return false;
        }

      if(!Refresh())
         m_logger.Warning("Market history is still loading; data collection will retry on the next event.");

      m_logger.Info("Data Engine initialized with full multi-timeframe coverage.");
      return true;
     }

   void Shutdown(void)
     {
      ReleaseHandle(m_adx_handle);
      ReleaseHandle(m_atr_handle);
      ReleaseHandle(m_rsi_handle);
      ReleaseHandle(m_ema_fast_handle);
      ReleaseHandle(m_ema_slow_handle);
      ReleaseHandle(m_sma_handle);
      ReleaseHandle(m_fractals_handle);
      m_snapshot.ready = false;
     }

   bool Refresh(void)
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol,tick))
         return false;

      m_snapshot.quote.time        = tick.time;
      m_snapshot.quote.bid         = tick.bid;
      m_snapshot.quote.ask         = tick.ask;
      m_snapshot.quote.mid         = (tick.bid+tick.ask)*0.5;
      m_snapshot.quote.tick_volume = (long)tick.volume;

      if(m_point > 0.0)
         m_snapshot.quote.spread_points = (tick.ask-tick.bid)/m_point;

      RefreshAllTimeframes();

      if(!RefreshBars() || !RefreshIndicators())
        {
         m_snapshot.ready = false;
         return false;
        }

      m_snapshot.updated_at = TimeCurrent();
      m_snapshot.ready      = true;
      return true;
     }

   bool IsReady(void) const
     {
      return m_snapshot.ready;
     }

   GBXDataSnapshot GetSnapshot(void) const
     {
      return m_snapshot;
     }
  };

#endif
