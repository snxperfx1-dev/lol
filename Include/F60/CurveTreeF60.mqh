//+------------------------------------------------------------------+
//|                                           F60/CurveTreeF60.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   F60-NATIVE curve tree (Part 16). Retires the Omega Tree/*      |
//|   lineage engine: F60 already carries the authoritative curve    |
//|   tree / recursion. Owner, control-transfer, chain vitality,     |
//|   recursion depth and budget are derived DIRECTLY from F60:      |
//|     · owner          = MTF curve-map rung that owns the curve    |
//|                        (highest mid-progress rung, strongest mf) |
//|     · recursion depth = f_se recBrk (canonical)                  |
//|     · recursion budget= compression-derived                      |
//|     · transfer        = f_se convexity-shift / recursion vs owner|
//|     · chain vitality  = FU/network confirmation + alignment      |
//|   No second structure engine; no Omega tree (L2 + "F60 is core").|
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_CURVETREE_F60_MQH__
#define __HYPEROMEGA_F60_CURVETREE_F60_MQH__

#include "../F60State.mqh"

class F60CurveTree
  {
private:
   double m_chainVit; int m_prevRecBrk;
public:
   int    ownerTf, ownerDir, treeDepth, recursionBudget, treeTransferDir;
   double ownerEnergy, ownerStability, chainVitality, ownerOrigin, ownerExtreme;

   void Reset(){ m_chainVit=OMEGA_TRINITY_NEUTRAL; m_prevRecBrk=0; ownerTf=-1; ownerDir=0; treeDepth=0; recursionBudget=1; treeTransferDir=0; ownerEnergy=0; ownerStability=OMEGA_TRINITY_NEUTRAL; chainVitality=OMEGA_TRINITY_NEUTRAL; ownerOrigin=0; ownerExtreme=0; }
   void Init(string sym){ Reset(); }

   static int BudgetFromCompression(double compNow){ return (int)MathMax(1,MathMin(4,1+(int)MathRound(compNow/33.0))); }

   //--- derive the curve tree from a (partially filled) F60State + canonical recDom.
   //    Substrate must have filled: tf* · fractal · structBias · network · recursiveDepth.
   void Update(const F60State &s, double recDom, double close)
     {
      //--- owner = highest mid-progress rung with strongest model fit (MTF curve map)
      int owner=-1; double bestMf=-1;
      for(int i=8;i>=0;i--) if(s.tfDir[i]!=0 && s.tfWp[i]>=15.0 && s.tfWp[i]<=92.0 && s.tfMf[i]>bestMf){ bestMf=s.tfMf[i]; owner=i; }
      if(owner<0) for(int i=8;i>=0;i--) if(s.tfDir[i]!=0){ owner=i; break; }
      ownerTf=owner; ownerDir=(owner>=0)?s.tfDir[owner]:0;

      //--- owner energy / stability (how alive + how coherent the owning curve is)
      if(owner>=0)
        {
         ownerEnergy = OmegaMath::Clamp(s.tfMf[owner]*0.45 + s.tfFrz[owner]*0.25
                       + (ownerDir==s.netBias && ownerDir!=0 ? 20.0:0.0)
                       + (ownerDir==s.structBias && ownerDir!=0 ? 10.0:0.0), 0.0, 100.0);
         ownerStability = OmegaMath::Clamp(s.fractalStackScore*0.60
                          + (ownerDir==s.fractalStackDir ? 25.0:0.0)
                          + (s.tfWp[owner]>20.0 && s.tfWp[owner]<85.0 ? 15.0:0.0), 0.0, 100.0);
         ownerOrigin  = Nz(s.tfInv[owner], close);
         ownerExtreme = (ownerDir==1)? Nz(s.tfCycH[owner],close) : Nz(s.tfCycL[owner],close);
        }
      else { ownerEnergy=0; ownerStability=OMEGA_TRINITY_NEUTRAL; ownerOrigin=close; ownerExtreme=close; }

      //--- recursion depth (f_se) + budget (compression)
      treeDepth       = s.recursiveDepth;
      recursionBudget = BudgetFromCompression(s.tfComp[TF_CANON]);

      //--- control transfer (F60-native): convexity-shift / recursion against the owner
      bool advanced = (s.recursiveDepth > m_prevRecBrk); m_prevRecBrk = s.recursiveDepth;
      int tdir=0;
      if(s.bullCS && ownerDir==-1)       tdir=1;
      else if(s.bearCS && ownerDir==1)   tdir=-1;
      else if(advanced && recDom>=50.0 && ownerDir!=0) tdir=-ownerDir;
      treeTransferDir = tdir;

      //--- chain vitality (FU/network confirmation + structural alignment), EWMA
      double rawVit = OmegaMath::Clamp(s.tfMf[TF_CANON]*0.40
                      + MathMin(s.eligibleNodes*8.0, 40.0)
                      + (s.netBias==s.structBias && s.structBias!=0 ? 20.0:0.0), 0.0, 100.0);
      m_chainVit += 0.2*(rawVit - m_chainVit);
      chainVitality = m_chainVit;
     }
   string Snapshot() const
     {
      return StringFormat("ownTf=%s ownDir=%d ownE=%.0f stab=%.0f depth=%d/%d transfer=%d chainV=%.0f",
              OmegaTfName(ownerTf>=0?ownerTf:TF_CANON), ownerDir, ownerEnergy, ownerStability,
              treeDepth, recursionBudget, treeTransferDir, chainVitality);
     }
  };

#endif // __HYPEROMEGA_F60_CURVETREE_F60_MQH__
