#ifndef GBX_ANALYZER_ENGINE_MQH
#define GBX_ANALYZER_ENGINE_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"
#include "../Data/GBX_DataTypes.mqh"
#include "../Feature/GBX_FeatureTypes.mqh"
#include "GBX_AnalysisTypes.mqh"

class CGBXAnalyzerEngine
  {
private:
   GBXConfig           m_config;
   GBXAnalysisSnapshot m_analysis;
   CGBXLogger          m_logger;

   double ClampScore(const double value) const
     {
      return MathMax(0.0,MathMin(100.0,value));
     }

   bool FindTimeframeData(const GBXDataSnapshot &data,
                          const ENUM_TIMEFRAMES timeframe,
                          GBXTimeframeData &result) const
     {
      for(int i=0;i<GBX_STANDARD_TIMEFRAME_COUNT;i++)
        {
         if(data.timeframes[i].timeframe == timeframe)
           {
            result = data.timeframes[i];
            return result.available;
           }
        }
      return false;
     }

   void AnalyzeTrend(const GBXDataSnapshot &data,
                     const GBXFeatureSnapshot &features,
                     GBXTrendAnalysis &trend) const
     {
      trend.direction          = features.directional_bias;
      trend.score              = features.trend_strength;
      trend.bullish_timeframes = 0;
      trend.bearish_timeframes = 0;

      int available_timeframes = 0;
      for(int i=0;i<GBX_STANDARD_TIMEFRAME_COUNT;i++)
        {
         if(!data.timeframes[i].available)
            continue;

         available_timeframes++;
         if(data.timeframes[i].last_closed_bar.close > data.timeframes[i].previous_closed_bar.close)
            trend.bullish_timeframes++;
         else if(data.timeframes[i].last_closed_bar.close < data.timeframes[i].previous_closed_bar.close)
            trend.bearish_timeframes++;
        }

      if(trend.bullish_timeframes > trend.bearish_timeframes)
         trend.direction = GBX_DIRECTION_BULLISH;
      else if(trend.bearish_timeframes > trend.bullish_timeframes)
         trend.direction = GBX_DIRECTION_BEARISH;

      if(available_timeframes > 0)
        {
         const int dominant_count = MathMax(trend.bullish_timeframes,trend.bearish_timeframes);
         trend.score = ClampScore(trend.score*0.65+((double)dominant_count/available_timeframes)*35.0);
        }
     }

   void AnalyzeStructure(const GBXDataSnapshot &data,GBXStructureAnalysis &structure) const
     {
      GBXTimeframeData primary;
      if(!FindTimeframeData(data,m_config.primary_timeframe,primary))
        {
         structure.direction = GBX_DIRECTION_NEUTRAL;
         structure.score     = 0.0;
         return;
        }

      structure.higher_highs = primary.last_closed_bar.high > primary.previous_closed_bar.high &&
                               primary.previous_closed_bar.high >= primary.older_closed_bar.high;
      structure.higher_lows  = primary.last_closed_bar.low > primary.previous_closed_bar.low &&
                               primary.previous_closed_bar.low >= primary.older_closed_bar.low;
      structure.lower_highs  = primary.last_closed_bar.high < primary.previous_closed_bar.high &&
                               primary.previous_closed_bar.high <= primary.older_closed_bar.high;
      structure.lower_lows   = primary.last_closed_bar.low < primary.previous_closed_bar.low &&
                               primary.previous_closed_bar.low <= primary.older_closed_bar.low;

      structure.direction = GBX_DIRECTION_NEUTRAL;
      structure.score     = 30.0;

      if(structure.higher_highs && structure.higher_lows)
        {
         structure.direction = GBX_DIRECTION_BULLISH;
         structure.score     = 80.0;
        }
      else if(structure.lower_highs && structure.lower_lows)
        {
         structure.direction = GBX_DIRECTION_BEARISH;
         structure.score     = 80.0;
        }
     }

   void AnalyzeVolatility(const GBXFeatureSnapshot &features,GBXVolatilityAnalysis &volatility) const
     {
      volatility.score      = features.volatility_score;
      volatility.compressed = volatility.score < 25.0;
      volatility.elevated   = volatility.score > 80.0;
     }

public:
   CGBXAnalyzerEngine(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeAnalysisSnapshot(m_analysis);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(config.debug_logging);
      GBXInitializeAnalysisSnapshot(m_analysis);
      m_logger.Info("Analyzer Engine initialized.");
      return true;
     }

   bool Refresh(const GBXDataSnapshot &data,const GBXFeatureSnapshot &features)
     {
      if(!data.ready || !features.ready)
        {
         m_analysis.ready = false;
         return false;
        }

      AnalyzeTrend(data,features,m_analysis.trend);
      AnalyzeStructure(data,m_analysis.structure);
      AnalyzeVolatility(features,m_analysis.volatility);
      m_analysis.updated_at = TimeCurrent();
      m_analysis.ready      = true;
      return true;
     }

   GBXAnalysisSnapshot GetSnapshot(void) const
     {
      return m_analysis;
     }

   bool IsReady(void) const
     {
      return m_analysis.ready;
     }
  };

#endif
