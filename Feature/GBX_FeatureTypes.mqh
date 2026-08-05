#ifndef GBX_FEATURE_TYPES_MQH
#define GBX_FEATURE_TYPES_MQH

#include "../Core/GBX_Enums.mqh"

struct GBXFeatureSnapshot
  {
   ENUM_GBX_DIRECTION directional_bias;
   bool               ema_aligned;
   bool               primary_context_aligned;
   bool               spread_acceptable;
   double             trend_strength;
   double             momentum_score;
   double             volatility_score;
   double             candle_quality;
   double             spread_quality;
   double             preliminary_quality;
   datetime           updated_at;
   bool               ready;
  };

void GBXInitializeFeatureSnapshot(GBXFeatureSnapshot &features)
  {
   features.directional_bias       = GBX_DIRECTION_NEUTRAL;
   features.ema_aligned            = false;
   features.primary_context_aligned = false;
   features.spread_acceptable      = false;
   features.trend_strength         = 0.0;
   features.momentum_score         = 0.0;
   features.volatility_score       = 0.0;
   features.candle_quality         = 0.0;
   features.spread_quality         = 0.0;
   features.preliminary_quality    = 0.0;
   features.updated_at             = 0;
   features.ready                  = false;
  }

#endif
