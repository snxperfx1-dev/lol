//+------------------------------------------------------------------+
//|                                          F60/CurveFramework.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Layer 5/7 — the curve-force framework that stands ON the       |
//|   structure authority (SEEngine), never duplicating it (L2):     |
//|     · CompressionTracker — rolling compression + tighten signal  |
//|     · ConvexityHelper     — convexity score / shift / maturity   |
//|     · ForceHelper          — Compression Persistence composite    |
//|       (PERSISTING / NEUTRAL / LEAKING)                           |
//|     · CurveForce          — the FCE base: aggregates the above   |
//|       into the force/curve-energy reading the observers consume. |
//|                                                                  |
//|   Preserved from the F72 Omega Curve/* lineage (Compression,     |
//|   Convexity, Force), re-pointed to read the authentic SEEngine.  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__
#define __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__

#include "Structure.mqh"

//==================================================================
//= Compression intelligence — can price BREATHE, or is it SQUEEZED?
//==================================================================
class CompressionTracker
  {
private:
   double m_history[]; int m_head, m_count, m_capacity;
public:
            CompressionTracker(){ m_capacity=16; ArrayResize(m_history,m_capacity); Reset(); }
   void Reset(){ m_head=0; m_count=0; ArrayInitialize(m_history,0.0); }
   void Push(double sample){ m_history[m_head]=sample; m_head=(m_head+1)%m_capacity; if(m_count<m_capacity) m_count++; }
   void Sample(double v){ Push(v); }
   //--- Δcompression over last `lookback` samples. + = TIGHTENING, - = BROADENING
   double Tightening(int lookback=5) const
     {
      if(m_count<2) return 0.0;
      int span=MathMin(lookback,m_count-1);
      int latest=(m_head-1+m_capacity)%m_capacity;
      int earlier=(m_head-1-span+m_capacity)%m_capacity;
      return m_history[latest]-m_history[earlier];
     }
   double Latest() const { if(m_count==0) return 0.0; int latest=(m_head-1+m_capacity)%m_capacity; return m_history[latest]; }
   string Tier() const
     {
      double v=Latest();
      if(v>=75.0) return "FAILURE_SWING";
      if(v>=50.0) return "COMPRESSED";
      if(v>=25.0) return "MEDIUM";
      return "WIDE";
     }
   int    Count() const { return m_count; }
  };

//==================================================================
//= Convexity helper — energy cannot travel infinitely straight
//==================================================================
class ConvexityHelper
  {
public:
   static double Score(SEEngine &se)    { return OmegaMath::Clamp(se.o_cm, 0.0, 100.0); }     // == convScore (no recompute)
   static int    ShiftSign(SEEngine &se){ if(se.BullCS()) return 1; if(se.BearCS()) return -1; return 0; }
   static double Maturity(SEEngine &se) { return OmegaMath::Clamp(se.o_wp, 0.0, 100.0); }
  };

//==================================================================
//= Force — Compression Persistence (can the COUNTER side build?)
//==================================================================
enum ENUM_OMEGA_FORCE_STATE { FORCE_LEAKING=0, FORCE_NEUTRAL=1, FORCE_PERSISTING=2 };

class ForceHelper
  {
public:
   static double Score(double compNow,double compTighten,double residualEnergy=0.0,int recursionDepth=0)
     {
      double s = compNow*0.50 + residualEnergy*0.20 - (double)recursionDepth*12.0
               + MathMax(0.0,compTighten)*0.8 + 8.0;
      return OmegaMath::Clamp(s,0.0,100.0);
     }
   static ENUM_OMEGA_FORCE_STATE State(double score){ if(score>=60.0) return FORCE_PERSISTING; if(score<=35.0) return FORCE_LEAKING; return FORCE_NEUTRAL; }
   static string StateString(ENUM_OMEGA_FORCE_STATE s){ switch(s){ case FORCE_PERSISTING:return"PERSISTING"; case FORCE_LEAKING:return"LEAKING"; case FORCE_NEUTRAL:return"NEUTRAL"; } return"UNKNOWN"; }
   static string TightenTrend(double t){ if(t>3.0) return"TIGHTENING"; if(t<-3.0) return"BROADENING"; return"STABLE"; }
  };

//==================================================================
//= CurveForce — the FCE base. One per timeframe curve. Aggregates
//= compression persistence + convexity into the force/curve-energy
//= reading. residualEnergy + recursionDepth are fed in by the deep
//= cognition layer (Part 8) — the L4 enrichment hook.
//==================================================================
class CurveForce
  {
private:
   CompressionTracker m_comp;
public:
   double                 convexityScore, convexityMaturity; int convShift;
   double                 compressionNow, compressionTighten;
   double                 forceScore;  ENUM_OMEGA_FORCE_STATE forceState;
   double                 curveEnergy;     // preliminary curve-energy estimate (residual proxy until Part 8)
   string                 compTier, tightenTrend, forceStr;

   void Reset()
     {
      m_comp.Reset();
      convexityScore=convexityMaturity=0; convShift=0;
      compressionNow=compressionTighten=0; forceScore=50; forceState=FORCE_NEUTRAL;
      curveEnergy=0; compTier="WIDE"; tightenTrend="STABLE"; forceStr="NEUTRAL";
     }
   void Update(SEEngine &se,double residualEnergy=0.0,int recursionDepth=0)
     {
      m_comp.Sample(se.o_compIdx);
      compressionNow     = m_comp.Latest();
      compressionTighten = m_comp.Tightening(5);
      convexityScore     = ConvexityHelper::Score(se);
      convexityMaturity  = ConvexityHelper::Maturity(se);
      convShift          = ConvexityHelper::ShiftSign(se);
      forceScore         = ForceHelper::Score(compressionNow,compressionTighten,residualEnergy,recursionDepth);
      forceState         = ForceHelper::State(forceScore);
      curveEnergy        = OmegaMath::Clamp(se.o_mf*0.6 + se.o_frzS*0.4 - convexityMaturity*0.2, 0.0, 100.0);
      compTier           = m_comp.Tier();
      tightenTrend       = ForceHelper::TightenTrend(compressionTighten);
      forceStr           = ForceHelper::StateString(forceState);
     }
  };

#endif // __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__
