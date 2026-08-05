#ifndef GBX_MARKET_CLASSIFIER_MQH
#define GBX_MARKET_CLASSIFIER_MQH

#include "../Core/GBX_Types.mqh"
#include "../Core/GBX_Logger.mqh"
#include "../Data/GBX_DataTypes.mqh"
#include "../Feature/GBX_FeatureTypes.mqh"
#include "../Analyzer/GBX_AnalysisTypes.mqh"

class CGBXMarketClassifier
  {
private:
   GBXConfig      m_config;
   GBXMarketState m_state;
   CGBXLogger     m_logger;

   double ClampScore(const double value) const
     {
      return MathMax(0.0,MathMin(100.0,value));
     }

   bool IsStrongAlignedTrend(const GBXFeatureSnapshot &features,
                             const GBXAnalysisSnapshot &analysis) const
     {
      return analysis.trend.score >= 70.0 &&
             analysis.structure.score >= 80.0 &&
             analysis.trend.direction == analysis.structure.direction &&
             features.ema_aligned &&
             features.primary_context_aligned;
     }

   ENUM_GBX_MARKET_REGIME DetermineRegime(const GBXFeatureSnapshot &features,
                                          const GBXAnalysisSnapshot &analysis) const
     {
      if(!features.spread_acceptable)
         return GBX_REGIME_UNTRADEABLE;

      if(analysis.volatility.elevated)
         return GBX_REGIME_HIGH_VOLATILITY;

      if(analysis.volatility.compressed)
         return GBX_REGIME_COMPRESSION;

      if(IsStrongAlignedTrend(features,analysis))
        {
         if(analysis.trend.direction == GBX_DIRECTION_BULLISH)
            return GBX_REGIME_BULLISH_TREND;
         if(analysis.trend.direction == GBX_DIRECTION_BEARISH)
            return GBX_REGIME_BEARISH_TREND;
        }

      if(analysis.trend.score >= 45.0 &&
         analysis.trend.direction != GBX_DIRECTION_NEUTRAL)
         return GBX_REGIME_FORMING_TREND;

      if(analysis.trend.score < 35.0 && analysis.structure.direction == GBX_DIRECTION_NEUTRAL)
         return GBX_REGIME_CLEAN_RANGE;

      if(analysis.trend.score < 55.0)
         return GBX_REGIME_NOISY_RANGE;

      return GBX_REGIME_UNCERTAIN;
     }

   double DetermineRiskMultiplier(const ENUM_GBX_MARKET_REGIME regime,
                                  const double quality,
                                  const double confidence) const
     {
      if(regime == GBX_REGIME_UNTRADEABLE || regime == GBX_REGIME_UNCERTAIN ||
         regime == GBX_REGIME_HIGH_VOLATILITY)
         return 0.0;

      if(quality >= 90.0 && confidence >= 90.0)
         return 1.0;
      if(quality >= 80.0 && confidence >= 80.0)
         return 0.80;
      if(quality >= 70.0 && confidence >= 70.0)
         return 0.60;
      return 0.0;
     }

public:
   CGBXMarketClassifier(void)
     {
      GBXInitializeConfig(m_config);
      GBXInitializeMarketState(m_state);
     }

   bool Initialize(const GBXConfig &config)
     {
      m_config = config;
      m_logger.Configure(config.debug_logging);
      GBXInitializeMarketState(m_state);
      m_logger.Info("Market Classifier initialized.");
      return true;
     }

   bool Refresh(const GBXDataSnapshot &data,
                const GBXFeatureSnapshot &features,
                const GBXAnalysisSnapshot &analysis)
     {
      if(!data.ready || !features.ready || !analysis.ready)
        {
         m_state.is_tradeable = false;
         return false;
        }

      m_state.direction = analysis.trend.direction;
      m_state.session   = GBX_SESSION_NONE;
      m_state.regime    = DetermineRegime(features,analysis);

      m_state.trend_score      = analysis.trend.score;
      m_state.structure_score  = analysis.structure.score;
      m_state.momentum_score   = features.momentum_score;
      m_state.volatility_score = analysis.volatility.score;
      m_state.liquidity_score  = 0.0;

      m_state.quality = ClampScore(
         analysis.trend.score*0.30 +
         analysis.structure.score*0.25 +
         features.momentum_score*0.20 +
         features.spread_quality*0.15 +
         features.candle_quality*0.10);

      const double alignment_bonus = features.primary_context_aligned ? 10.0 : 0.0;
      m_state.confidence = ClampScore(
         features.preliminary_quality*0.40 +
         analysis.trend.score*0.30 +
         analysis.structure.score*0.20 +
         alignment_bonus);

      const bool permitted_regime =
         m_state.regime == GBX_REGIME_BULLISH_TREND ||
         m_state.regime == GBX_REGIME_BEARISH_TREND ||
         m_state.regime == GBX_REGIME_FORMING_TREND ||
         m_state.regime == GBX_REGIME_CLEAN_RANGE;

      m_state.is_tradeable = permitted_regime &&
                             m_state.quality >= m_config.min_quality_score &&
                             m_state.confidence >= m_config.min_confidence;

      if(m_state.regime == GBX_REGIME_UNTRADEABLE)
         m_state.favorability = GBX_FAVORABILITY_BLOCKED;
      else if(m_state.is_tradeable)
         m_state.favorability = GBX_FAVORABILITY_FAVORABLE;
      else if(m_state.regime == GBX_REGIME_UNCERTAIN ||
              m_state.regime == GBX_REGIME_NOISY_RANGE ||
              m_state.regime == GBX_REGIME_HIGH_VOLATILITY)
         m_state.favorability = GBX_FAVORABILITY_UNFAVORABLE;
      else
         m_state.favorability = GBX_FAVORABILITY_NEUTRAL;

      m_state.risk_multiplier = DetermineRiskMultiplier(m_state.regime,
                                                         m_state.quality,
                                                         m_state.confidence);
      m_state.can_add_position = m_state.is_tradeable &&
                                 m_state.risk_multiplier >= 0.80 &&
                                 IsStrongAlignedTrend(features,analysis);
      return true;
     }

   GBXMarketState GetState(void) const
     {
      return m_state;
     }
  };

#endif
