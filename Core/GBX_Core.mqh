#ifndef GBX_CORE_MQH
#define GBX_CORE_MQH

#include "GBX_Types.mqh"
#include "GBX_Constants.mqh"
#include "GBX_Logger.mqh"

class CGBXCore
  {
private:
   GBXConfig        m_config;
   GBXRuntimeState  m_runtime;
   GBXMarketState   m_market;
   CGBXLogger       m_logger;
   double           m_point;
   double           m_tick_size;
   int              m_digits;

   bool ValidateConfiguration(void)
     {
      if(StringLen(m_config.symbol) == 0)
        {
         m_logger.Error("The trading symbol is empty.");
         return false;
        }

      if(m_config.risk_per_trade_percent < GBX_MIN_RISK_PERCENT ||
         m_config.risk_per_trade_percent > GBX_MAX_RISK_PERCENT)
        {
         m_logger.Error("Risk per trade is outside the permitted range.");
         return false;
        }

      if(m_config.max_open_positions < 1)
        {
         m_logger.Error("At least one open position must be permitted.");
         return false;
        }

      return true;
     }

   bool RefreshQuote(void)
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_config.symbol,tick))
        {
         m_logger.Warning("Unable to read the current quote.");
         return false;
        }

      m_runtime.bid          = tick.bid;
      m_runtime.ask          = tick.ask;
      m_runtime.mid          = (tick.bid + tick.ask) * 0.5;
      m_runtime.last_tick_at = tick.time;
      m_runtime.tick_count++;

      if(m_point > 0.0)
         m_runtime.spread_points = (tick.ask - tick.bid) / m_point;
      else
         m_runtime.spread_points = 0.0;

      return true;
     }

public:
   CGBXCore(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeRuntimeState(m_runtime);
      GBXInitializeMarketState(m_market);
      m_point     = 0.0;
      m_tick_size = 0.0;
      m_digits    = 0;
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(m_config.debug_logging);

      if(!ValidateConfiguration())
         return false;

      if(!SymbolSelect(m_config.symbol,true))
        {
         m_logger.Error("Unable to select the configured symbol.");
         return false;
        }

      m_point     = SymbolInfoDouble(m_config.symbol,SYMBOL_POINT);
      m_tick_size = SymbolInfoDouble(m_config.symbol,SYMBOL_TRADE_TICK_SIZE);
      m_digits    = (int)SymbolInfoInteger(m_config.symbol,SYMBOL_DIGITS);

      if(m_point <= 0.0 || m_tick_size <= 0.0)
        {
         m_logger.Error("The symbol does not expose valid price properties.");
         return false;
        }

      if(!RefreshQuote())
         return false;

      m_runtime.initialized = true;
      m_runtime.started_at  = TimeCurrent();

      m_logger.Info(StringFormat("Core initialized for %s (%s).",
                                 m_config.symbol,
                                 EnumToString(m_config.primary_timeframe)));
      m_logger.Info("Trading is disabled until a decision and risk pipeline is available.");
      return true;
     }

   void Shutdown(const int reason)
     {
      if(!m_runtime.initialized)
         return;

      m_logger.Info(StringFormat("Core shutdown. Reason=%d, ticks=%I64u.",
                                 reason,m_runtime.tick_count));
      m_runtime.initialized = false;
     }

   void OnTick(void)
     {
      if(!m_runtime.initialized)
         return;

      RefreshQuote();
     }

   void OnTimer(void)
     {
      // Reserved for scheduled market-state refresh and reporting.
     }

   bool IsInitialized(void) const
     {
      return m_runtime.initialized;
     }

   const GBXRuntimeState GetRuntimeState(void) const
     {
      return m_runtime;
     }

   const GBXMarketState GetMarketState(void) const
     {
      return m_market;
     }

   double Point(void) const
     {
      return m_point;
     }

   int Digits(void) const
     {
      return m_digits;
     }
  };

#endif
