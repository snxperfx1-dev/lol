//+------------------------------------------------------------------+
//|                                              F60/Structure.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   f_se — the fixed-TF structure & lifecycle authority. Stands on |
//|   PhysicsCore (f_phys). Sequential per-bar state machine (Pine   |
//|   'var' evolution): pivots -> BOS/CHoCH -> wave spawn -> recursion|
//|   / inducement -> origin-based direction -> phase machine 0..14. |
//|                                                                  |
//|   This is the SOLE lifecycle authority for its timeframe. No     |
//|   higher layer recomputes structure or phases (Law L2).          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_STRUCTURE_MQH__
#define __HYPEROMEGA_F60_STRUCTURE_MQH__

#include "Physics.mqh"

//--- phase code -> human label (Engine 1A vocabulary)
string F60PhaseStr(int c)
  {
   switch(c){ case 1:return"Expansion"; case 2:return"Expansion Pre-Convexity"; case 3:return"Expansion Induction";
              case 4:return"Expansion Liquidity"; case 5:return"New High"; case 6:return"New Low"; case 7:return"Transition";
              case 8:return"Retracement"; case 9:return"HTF Flip Zone"; case 10:return"Induction"; case 11:return"Liquidation";
              case 12:return"Terminal Curve"; case 13:return"Demand Return"; case 14:return"Supply Return"; }
   return "Point 4 Origin";
  }
int F60DirByOrigin(double origin,int fallback,double close){ if(IsNa(origin)) return fallback; return close>origin?1:close<origin?-1:fallback; }

class SEEngine
  {
private:
   PhysicsCore m_phys;
   int    m_pvLen; double m_impM, m_chBuf; bool m_strict;
   double m_effT, m_dispT, m_convM;
   //--- OHLC ring for pivots (newest at end)
   double m_hi[64], m_lo[64], m_cl[64]; int m_n;
   //--- pivot memory
   double m_curSH, m_curSL, m_prSH, m_prSL, m_lastP, m_prevP; int m_lastD, m_prevD;
   //--- wave context
   int    m_dir; double m_ft, m_fb, m_p4h, m_p4l, m_inv, m_tgt, m_cycH, m_cycL;
   //--- recursion / inducement
   bool   m_bos1, m_bos2, m_indBrk; double m_protSw, m_protSw2, m_indOrig, m_indExt;
   int    m_lastDirSeen, m_recBrk; bool m_recArm; int m_pst;
public:
   //--- structural outputs (the f_se return tuple)
   int    o_dir, o_phase;
   double o_curSH, o_curSL, o_prSH, o_prSL;
   int    o_bos, o_ch;
   double o_p4h, o_p4l, o_inv, o_tgt, o_ft, o_fb, o_frzS, o_wp, o_cm, o_mf, o_compIdx;
   int    o_recBrk; double o_recDom;
   bool   o_reset, o_eLong, o_eShort, o_atExtreme;

   void Init(int pvLen,int atrL,int effL,double effT,double dispT,double convM,double impM,double chBuf,bool strict)
     {
      m_phys.Init(atrL,effL,effT,dispT,convM);
      m_pvLen=pvLen; m_impM=impM; m_chBuf=chBuf; m_strict=strict;
      m_effT=effT; m_dispT=dispT; m_convM=convM;
      Reset();
     }
   void Reset()
     {
      m_phys.Reset();
      ArrayInitialize(m_hi,0); ArrayInitialize(m_lo,0); ArrayInitialize(m_cl,0); m_n=0;
      m_curSH=m_curSL=m_prSH=m_prSL=NA_VAL; m_lastP=m_prevP=NA_VAL; m_lastD=m_prevD=0;
      m_dir=0; m_ft=m_fb=m_p4h=m_p4l=m_inv=m_tgt=m_cycH=m_cycL=NA_VAL;
      m_bos1=m_bos2=m_indBrk=false; m_protSw=m_protSw2=m_indOrig=m_indExt=NA_VAL;
      m_lastDirSeen=0; m_recBrk=0; m_recArm=true; m_pst=0;
      o_dir=o_phase=0; o_curSH=o_curSL=o_prSH=o_prSL=NA_VAL; o_bos=o_ch=0;
      o_p4h=o_p4l=o_inv=o_tgt=o_ft=o_fb=NA_VAL; o_frzS=o_wp=o_cm=o_mf=o_compIdx=0;
      o_recBrk=0; o_recDom=0; o_reset=false; o_eLong=o_eShort=o_atExtreme=false;
     }
private:
   void Push(double h,double l,double c){ for(int i=0;i<63;i++){ m_hi[i]=m_hi[i+1]; m_lo[i]=m_lo[i+1]; m_cl[i]=m_cl[i+1]; } m_hi[63]=h; m_lo[63]=l; m_cl[63]=c; m_n++; }
   double H(int b) const { return m_hi[63-b]; }
   double L(int b) const { return m_lo[63-b]; }
   double PivotHigh(){ int L2=m_pvLen; if(m_n<2*L2+1) return NA_VAL; double cand=H(L2); for(int i=0;i<=2*L2;i++){ if(i==L2)continue; if(H(i)>=cand) return NA_VAL; } return cand; }
   double PivotLow(){ int L2=m_pvLen; if(m_n<2*L2+1) return NA_VAL; double cand=L(L2); for(int i=0;i<=2*L2;i++){ if(i==L2)continue; if(L(i)<=cand) return NA_VAL; } return cand; }
public:
   void Step(double o,double h,double l,double c)
     {
      m_phys.Step(o,h,l,c);
      Push(h,l,c);
      double atr=m_phys.atr, vel=m_phys.vel, vel1=m_phys.vel1, acc=m_phys.acc, csm=m_phys.csm;
      double eff=m_phys.eff, disp=m_phys.disp;
      bool bullImp=m_phys.bullImp, bearImp=m_phys.bearImp, bullDec=m_phys.bullDec, bearDec=m_phys.bearDec;

      //=== pivots ====================================================
      double pH=PivotHigh(), pL=PivotLow();
      if(!IsNa(pH)){ m_prSH=IsNa(m_curSH)?pH:m_curSH; m_curSH=pH; }
      if(!IsNa(pL)){ m_prSL=IsNa(m_curSL)?pL:m_curSL; m_curSL=pL; }
      double eP=NA_VAL; int eD=0;
      if(!IsNa(pH)){ eP=pH; eD=1; } else if(!IsNa(pL)){ eP=pL; eD=-1; }
      if(eD!=0){ m_prevP=m_lastP; m_prevD=m_lastD; m_lastP=eP; m_lastD=eD; }

      //=== structure =================================================
      bool bullBOS=!IsNa(m_prSH)&&c>m_prSH, bearBOS=!IsNa(m_prSL)&&c<m_prSL;
      bool bullCH=!IsNa(m_prSH)&&c>m_prSH+atr*m_chBuf, bearCH=!IsNa(m_prSL)&&c<m_prSL-atr*m_chBuf;
      bool eLong=!IsNa(pH)&&m_prevD==-1&&!IsNa(m_prevP)&&(pH-m_prevP)>atr*m_impM;
      bool eShort=!IsNa(pL)&&m_prevD==1&&!IsNa(m_prevP)&&(m_prevP-pL)>atr*m_impM;

      //=== spawn =====================================================
      bool hasCtx=m_dir!=0&&!IsNa(m_ft);
      bool flipDn=m_dir==1&&bearCH, flipUp=m_dir==-1&&bullCH;
      bool isRev=(eLong&&m_dir==-1)||(eShort&&m_dir==1)||flipUp||flipDn;
      bool spawn=(eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
      if(spawn)
        {
         int nd=eLong?1:eShort?-1:flipUp?1:-1;
         double hi=MathMax(Nz(m_lastP,c),Nz(m_prevP,c)), lo=MathMin(Nz(m_lastP,c),Nz(m_prevP,c));
         m_dir=nd; m_ft=hi; m_fb=lo; m_p4h=hi; m_p4l=lo; m_cycH=h; m_cycL=l; m_inv=(nd==1)?lo:hi;
         double rng=(!IsNa(m_prSH)&&!IsNa(m_prSL))?MathAbs(m_prSH-m_prSL):atr*5.0;
         m_tgt=(nd==1)?Nz(hi,c)+rng:Nz(lo,c)-rng;
        }
      if(m_dir==1)  m_cycH=IsNa(m_cycH)?h:MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL=IsNa(m_cycL)?l:MathMin(m_cycL,l);
      int bosOut=bullBOS?1:bearBOS?-1:0, chOut=bullCH?1:bearCH?-1:0;

      //=== recursion / inducement ====================================
      bool reset=(m_dir!=m_lastDirSeen); m_lastDirSeen=m_dir;
      if(reset){ m_bos1=false;m_bos2=false;m_protSw=NA_VAL;m_protSw2=NA_VAL;m_indOrig=NA_VAL;m_indExt=NA_VAL;m_indBrk=false; }
      if(m_dir==1&&!IsNa(pL)){ m_protSw2=m_protSw; m_protSw=pL; }
      if(m_dir==-1&&!IsNa(pH)){ m_protSw2=m_protSw; m_protSw=pH; }
      bool oppBOS=(m_dir==1&&!IsNa(m_protSw)&&c<m_protSw)||(m_dir==-1&&!IsNa(m_protSw)&&c>m_protSw);
      if(!m_bos1&&oppBOS){ m_bos1=true; m_indOrig=(m_dir==1)?Nz(m_cycH,h):Nz(m_cycL,l); }
      if(m_bos1&&!m_bos2&&oppBOS&&!IsNa(m_protSw2)&&(m_dir==1?c<m_protSw2:c>m_protSw2)) m_bos2=true;
      if(m_bos1&&m_dir==1)  m_indExt=IsNa(m_indExt)?c:MathMin(m_indExt,c);
      if(m_bos1&&m_dir==-1) m_indExt=IsNa(m_indExt)?c:MathMax(m_indExt,c);
      if(m_bos2&&!IsNa(m_indOrig)){ if(m_dir==1&&c>m_indOrig) m_indBrk=true; if(m_dir==-1&&c<m_indOrig) m_indBrk=true; }

      //=== scores ====================================================
      double convScore=MathMin(MathAbs(csm)/MathMax(atr*m_convM,1e-10)*50.0,100.0);
      double expScore=MathMin(eff/MathMax(m_effT,1e-10)*50.0+disp/MathMax(m_dispT,1e-10)*50.0,100.0);
      double absScore=(eff<m_effT*0.7&&MathAbs(vel)<MathAbs(vel1)*0.6)?60.0+convScore*0.4:convScore*0.3;
      bool momExpStrong=eff>m_effT*0.75&&(m_dir==1?vel>0:vel<0);
      bool momDecaying=(m_dir==1)?bullDec:bearDec;
      bool momCounter=(m_dir==1)?bearImp:bullImp;
      bool momExhaust=eff<m_effT*0.65&&absScore>40.0;
      bool physConvexDevel=convScore>35.0;
      bool physTransfer=convScore>48.0||absScore>40.0;
      bool physCapacityLow=absScore>45.0||eff<m_effT*0.6;

      //=== direction (origin-based) ==================================
      int wdir=!IsNa(m_inv)?(c>m_inv?1:c<m_inv?-1:m_dir):m_dir;
      bool atFlip=!IsNa(m_ft)&&!IsNa(m_fb)&&c<=m_ft&&c>=m_fb;
      bool expanding=momExpStrong||eLong||eShort||(wdir==1?bullImp:bearImp);
      bool atExtreme=wdir==1?h>=Nz(m_cycH,h):wdir==-1?l<=Nz(m_cycL,l):false;
      double extr=wdir==1?Nz(m_cycH,c):Nz(m_cycL,c);
      bool extended=!IsNa(m_inv)&&MathAbs(extr-m_inv)>atr*1.5;
      double fzMid=(!IsNa(m_ft)&&!IsNa(m_fb))?(m_ft+m_fb)/2.0:NA_VAL;
      double retrFrac=(!IsNa(fzMid)&&MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-c)/MathAbs(extr-fzMid):0.0;
      double compIdx=MathMin(100.0,MathMax(0.0,(1.0-MathMin(disp/MathMax(m_dispT,1e-10),1.0))*60.0+(1.0-MathMin(eff/MathMax(m_effT,1e-10),1.0))*40.0));

      //=== recursive transition ======================================
      bool phase2CH=(m_dir==1&&bearCH)||(m_dir==-1&&bullCH);
      if(reset||(atExtreme&&extended)){ m_recBrk=0; m_recArm=true; }
      if((m_dir==1&&!IsNa(pH))||(m_dir==-1&&!IsNa(pL))) m_recArm=true;
      if((phase2CH||oppBOS)&&m_recArm&&!atExtreme){ m_recBrk++; m_recArm=false; }
      double recDom=MathMin(100.0,MathMax(m_recBrk*(30.0-compIdx*0.15),retrFrac*80.0));
      bool transferDone=recDom>=50.0;

      //=== phase state machine 0..14 =================================
      if(reset) m_pst=0;
      if(m_dir!=0&&!reset)
        {
         if(m_pst==0&&expanding) m_pst=1;
         if(m_pst==1&&!atExtreme&&momDecaying&&physConvexDevel) m_pst=2;
         if(m_pst==2&&!atExtreme&&momCounter&&physTransfer) m_pst=3;
         if(m_pst==3&&!atExtreme&&(m_bos1||m_bos2||m_indBrk)&&physTransfer) m_pst=4;
         if(m_pst>=1&&m_pst<=7&&atExtreme&&extended) m_pst=5;
         if(m_pst==5&&!atExtreme&&(m_recBrk>=1||momExhaust)) m_pst=7;
         if(m_pst==7&&transferDone) m_pst=8;
         if(m_pst==8&&atFlip) m_pst=9;
         if(m_pst==9&&((m_dir==1&&bullImp)||(m_dir==-1&&bearImp))) m_pst=10;
         if(m_pst==10&&(oppBOS||physCapacityLow)) m_pst=11;
         if(m_pst==11&&((m_dir==1&&l<m_fb)||(m_dir==-1&&h>m_ft))) m_pst=12;
         if(m_pst==12&&((m_dir==1&&bullCH)||(m_dir==-1&&bearCH))) m_pst=13;
        }
      int phase=m_pst; if(phase==5&&m_dir==-1)phase=6; if(phase==13&&m_dir==-1)phase=14;
      double wp=m_pst==0?5.0:m_pst==1?15.0:m_pst==2?25.0:m_pst==3?33.0:m_pst==4?42.0:m_pst==5?55.0:
                m_pst==7?65.0:m_pst==8?75.0:m_pst==9?85.0:m_pst==10?90.0:m_pst==11?94.0:m_pst==12?97.0:100.0;
      double cm=MathMin(convScore,100.0);
      double mf=MathMin(MathMax(expScore,MathMax(absScore,convScore))*0.70+(m_dir!=0?30.0:0.0),100.0);
      double frzS=MathMin((eLong||eShort?50.0:0.0)+expScore*0.30+convScore*0.20,100.0);

      //=== publish ===================================================
      o_dir=wdir; o_phase=phase; o_curSH=m_curSH; o_curSL=m_curSL; o_prSH=m_prSH; o_prSL=m_prSL;
      o_bos=bosOut; o_ch=chOut; o_p4h=m_p4h; o_p4l=m_p4l; o_inv=m_inv; o_tgt=m_tgt; o_ft=m_ft; o_fb=m_fb;
      o_frzS=frzS; o_wp=wp; o_cm=cm; o_mf=mf; o_compIdx=compIdx; o_recBrk=m_recBrk; o_recDom=recDom;
      o_reset=reset; o_eLong=eLong; o_eShort=eShort; o_atExtreme=atExtreme;
     }

   //--- physics passthrough (canonical instance feeds curve framework / cognition)
   double Atr()        const { return m_phys.atr; }
   double Vel()        const { return m_phys.vel; }
   double VelPrev1()   const { return m_phys.vel1; }
   double VelPrev2()   const { return m_phys.vel2; }
   double Acc()        const { return m_phys.acc; }
   double Conv()       const { return m_phys.conv; }
   double ConvSmooth() const { return m_phys.csm; }
   double Eff()        const { return m_phys.eff; }
   double Disp()       const { return m_phys.disp; }
   bool   BullImp()    const { return m_phys.bullImp; }
   bool   BearImp()    const { return m_phys.bearImp; }
   bool   BullDec()    const { return m_phys.bullDec; }
   bool   BearDec()    const { return m_phys.bearDec; }
   bool   BullCS()     const { return m_phys.bullCS; }
   bool   BearCS()     const { return m_phys.bearCS; }
   bool   Vd70()       const { return m_phys.vd70; }
   bool   Vd50()       const { return m_phys.vd50; }
   int    Dir()        const { return m_dir; }
   double CycH()       const { return m_cycH; }
   double CycL()       const { return m_cycL; }
  };

#endif // __HYPEROMEGA_F60_STRUCTURE_MQH__
