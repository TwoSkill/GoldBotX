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

   ENUM_GBX_SESSION DetermineSession(void) const
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(),dt);
      const int hour=dt.hour;

      if(hour>=13 && hour<17)
         return GBX_SESSION_OVERLAP;
      if(hour>=7 && hour<13)
         return GBX_SESSION_LONDON;
      if(hour>=17 && hour<22)
         return GBX_SESSION_NEW_YORK;
      if(hour>=0 && hour<7)
         return GBX_SESSION_ASIA;
      return GBX_SESSION_NONE;
     }

   double DetermineLiquidityScore(const ENUM_GBX_SESSION session,
                                  const GBXFeatureSnapshot &features) const
     {
      double session_score=45.0;
      if(session==GBX_SESSION_OVERLAP)
         session_score=100.0;
      else if(session==GBX_SESSION_LONDON)
         session_score=90.0;
      else if(session==GBX_SESSION_NEW_YORK)
         session_score=85.0;
      else if(session==GBX_SESSION_ASIA)
         session_score=68.0;

      return ClampScore(session_score*0.70+features.spread_quality*0.30);
     }

   double VolatilityBalanceScore(const double volatility_score) const
     {
      return ClampScore(100.0-MathAbs(volatility_score-45.0)*2.0);
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

   ENUM_GBX_SIGNAL_CLASS DetermineSignalClass(const ENUM_GBX_MARKET_REGIME regime,
                                              const double quality,
                                              const double confidence) const
     {
      if(regime == GBX_REGIME_UNTRADEABLE || regime == GBX_REGIME_UNCERTAIN ||
         regime == GBX_REGIME_HIGH_VOLATILITY)
         return GBX_SIGNAL_C;

      if(quality >= 90.0 && confidence >= 85.0)
         return GBX_SIGNAL_A;
      if(quality >= m_config.min_quality_score && confidence >= m_config.min_confidence)
         return GBX_SIGNAL_B;
      return GBX_SIGNAL_C;
     }

   double RiskMultiplierForSignal(const ENUM_GBX_SIGNAL_CLASS signal_class) const
     {
      if(signal_class==GBX_SIGNAL_A)
         return 1.00;
      if(signal_class==GBX_SIGNAL_B)
         return 0.55;
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
         GBXInitializeMarketState(m_state);
         m_state.favorability = GBX_FAVORABILITY_BLOCKED;
         return false;
        }

      m_state.direction = analysis.trend.direction;
      m_state.session   = DetermineSession();
      m_state.regime    = DetermineRegime(features,analysis);

      m_state.trend_score      = analysis.trend.score;
      m_state.structure_score  = analysis.structure.score;
      m_state.momentum_score   = features.momentum_score;
      m_state.volatility_score = analysis.volatility.score;
      m_state.liquidity_score  = DetermineLiquidityScore(m_state.session,features);

      if(m_state.regime==GBX_REGIME_CLEAN_RANGE)
        {
         const double no_trend_score=ClampScore(100.0-analysis.trend.score*2.0);
         const double neutral_structure_score=(analysis.structure.direction==GBX_DIRECTION_NEUTRAL ? 100.0 : 45.0);
         const double volatility_balance=VolatilityBalanceScore(analysis.volatility.score);

         m_state.quality = ClampScore(
            no_trend_score*0.25 +
            neutral_structure_score*0.20 +
            features.spread_quality*0.20 +
            m_state.liquidity_score*0.20 +
            volatility_balance*0.15);

         m_state.confidence = ClampScore(
            no_trend_score*0.28 +
            neutral_structure_score*0.22 +
            features.spread_quality*0.18 +
            m_state.liquidity_score*0.17 +
            volatility_balance*0.15);
        }
      else
        {
         m_state.quality = ClampScore(
            analysis.trend.score*0.28 +
            analysis.structure.score*0.23 +
            features.momentum_score*0.19 +
            features.spread_quality*0.10 +
            features.candle_quality*0.10 +
            m_state.liquidity_score*0.10);

         const double alignment_bonus = features.primary_context_aligned ? 10.0 : 0.0;
         const double liquidity_bonus = m_state.liquidity_score >= 80.0 ? 5.0 : 0.0;
         m_state.confidence = ClampScore(
            features.preliminary_quality*0.38 +
            analysis.trend.score*0.30 +
            analysis.structure.score*0.20 +
            alignment_bonus +
            liquidity_bonus);
        }

      const bool permitted_regime =
         m_state.regime == GBX_REGIME_BULLISH_TREND ||
         m_state.regime == GBX_REGIME_BEARISH_TREND ||
         m_state.regime == GBX_REGIME_FORMING_TREND ||
         m_state.regime == GBX_REGIME_CLEAN_RANGE;

      m_state.signal_class = DetermineSignalClass(m_state.regime,m_state.quality,m_state.confidence);
      m_state.risk_multiplier = RiskMultiplierForSignal(m_state.signal_class);
      m_state.is_tradeable = permitted_regime &&
                             m_state.signal_class!=GBX_SIGNAL_C &&
                             m_state.liquidity_score >= 55.0;

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

      const bool addable_trend=IsStrongAlignedTrend(features,analysis);
      const bool addable_range=m_state.regime==GBX_REGIME_CLEAN_RANGE &&
                               m_state.signal_class==GBX_SIGNAL_A;
      m_state.can_add_position = m_state.is_tradeable &&
                                 (addable_trend || addable_range);
      return true;
     }

   GBXMarketState GetState(void) const
     {
      return m_state;
     }
  };

#endif
