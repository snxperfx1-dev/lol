//+------------------------------------------------------------------+
//|                                       Observers/ObserverBus.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The shared observer output bus. Every V72 observer writes its  |
//|   reading here; HyperIntelligence reads the whole bus. Observers  |
//|   are orthogonal — each answers a DIFFERENT question (L3) and is  |
//|   fed by authentic F60 substrate values (L4).                    |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBSERVERBUS_MQH__
#define __HYPEROMEGA_OBSERVERBUS_MQH__

#include "../F60State.mqh"

struct ObserverBus
  {
   //--- ERF — unresolved / residual energy
   double erf_residual; int erf_unresolvedDir; double erf_exhaustScore; int erf_exhaustDir;
   //--- FRZ — supply/demand geometry · attractors
   double frz_supplyDistAtr, frz_demandDistAtr, frz_attractor, frz_attractorScore, frz_approachQ; int frz_dir;
   //--- RIE — rotation / control transfer
   double rie_rotationProb; int rie_transferDir;
   //--- MCE — MTF consensus
   int    mce_dir; double mce_score, mce_conflict;
   //--- NE — narrative
   int    ne_dir; double ne_maturity; string ne_story;
   //--- TQE — trade qualification (veto gate)
   double tqe_quality;
   //--- TE — targets
   double te_target, te_quality, te_travelAtr; int te_dir;
   //--- IE2 — invalidation
   double ie2_inv, ie2_roomAtr;
   //--- WR / DWR — wave registry / depth
   int    wr_depth; bool wr_recursive;

   void Reset()
     {
      erf_residual=0; erf_unresolvedDir=0; erf_exhaustScore=0; erf_exhaustDir=0;
      frz_supplyDistAtr=99; frz_demandDistAtr=99; frz_attractor=NA_VAL; frz_attractorScore=0; frz_approachQ=0; frz_dir=0;
      rie_rotationProb=0; rie_transferDir=0;
      mce_dir=0; mce_score=0; mce_conflict=0;
      ne_dir=0; ne_maturity=0; ne_story="BALANCE";
      tqe_quality=50;
      te_target=NA_VAL; te_quality=0; te_travelAtr=0; te_dir=0;
      ie2_inv=NA_VAL; ie2_roomAtr=0;
      wr_depth=0; wr_recursive=false;
     }
  };

#endif // __HYPEROMEGA_OBSERVERBUS_MQH__
