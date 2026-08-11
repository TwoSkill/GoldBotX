#ifndef GBX_FEATURE_ENGINE_MQH
#define GBX_FEATURE_ENGINE_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"
#include "../Data/GBX_DataTypes.mqh"
#include "GBX_FeatureTypes.mqh"

class CGBXFeatureEngine
  {
private:
   GBXConfig          m_config;
   GBXFeatureSnapshot m_features;
   CGBXLogger         m_logger;

   double ClampScore(const double value) const
     {
      return MathMax(0.0,MathMin(100.0,value));
     }

   ENUM_GBX_DIRECTION ResolveDirection(const GBXDataSnapshot &data) const
     {
      if(data.indicators.ema_fast > data.indicators.ema_slow &&
         data.primary_bar.close > data.indicators.ema_fast)
         return GBX_DIRECTION_BULLISH;

      if(data.indicators.ema_fast < data.indicators.ema_slow &&
         data.primary_bar.close < data.indicators.ema_fast)
         return GBX_DIRECTION_BEARISH;

      return GBX_DIRECTION_NEUTRAL;
     }

   ENUM_GBX_DIRECTION CandleDirection(const GBXBarData &bar) const
     {
      if(bar.range<=0.0 || bar.body/bar.range<0.10)
         return GBX_DIRECTION_NEUTRAL;
      if(bar.close>bar.open)
         return GBX_DIRECTION_BULLISH;
      if(bar.close<bar.open)
         return GBX_DIRECTION_BEARISH;
      return GBX_DIRECTION_NEUTRAL;
     }

   double CalculateTrendStrength(const GBXDataSnapshot &data) const
     {
      if(data.indicators.atr <= 0.0)
         return 0.0;

      const double ema_distance = MathAbs(data.indicators.ema_fast-data.indicators.ema_slow);
      const double distance_score = MathMin(30.0,(ema_distance/data.indicators.atr)*30.0);
      const double direction_score = MathMin(30.0,MathAbs(data.indicators.plus_di-data.indicators.minus_di)*1.5);
      return ClampScore(data.indicators.adx*0.8+distance_score+direction_score);
     }

   double CalculateMomentum(const GBXDataSnapshot &data,const ENUM_GBX_DIRECTION direction) const
     {
      double score = 50.0;

      if(direction == GBX_DIRECTION_BULLISH)
         score += (data.indicators.rsi-50.0)*1.5;
      else if(direction == GBX_DIRECTION_BEARISH)
         score += (50.0-data.indicators.rsi)*1.5;

      if(data.primary_bar.close > data.primary_bar.open && direction == GBX_DIRECTION_BULLISH)
         score += 10.0;
      if(data.primary_bar.close < data.primary_bar.open && direction == GBX_DIRECTION_BEARISH)
         score += 10.0;

      return ClampScore(score);
     }

public:
   CGBXFeatureEngine(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeFeatureSnapshot(m_features);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(config.debug_logging);
      GBXInitializeFeatureSnapshot(m_features);
      m_logger.Info("Feature Engine initialized.");
      return true;
     }

   bool Refresh(const GBXDataSnapshot &data)
     {
      if(!data.ready)
        {
         m_features.ready = false;
         return false;
        }

      m_features.directional_bias = ResolveDirection(data);
      m_features.ema_aligned =
         (m_features.directional_bias == GBX_DIRECTION_BULLISH && data.indicators.plus_di > data.indicators.minus_di) ||
         (m_features.directional_bias == GBX_DIRECTION_BEARISH && data.indicators.minus_di > data.indicators.plus_di);

      const ENUM_GBX_DIRECTION primary_direction=CandleDirection(data.primary_bar);
      const ENUM_GBX_DIRECTION context_direction=CandleDirection(data.context_bar);
      m_features.primary_context_aligned =
         primary_direction!=GBX_DIRECTION_NEUTRAL &&
         primary_direction==context_direction;

      m_features.spread_acceptable = data.quote.spread_points <= m_config.max_spread_points;
      if(m_config.max_spread_points > 0)
         m_features.spread_quality = ClampScore(100.0-(data.quote.spread_points/m_config.max_spread_points)*100.0);
      else
         m_features.spread_quality = 0.0;

      if(data.primary_bar.range > 0.0)
         m_features.candle_quality = ClampScore((data.primary_bar.body/data.primary_bar.range)*100.0);
      else
         m_features.candle_quality = 0.0;

      m_features.trend_strength = CalculateTrendStrength(data);
      m_features.momentum_score = CalculateMomentum(data,m_features.directional_bias);

      if(data.indicators.atr > 0.0)
         m_features.volatility_score = ClampScore((data.primary_bar.range/data.indicators.atr)*50.0);
      else
         m_features.volatility_score = 0.0;

      m_features.preliminary_quality = ClampScore(
         m_features.trend_strength*0.35 +
         m_features.momentum_score*0.25 +
         m_features.candle_quality*0.20 +
         m_features.spread_quality*0.20);

      m_features.updated_at = TimeCurrent();
      m_features.ready      = true;
      return true;
     }

   GBXFeatureSnapshot GetSnapshot(void) const
     {
      return m_features;
     }

   bool IsReady(void) const
     {
      return m_features.ready;
     }
  };

#endif
