//+------------------------------------------------------------------+
//|                                            Observers/ObsC.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers C — TE · IE2 · WR/DWR. Enriched (L4):                |
//|     TE   : Invisible Network path nodes + FCE trajectory + owner |
//|            objective + attractor convergence.                    |
//|     IE2  : recursive origin / parent curve / owner invalidation  |
//|            / point-4 (where the campaign is broken).             |
//|     WR/DWR : wave registry depth + recursion completion.         |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_C_MQH__
#define __HYPEROMEGA_OBS_C_MQH__

#include "ObserverBus.mqh"

class ObserversC
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      double atr=MathMax(s.atr,1e-10), close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== TE — targets (network path nodes + FCE trajectory + owner
      //    objective + attractor convergence) =======================
      double tgt = s.tfTgt[own];
      double pathNode = (od==1)? s.nodeAbove : (od==-1)? s.nodeBelow : NA_VAL;
      if(IsNa(tgt) && !IsNa(pathNode)) tgt = pathNode;
      // a node sitting between price and the objective is the nearer realistic target
      if(!IsNa(tgt) && !IsNa(pathNode))
        {
         if(od==1  && pathNode>close && pathNode<tgt) tgt=pathNode;
         if(od==-1 && pathNode<close && pathNode>tgt) tgt=pathNode;
        }
      o.te_target   = tgt; o.te_dir = od;
      o.te_travelAtr = (!IsNa(tgt))? MathAbs(tgt-close)/atr : 0.0;
      o.te_quality  = OmegaMath::Clamp(s.fce_budget*0.50 + o.frz_attractorScore*0.30 + s.chainVitality*0.20, 0.0, 100.0);

      //=== IE2 — invalidation (recursive origin / parent curve / owner
      //    invalidation / point-4) ===================================
      double inv = s.tfInv[own];
      if(IsNa(inv)) inv = (od==1)? s.tfP4l[own] : s.tfP4h[own];
      // widen to the parent (next higher) curve invalidation if more protective
      if(own<8 && !IsNa(s.tfInv[own+1]))
        {
         double pinv=s.tfInv[own+1];
         if(od==1  && pinv<Nz(inv,pinv)) inv=pinv;
         if(od==-1 && pinv>Nz(inv,pinv)) inv=pinv;
        }
      o.ie2_inv = inv;
      o.ie2_roomAtr = (!IsNa(inv))? MathAbs(close-inv)/atr : InpMinStopAtr;

      //=== WR / DWR — wave registry / depth =========================
      o.wr_depth     = s.recursiveDepth;
      o.wr_recursive = (s.isRecursive || s.recursiveComplete);
     }
  };

#endif // __HYPEROMEGA_OBS_C_MQH__
