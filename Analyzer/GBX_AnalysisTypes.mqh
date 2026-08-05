#ifndef GBX_ANALYSIS_TYPES_MQH
#define GBX_ANALYSIS_TYPES_MQH

#include "../Core/GBX_Enums.mqh"

struct GBXTrendAnalysis
  {
   ENUM_GBX_DIRECTION direction;
   double             score;
   int                bullish_timeframes;
   int                bearish_timeframes;
  };

struct GBXStructureAnalysis
  {
   ENUM_GBX_DIRECTION direction;
   double             score;
   bool               higher_highs;
   bool               higher_lows;
   bool               lower_highs;
   bool               lower_lows;
  };

struct GBXVolatilityAnalysis
  {
   double score;
   bool   compressed;
   bool   elevated;
  };

struct GBXAnalysisSnapshot
  {
   GBXTrendAnalysis      trend;
   GBXStructureAnalysis  structure;
   GBXVolatilityAnalysis volatility;
   bool                  ready;
   datetime              updated_at;
  };

void GBXInitializeAnalysisSnapshot(GBXAnalysisSnapshot &analysis)
  {
   analysis.trend.direction              = GBX_DIRECTION_NEUTRAL;
   analysis.trend.score                  = 0.0;
   analysis.trend.bullish_timeframes     = 0;
   analysis.trend.bearish_timeframes     = 0;
   analysis.structure.direction          = GBX_DIRECTION_NEUTRAL;
   analysis.structure.score              = 0.0;
   analysis.structure.higher_highs       = false;
   analysis.structure.higher_lows        = false;
   analysis.structure.lower_highs        = false;
   analysis.structure.lower_lows         = false;
   analysis.volatility.score             = 0.0;
   analysis.volatility.compressed        = false;
   analysis.volatility.elevated          = false;
   analysis.ready                        = false;
   analysis.updated_at                   = 0;
  }

#endif
