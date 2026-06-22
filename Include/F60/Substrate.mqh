//+------------------------------------------------------------------+
//|                                            F60/Substrate.mqh     |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The F60 substrate aggregator (per symbol). Owns the entire     |
//|   substrate and produces ONE F60State snapshot per canonical     |
//|   (M5) bar:                                                      |
//|     9-TF SEEngine ladder · Invisible Network · recursive curve   |
//|     tree · participants · curve-force (FCE) · fractal stack ·    |
//|     time intelligence · deep cognition.                          |
//|                                                                  |
//|   Information flows UPWARD only: this fills F60State; observers   |
//|   read it (L2). Nothing above recomputes the substrate.          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_SUBSTRATE_MQH__
#define __HYPEROMEGA_F60_SUBSTRATE_MQH__

#include "../F60State.mqh"
#include "Structure.mqh"
#include "CurveFramework.mqh"
#include "CurveTreeF60.mqh"
#include "Network.mqh"
#include "Participants.mqh"
#include "FractalTime.mqh"
#include "Cognition.mqh"

class SubstrateEngine
  {
private:
   string           m_sym;
   SEEngine         m_se[9];
   ENUM_TIMEFRAMES  m_seTf[9]; datetime m_seLast[9];
   NetworkEngine    m_net;
   ENUM_TIMEFRAMES  m_fuTf[7]; datetime m_fuLast[7];
   F60CurveTree     m_tree;
   OmegaParticipants m_part;
   CurveForce       m_force;
   FractalStack     m_fractal;
   TimeIntelligence m_tie;
   CognitionEngine  m_cog;
   double           m_m5o,m_m5h,m_m5l,m_m5c,m_m5atr;
   int              m_structBias;
   double           m_compPersist[9]; int m_compBars[9];
   double           m_prevResidual; long m_prevTransfers;
public:
   void Init(string sym)
     {
      m_sym=sym;
      m_seTf[0]=PERIOD_M1; m_seTf[1]=PERIOD_M3; m_seTf[2]=PERIOD_M5; m_seTf[3]=PERIOD_M15;
      m_seTf[4]=PERIOD_H1; m_seTf[5]=PERIOD_H4; m_seTf[6]=PERIOD_D1; m_seTf[7]=PERIOD_W1; m_seTf[8]=PERIOD_MN1;
      for(int i=0;i<9;i++){ m_se[i].Init(InpPivotLen,InpAtrLen,InpEffLen,InpEffThresh,InpDispThresh,InpConvMult,InpImpulseAtrMult,InpChochBufferATR,InpUseStrictStruct); m_seLast[i]=0; m_compPersist[i]=0; m_compBars[i]=0; }
      m_fuTf[0]=PERIOD_MN1; m_fuTf[1]=PERIOD_W1; m_fuTf[2]=PERIOD_D1; m_fuTf[3]=PERIOD_H4; m_fuTf[4]=PERIOD_H1; m_fuTf[5]=PERIOD_M15; m_fuTf[6]=PERIOD_M5;
      m_net.Init(); for(int i=0;i<7;i++) m_fuLast[i]=0;
      m_tree.Init(sym); m_part.Init(sym); m_force.Reset(); m_fractal.Reset(); m_tie.Reset(); m_cog.Init(sym);
      m_structBias=0; m_m5o=m_m5h=m_m5l=m_m5c=m_m5atr=0; m_prevResidual=0; m_prevTransfers=0;
     }
   void Warmup(int bars)
     {
      for(int e=0;e<9;e++)
        {
         ENUM_TIMEFRAMES tf=m_seTf[e]; int avail=Bars(m_sym,tf); int n=MathMin(bars,avail-2);
         for(int sh=n;sh>=1;sh--) m_se[e].Step(iOpen(m_sym,tf,sh),iHigh(m_sym,tf,sh),iLow(m_sym,tf,sh),iClose(m_sym,tf,sh));
         m_seLast[e]=iTime(m_sym,tf,0);
        }
      for(int e=0;e<7;e++)
        {
         ENUM_TIMEFRAMES tf=m_fuTf[e]; int avail=Bars(m_sym,tf); int n=MathMin(bars,avail-2);
         for(int sh=n;sh>=1;sh--) m_net.StepTF(e,iOpen(m_sym,tf,sh),iHigh(m_sym,tf,sh),iLow(m_sym,tf,sh),iClose(m_sym,tf,sh));
         m_fuLast[e]=iTime(m_sym,tf,0);
        }
      m_m5o=iOpen(m_sym,PERIOD_M5,1); m_m5h=iHigh(m_sym,PERIOD_M5,1); m_m5l=iLow(m_sym,PERIOD_M5,1); m_m5c=iClose(m_sym,PERIOD_M5,1); m_m5atr=m_se[2].Atr();
      if(m_m5c>0) m_net.Commit(m_m5c,m_m5atr);
     }
   //--- advance closed bars; true when a NEW canonical (M5) bar processed
   bool DriveBars()
     {
      bool canon=false;
      for(int e=0;e<7;e++)
        {
         ENUM_TIMEFRAMES tf=m_fuTf[e]; datetime t0=iTime(m_sym,tf,0);
         if(t0!=0&&t0!=m_fuLast[e]){ if(m_fuLast[e]!=0) m_net.StepTF(e,iOpen(m_sym,tf,1),iHigh(m_sym,tf,1),iLow(m_sym,tf,1),iClose(m_sym,tf,1)); m_fuLast[e]=t0; }
        }
      for(int e=0;e<9;e++)
        {
         ENUM_TIMEFRAMES tf=m_seTf[e]; datetime t0=iTime(m_sym,tf,0);
         if(t0!=0&&t0!=m_seLast[e])
           {
            if(m_seLast[e]!=0)
              {
               double o=iOpen(m_sym,tf,1),h=iHigh(m_sym,tf,1),l=iLow(m_sym,tf,1),c=iClose(m_sym,tf,1);
               m_se[e].Step(o,h,l,c);
               if(e==2){ m_m5o=o; m_m5h=h; m_m5l=l; m_m5c=c; m_m5atr=m_se[2].Atr(); canon=true; }
              }
            m_seLast[e]=t0;
           }
        }
      if(canon) m_net.Commit(m_m5c,m_m5atr);
      return canon;
     }
   double CanonAtr() const { return (m_m5atr>0)?m_m5atr:0.0; }
   double NearestNodeAbove(double price,int wantDir){ return m_net.NearestNode(price,1,wantDir); }
   double NearestNodeBelow(double price,int wantDir){ return m_net.NearestNode(price,-1,wantDir); }

   //--- fill the F60 snapshot (call when DriveBars()==true)
   void Compute(F60State &s)
     {
      double close=m_m5c, high=m_m5h, low=m_m5l, atr=(m_m5atr>0?m_m5atr:MathMax(close*0.001,1e-10));
      s.close=close; s.high=high; s.low=low; s.open=m_m5o; s.atr=atr;
      int dirs[9];
      for(int i=0;i<9;i++)
        {
         s.tfDir[i]=F60DirByOrigin(m_se[i].o_inv,m_se[i].o_dir,close); dirs[i]=s.tfDir[i];
         s.tfPhase[i]=m_se[i].o_phase; s.tfPhaseStr[i]=F60PhaseStr(m_se[i].o_phase);
         s.tfWp[i]=m_se[i].o_wp; s.tfComp[i]=m_se[i].o_compIdx; s.tfMf[i]=m_se[i].o_mf; s.tfFrz[i]=m_se[i].o_frzS;
         s.tfInv[i]=m_se[i].o_inv; s.tfTgt[i]=m_se[i].o_tgt; s.tfFt[i]=m_se[i].o_ft; s.tfFb[i]=m_se[i].o_fb;
         s.tfCycH[i]=m_se[i].CycH(); s.tfCycL[i]=m_se[i].CycL(); s.tfP4h[i]=m_se[i].o_p4h; s.tfP4l[i]=m_se[i].o_p4l;
         s.tfBos[i]=m_se[i].o_bos; s.tfCh[i]=m_se[i].o_ch; s.tfELong[i]=m_se[i].o_eLong; s.tfEShort[i]=m_se[i].o_eShort; s.tfAtExt[i]=m_se[i].o_atExtreme;
         double cp=m_se[i].o_compIdx; m_compPersist[i]+=0.2*(cp-m_compPersist[i]);
         if(cp>55.0) m_compBars[i]++; else m_compBars[i]=0;
         s.tfCompPersist[i]=m_compPersist[i]; s.tfCompBars[i]=m_compBars[i];
        }
      //--- canonical physics
      s.vel=m_se[2].Vel(); s.acc=m_se[2].Acc(); s.conv=m_se[2].Conv(); s.convSmooth=m_se[2].ConvSmooth();
      s.eff=m_se[2].Eff(); s.disp=m_se[2].Disp(); s.velPrev2=m_se[2].VelPrev2();
      s.bullImp=m_se[2].BullImp(); s.bearImp=m_se[2].BearImp(); s.bullDec=m_se[2].BullDec(); s.bearDec=m_se[2].BearDec();
      s.bullCS=m_se[2].BullCS(); s.bearCS=m_se[2].BearCS(); s.vd70=m_se[2].Vd70(); s.vd50=m_se[2].Vd50();
      //--- network
      s.netBias=m_net.netBias; s.pdir=m_net.pdir; s.eligibleNodes=m_net.eligibleNodes; s.nodeCount=m_net.nodeCount;
      s.pressure=m_net.pressure; s.bullAuth=m_net.bullAuth; s.bearAuth=m_net.bearAuth;
      s.nodeAbove=m_net.NearestNode(close,1,0); s.nodeBelow=m_net.NearestNode(close,-1,0);
      //--- fractal stack
      m_fractal.Compute(dirs,9); s.fractalStackDir=m_fractal.dir; s.fractalStackScore=m_fractal.score;
      //--- structBias (M5 strict HH/HL)
      double sh=m_se[2].o_curSH,sl=m_se[2].o_curSL,psh=m_se[2].o_prSH,psl=m_se[2].o_prSL;
      bool isHH=!IsNa(sh)&&!IsNa(psh)&&sh>psh, isLH=!IsNa(sh)&&!IsNa(psh)&&sh<psh;
      bool isHL=!IsNa(sl)&&!IsNa(psl)&&sl>psl, isLL=!IsNa(sl)&&!IsNa(psl)&&sl<psl;
      if(InpUseStrictStruct){ if(isHH&&isHL) m_structBias=1; if(isLH&&isLL) m_structBias=-1; }
      else { if(m_se[2].o_bos==1) m_structBias=1; if(m_se[2].o_bos==-1) m_structBias=-1; }
      s.structBias=m_structBias;
      //--- recursive curve tree (F60-native: f_se recursion + network + MTF map)
      s.recursiveDepth=m_se[2].o_recBrk;
      m_tree.Update(s,m_se[2].o_recDom,close);
      s.ownerTf=m_tree.ownerTf; s.ownerDir=m_tree.ownerDir;
      s.treeOwnerDir=m_tree.ownerDir; s.treeOwnerEnergy=m_tree.ownerEnergy; s.treeOwnerStability=m_tree.ownerStability;
      s.treeDepth=m_tree.treeDepth; s.treeRecursionBudget=m_tree.recursionBudget; s.chainVitality=m_tree.chainVitality;
      s.treeTransferDir=m_tree.treeTransferDir;
      //--- participants (owner leg from the F60 curve tree)
      double ownOrigin=m_tree.ownerOrigin, ownExtreme=m_tree.ownerExtreme;
      m_part.Update(m_tree.ownerDir,ownOrigin,ownExtreme,atr,high,low,m_m5o,close);
      s.participantStability=m_part.participantStability; s.flipQuality=m_part.flipQuality;
      s.participantInterference=m_part.Interference();
      s.flipTrueInductionPx=m_part.flip.TrueInductionPrice(); s.flipTrueInductionDir=m_part.flip.TrueInductionDir();
      s.manipulationFlag=m_part.fib.ManipulationFlag();
      //--- curve force (FCE) — fed prev residual + tree depth (L4 enrichment)
      m_force.Update(m_se[2],m_prevResidual,m_tree.treeDepth);
      s.forceScore=m_force.forceScore; s.forceState=(int)m_force.forceState;
      s.compressionPersistChart=m_force.compressionNow; s.compressionTightenChart=m_force.compressionTighten;
      //--- time intelligence
      m_tie.Update(m_sym,close); s.timeDir=m_tie.timeDir; s.timeAlign=m_tie.timeAlign; s.timeConflict=m_tie.timeConflict;
      //--- deep cognition (fills energy/belief/spawn/liqg/attack)
      m_cog.Compute(s);
      //--- FCE composite (after cognition supplies residual/maturity)
      s.fce_residual=s.re_residualScore; s.fce_convexity=s.convexityScore; s.fce_maturity=s.convexityMaturity;
      double otgt=(owner>=0)?s.tfTgt[owner]:s.tfTgt[2], oinv=(owner>=0)?s.tfInv[owner]:s.tfInv[2];
      if(!IsNa(otgt)&&!IsNa(oinv)&&MathAbs(otgt-oinv)>1e-10){ double tr=OmegaMath::Clamp(MathAbs(close-oinv)/MathAbs(otgt-oinv)*100.0,0.0,100.0); s.fce_travel=tr; s.fce_budget=MathMax(0.0,100.0-tr); }
      else { s.fce_travel=50.0; s.fce_budget=50.0; }
      s.fce_progress=s.fce_maturity;
      m_prevResidual=s.re_residualScore;
     }
   //--- tree snapshot for diagnostics
   string TreeSnapshot() { return m_tree.Snapshot(); }
  };

#endif // __HYPEROMEGA_F60_SUBSTRATE_MQH__
