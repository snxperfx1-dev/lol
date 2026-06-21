//+------------------------------------------------------------------+
//|                                            Observers/ObsB.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers B — MCE · NE · TQE. Enriched (L4):                   |
//|     MCE  : fractal stack + curve map + Time Intelligence (NOT a  |
//|            naive per-TF alignment %).                            |
//|     NE   : owner-phase lineage + campaign ownership + chain      |
//|            vitality -> dominant story.                           |
//|     TQE  : ERF + FRZ convergence + chain vitality + network      |
//|            pressure + participant interference (veto gate).      |
//|                                                                  |
//|   MCE runs before TQE (TQE reads mce_conflict). FRZ (ObsA) ran   |
//|   first, so TQE may read frz_*.                                  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_B_MQH__
#define __HYPEROMEGA_OBS_B_MQH__

#include "ObserverBus.mqh"

class ObserversB
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== MCE — MTF consensus (fractal stack + curve map + TIE) ====
      o.mce_dir   = s.fractalStackDir;
      o.mce_score = OmegaMath::Clamp(s.fractalStackScore*0.60 + s.timeAlign*0.40, 0.0, 100.0);
      o.mce_conflict = OmegaMath::Clamp((od!=0 && s.fractalStackDir!=0 && od!=s.fractalStackDir ? 50.0:0.0)
                       + s.timeConflict*0.50, 0.0, 100.0);

      //=== NE — dominant narrative (owner phase lineage + chain) =====
      o.ne_dir = od; o.ne_maturity = s.fce_maturity;
      string ph = s.tfPhaseStr[own];
      string story;
      if(OmegaStr::Has(ph,"Expansion") && !OmegaStr::Has(ph,"Induction") && !OmegaStr::Has(ph,"Liquidity")) story="EXPANSION";
      else if(OmegaStr::Has(ph,"Induction") || OmegaStr::Has(ph,"Liquidity"))                              story="DISTRIBUTION";
      else if(OmegaStr::Has(ph,"Retracement") || OmegaStr::Has(ph,"Flip"))                                 story="ACCUMULATION";
      else if(OmegaStr::Has(ph,"Liquidation") || OmegaStr::Has(ph,"Terminal"))                             story="LIQUIDATION";
      else if(OmegaStr::Has(ph,"Demand Return") || OmegaStr::Has(ph,"Supply Return"))                      story="CAMPAIGN TRANSITION";
      else if(OmegaStr::Has(ph,"New High") || OmegaStr::Has(ph,"New Low"))                                 story="DELIVERY";
      else                                                                                                 story="BALANCE";
      // chain vitality strengthens / weakens the conviction of the story
      if(s.chainVitality<35.0 && story!="LIQUIDATION") story=story+" (weak)";
      o.ne_story = story;

      //=== TQE — trade qualification (veto gate) ===================
      double q = OmegaMath::Clamp(s.chainVitality*0.30 + o.frz_attractorScore*0.20
                 + MathAbs(s.pressure)*0.20 + o.frz_approachQ*0.15
                 + (s.eligibleNodes>0?MathMin(s.eligibleNodes*3.0,15.0):0.0), 0.0, 100.0);
      q -= o.mce_conflict*0.20 + (s.fce_maturity>90.0?15.0:0.0) + s.participantInterference*0.10;
      // a persisting force / fresh residual lifts qualification (L4)
      if(s.forceState==2) q += 8.0;
      if(o.erf_residual>60.0) q += 6.0;
      o.tqe_quality = OmegaMath::Clamp(q, 0.0, 100.0);
     }
  };

#endif // __HYPEROMEGA_OBS_B_MQH__
