//+------------------------------------------------------------------+
//|                                  Exec/PositionIntelligence.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Position Intelligence (spec Stratum F / L10): the trade is     |
//|   never "over". Post-entry, the live campaign is continuously    |
//|   re-evaluated against the F60 substrate + observers (curve-tree |
//|   owner flip, struct flip, chain vitality, exhaustion, terminal  |
//|   phase, rotation transfer) and the verdict feeds back into the  |
//|   loop -> trail / partial / exit / reverse.                      |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_POSITION_INTELLIGENCE_MQH__
#define __HYPEROMEGA_POSITION_INTELLIGENCE_MQH__

#include "../Observers/ObserverBus.mqh"
#include "../Hyper/Opportunity.mqh"

struct Campaign
  {
   bool   active; int dir; double entry, initialSL, initTarget, origVol;
   EntryFamily family; MgmtStyle mgmt; bool partialDone; int adds; ulong ticket;
   void Reset(){ active=false; dir=0; entry=0; initialSL=NA_VAL; initTarget=NA_VAL; origVol=0; family=FAM_NONE; mgmt=MGMT_NORMAL; partialDone=false; adds=0; ticket=0; }
  };
struct PositionVerdict { bool doExit, doPartial, doTrail, doReverse; double newSL; string reason; };

class PositionIntelligence
  {
public:
   static void Evaluate(const F60State &s,const ObserverBus &o,const Campaign &c,double curPrice,PositionVerdict &v)
     {
      v.doExit=false; v.doPartial=false; v.doTrail=false; v.doReverse=false; v.newSL=NA_VAL; v.reason="";
      if(!c.active||c.dir==0) return;
      int dir=c.dir;
      bool ownerFlipped   = (s.ownerDir!=0 && s.ownerDir!=dir);
      bool structFlipped  = (s.structBias!=0 && s.structBias!=dir);
      bool lowVitality    = (s.chainVitality<35.0);
      bool resolvedAgainst= (o.erf_exhaustDir==dir && o.erf_exhaustScore>70.0);
      bool phaseTerminal  = OmegaStr::Has(s.tfPhaseStr[TF_CANON],"Liquidation")||OmegaStr::Has(s.tfPhaseStr[TF_CANON],"Terminal");
      bool rotationAgainst= (o.rie_rotationProb>70.0 && o.rie_transferDir!=0 && o.rie_transferDir!=dir);

      if((ownerFlipped && lowVitality) || (structFlipped && rotationAgainst) || (resolvedAgainst && phaseTerminal))
        { v.doExit=true; v.reason="campaign invalidated (owner/struct flip · exhaustion · terminal)"; return; }
      if(rotationAgainst && resolvedAgainst)
        { v.doReverse=true; v.reason="control transfer against position"; }
      if(!c.partialDone)
        {
         bool tgtHit = (!IsNa(c.initTarget)) && ((dir==1 && curPrice>=c.initTarget) || (dir==-1 && curPrice<=c.initTarget));
         bool matureFade = (s.fce_maturity>82.0 && s.fce_budget<25.0);
         if(tgtHit || matureFade){ v.doPartial=true; v.reason="first objective / maturity — bank partial"; }
        }
      if(InpTrailStops && !IsNa(o.ie2_inv)) { v.doTrail=true; v.newSL=o.ie2_inv; }
     }
  };

#endif // __HYPEROMEGA_POSITION_INTELLIGENCE_MQH__
