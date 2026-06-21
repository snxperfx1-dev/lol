//+------------------------------------------------------------------+
//|                                            Observers/ObsA.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers A — ERF · FRZ · RIE. Each ENRICHED to consume        |
//|   authentic F60 outputs (L4): FCE residual, chain vitality,      |
//|   compression persistence, curve maturity/budget, Invisible      |
//|   Network nodes, curve-tree ownership transfer, participant      |
//|   interference. NO EMA/ATR proxies.                              |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_A_MQH__
#define __HYPEROMEGA_OBS_A_MQH__

#include "ObserverBus.mqh"

class ObserversA
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      double atr=MathMax(s.atr,1e-10), close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== ERF — unresolved energy (FCE residual + compression
      //    persistence + chain vitality + curve maturity + force) ===
      o.erf_residual = OmegaMath::Clamp(s.fce_residual*0.45 + s.chainVitality*0.20
                       + s.tfCompPersist[own]*0.15 + (100.0-s.fce_maturity)*0.10
                       + (s.forceState==2?10.0:0.0), 0.0, 100.0);   // forceState 2 = PERSISTING
      o.erf_unresolvedDir = od;
      double exh = OmegaMath::Clamp((s.fce_maturity>70.0?40.0:0.0) + ((s.bullDec||s.bearDec)?20.0:0.0)
                   + (s.fce_budget<25.0?25.0:0.0) + (s.tfAtExt[own]?15.0:0.0), 0.0, 100.0);
      o.erf_exhaustScore = exh; o.erf_exhaustDir = od;

      //=== FRZ — supply/demand geometry · attractors (network nodes +
      //    curve ownership + flip zones + participant true induction) =
      double sup=s.nodeAbove, dem=s.nodeBelow;
      double oft=s.tfFt[own], ofb=s.tfFb[own];
      if(!IsNa(oft)&&oft>close&&(IsNa(sup)||oft<sup)) sup=oft;
      if(!IsNa(ofb)&&ofb<close&&(IsNa(dem)||ofb>dem)) dem=ofb;
      double tiPx=s.flipTrueInductionPx;
      if(tiPx>0)
        {
         if(tiPx>close && (IsNa(sup)||tiPx<sup)) sup=tiPx;
         if(tiPx<close && (IsNa(dem)||tiPx>dem)) dem=tiPx;
        }
      o.frz_supplyDistAtr = !IsNa(sup)? (sup-close)/atr : 99.0;
      o.frz_demandDistAtr = !IsNa(dem)? (close-dem)/atr : 99.0;
      double attr = s.tfTgt[own];
      if(IsNa(attr)) attr = (od==1)? sup : dem;
      o.frz_attractor = attr;
      o.frz_attractorScore = OmegaMath::Clamp(s.fce_budget*0.45 + s.chainVitality*0.25
                             + (s.eligibleNodes>0?20.0:0.0) + (s.flipQuality>50.0?10.0:0.0), 0.0, 100.0);
      o.frz_dir = od;
      double approachDist = (od==1)? o.frz_demandDistAtr : (od==-1)? o.frz_supplyDistAtr : 99.0;
      o.frz_approachQ = OmegaMath::Clamp(100.0 - approachDist*30.0, 0.0, 100.0);

      //=== RIE — rotation / control transfer (ownership transfer +
      //    recursion + participant interference + compression + shift) =
      bool ownerVsStruct = (od!=0 && s.structBias!=0 && od!=s.structBias);
      double rot = OmegaMath::Clamp((s.treeTransferDir!=0?25.0:0.0)
                   + MathMin(s.recursiveDepth*12.0, 36.0)
                   + (ownerVsStruct?20.0:0.0)
                   + s.participantInterference*0.20
                   + (s.compressionPersistChart>60.0?10.0:0.0)
                   + ((s.bullCS||s.bearCS)?10.0:0.0), 0.0, 100.0);
      o.rie_rotationProb = rot;
      o.rie_transferDir = (s.treeTransferDir!=0)? s.treeTransferDir
                          : (s.bullCS?1:s.bearCS?-1:(rot>50.0? -od : 0));
     }
  };

#endif // __HYPEROMEGA_OBS_A_MQH__
