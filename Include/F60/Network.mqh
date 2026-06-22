//+------------------------------------------------------------------+
//|                                                F60/Network.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The Invisible Network — spatial intelligence.                  |
//|     FUEngine  : f_fuPool — dominant rejection-wick (FU / flip)   |
//|       at a local extreme, swept or not, per timeframe.           |
//|     NetworkEngine : registry of FU "nodes" across MN..M5, with   |
//|       authority decay, revisit accrual, pressure / netBias, and  |
//|       nearest-node spatial lookups (consumed by FRZ / TE).       |
//|                                                                  |
//|   Nodes are the spatial memory of where price was rejected and   |
//|   has unfinished business. netBias = highest-TF active FU dir.   |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_NETWORK_MQH__
#define __HYPEROMEGA_F60_NETWORK_MQH__

#include "../Common.mqh"

//==================================================================
//= FUEngine — faithful f_fuPool (per timeframe)
//==================================================================
class FUEngine
  {
private:
   double m_wf; int m_lb;
   double m_hi[48],m_lo[48],m_cl[48],m_op[48];
   int    m_n; double m_atr; bool m_haveAtr; double m_prevClose; bool m_havePC;
   double m_tip,m_bH,m_bL,m_mid; int m_dir; bool m_have,m_conf;
public:
   double o_tip,o_mid; int o_dir; bool o_valid; double o_score;
   void Init(double wf,int lb){ m_wf=wf; m_lb=lb; Reset(); }
   void Reset()
     {
      ArrayInitialize(m_hi,0);ArrayInitialize(m_lo,0);ArrayInitialize(m_cl,0);ArrayInitialize(m_op,0);
      m_n=0;m_atr=0;m_haveAtr=false;m_prevClose=0;m_havePC=false;
      m_tip=m_bH=m_bL=m_mid=NA_VAL;m_dir=0;m_have=false;m_conf=false;
      o_tip=NA_VAL;o_mid=NA_VAL;o_dir=0;o_valid=false;o_score=0;
     }
private:
   void Push(double o,double h,double l,double c){ for(int i=0;i<47;i++){m_hi[i]=m_hi[i+1];m_lo[i]=m_lo[i+1];m_cl[i]=m_cl[i+1];m_op[i]=m_op[i+1];} m_hi[47]=h;m_lo[47]=l;m_cl[47]=c;m_op[47]=o;m_n++; }
   double H(int b) const { return m_hi[47-b]; }
   double L(int b) const { return m_lo[47-b]; }
   double HighestPrev(int len) const { double m=-DBL_MAX; for(int i=1;i<=len&&i<m_n;i++) m=MathMax(m,H(i)); return (m==-DBL_MAX)?NA_VAL:m; }
   double LowestPrev(int len)  const { double m=DBL_MAX;  for(int i=1;i<=len&&i<m_n;i++) m=MathMin(m,L(i)); return (m==DBL_MAX)?NA_VAL:m; }
   double HighestNow(int len)  const { double m=-DBL_MAX; for(int i=0;i<len&&i<m_n;i++) m=MathMax(m,H(i)); return (m==-DBL_MAX)?NA_VAL:m; }
   double LowestNow(int len)   const { double m=DBL_MAX;  for(int i=0;i<len&&i<m_n;i++) m=MathMin(m,L(i)); return (m==DBL_MAX)?NA_VAL:m; }
public:
   void Step(double o,double h,double l,double c)
     {
      Push(o,h,l,c);
      double tr=!m_havePC?(h-l):MathMax(h-l,MathMax(MathAbs(h-m_prevClose),MathAbs(l-m_prevClose)));
      if(!m_haveAtr){ m_atr=tr; m_haveAtr=true; } else m_atr=(m_atr*13.0+tr)/14.0;
      double rng=MathMax(h-l,1e-10);
      double pHi=HighestPrev(m_lb), pLo=LowestPrev(m_lb);
      double uw=(h-MathMax(o,c))/rng, lw=(MathMin(o,c)-l)/rng;
      double hNow=HighestNow(m_lb), lNow=LowestNow(m_lb);
      bool localTop=!IsNa(hNow)&&h>=hNow, localBot=!IsNa(lNow)&&l<=lNow;
      bool bear=uw>=m_wf&&((!IsNa(pHi)&&h>=pHi&&c<pHi)||(localTop&&c<o));
      bool bull=lw>=m_wf&&((!IsNa(pLo)&&l<=pLo&&c>pLo)||(localBot&&c>o));
      if(bear){ m_dir=-1;m_tip=h;m_bH=MathMax(o,c);m_bL=MathMin(o,c);m_mid=m_bH+(m_tip-m_bH)*0.5;m_have=true;m_conf=false; }
      else if(bull){ m_dir=1;m_tip=l;m_bH=MathMax(o,c);m_bL=MathMin(o,c);m_mid=m_tip+(m_bL-m_tip)*0.5;m_have=true;m_conf=false; }
      if(m_have&&m_dir==-1&&!m_conf&&c<m_bL) m_conf=true;
      if(m_have&&m_dir==1&&!m_conf&&c>m_bH) m_conf=true;
      double wk=(m_dir==-1&&m_have)?(m_tip-m_bH)/MathMax(m_atr,1e-10):(m_dir==1&&m_have)?(m_bL-m_tip)/MathMax(m_atr,1e-10):0.0;
      double score=20.0+MathMin(25.0,wk*15.0)+(m_conf?30.0:0.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0);
      o_tip=m_have?m_tip:NA_VAL; o_mid=m_mid; o_dir=m_dir; o_valid=m_have; o_score=score;
      m_prevClose=c; m_havePC=true;
     }
  };

//==================================================================
//= NetworkEngine — node registry + pressure / netBias
//==================================================================
class NetworkEngine
  {
private:
   FUEngine m_fu[7]; int m_wt[7]; double m_prevTip[7];
   double m_nPx[],m_nMid[],m_nSc[]; int m_nDir[],m_nWt[],m_nState[],m_nBar[],m_nRev[];
   int    m_barIndex; double m_ema50; bool m_haveEma;
public:
   int    netBias,pdir,eligibleNodes,nodeCount;
   double pressure,bullAuth,bearAuth;
   void Init()
     {
      for(int i=0;i<7;i++){ m_fu[i].Init(InpWickFrac,InpFuLookback); m_prevTip[i]=NA_VAL; }
      m_wt[0]=9;m_wt[1]=8;m_wt[2]=7;m_wt[3]=6;m_wt[4]=5;m_wt[5]=4;m_wt[6]=3;
      ArrayResize(m_nPx,0);ArrayResize(m_nMid,0);ArrayResize(m_nSc,0);ArrayResize(m_nDir,0);
      ArrayResize(m_nWt,0);ArrayResize(m_nState,0);ArrayResize(m_nBar,0);ArrayResize(m_nRev,0);
      m_barIndex=0;m_ema50=0;m_haveEma=false;
      netBias=pdir=eligibleNodes=nodeCount=0;pressure=bullAuth=bearAuth=0;
     }
   void StepTF(int idx,double o,double h,double l,double c){ m_fu[idx].Step(o,h,l,c); }
   void NodeAdd(double tip,double mid,int dir,double sc,int wt)
     {
      int sz=ArraySize(m_nPx);
      ArrayResize(m_nPx,sz+1);ArrayResize(m_nMid,sz+1);ArrayResize(m_nSc,sz+1);ArrayResize(m_nDir,sz+1);
      ArrayResize(m_nWt,sz+1);ArrayResize(m_nState,sz+1);ArrayResize(m_nBar,sz+1);ArrayResize(m_nRev,sz+1);
      m_nPx[sz]=tip;m_nMid[sz]=mid;m_nDir[sz]=dir;m_nSc[sz]=sc;m_nWt[sz]=wt;m_nState[sz]=0;m_nBar[sz]=m_barIndex;m_nRev[sz]=0;
      if(ArraySize(m_nPx)>InpNodeMax) ShiftFront();
     }
   void ShiftFront()
     {
      int sz=ArraySize(m_nPx); if(sz<=0) return;
      for(int i=0;i<sz-1;i++){ m_nPx[i]=m_nPx[i+1];m_nMid[i]=m_nMid[i+1];m_nSc[i]=m_nSc[i+1];m_nDir[i]=m_nDir[i+1];m_nWt[i]=m_nWt[i+1];m_nState[i]=m_nState[i+1];m_nBar[i]=m_nBar[i+1];m_nRev[i]=m_nRev[i+1]; }
      ArrayResize(m_nPx,sz-1);ArrayResize(m_nMid,sz-1);ArrayResize(m_nSc,sz-1);ArrayResize(m_nDir,sz-1);
      ArrayResize(m_nWt,sz-1);ArrayResize(m_nState,sz-1);ArrayResize(m_nBar,sz-1);ArrayResize(m_nRev,sz-1);
     }
   double Auth(int i) const { return m_nSc[i]+m_nWt[i]*4.0+m_nRev[i]*3.0; }
   double NearestNode(double price,int dir,int wantDir)   // dir:+1 above /-1 below; wantDir filters node side (0=any)
     {
      double best=NA_VAL,bestDist=DBL_MAX; int sz=ArraySize(m_nPx);
      for(int i=0;i<sz;i++)
        {
         if(m_nState[i]==2) continue;
         if(wantDir!=0 && m_nDir[i]!=wantDir) continue;
         double p=m_nPx[i];
         if(dir==1 && p<=price) continue;
         if(dir==-1 && p>=price) continue;
         double d=MathAbs(p-price); if(d<bestDist){ bestDist=d; best=p; }
        }
      return best;
     }
   void Commit(double m5close,double m5atr)
     {
      m_barIndex++;
      double a=2.0/51.0;
      if(!m_haveEma){ m_ema50=m5close; m_haveEma=true; } else m_ema50+=a*(m5close-m_ema50);
      for(int i=0;i<7;i++)
         if(m_fu[i].o_valid&&!IsNa(m_fu[i].o_tip)&&(IsNa(m_prevTip[i])||m_fu[i].o_tip!=m_prevTip[i]))
           { NodeAdd(m_fu[i].o_tip,m_fu[i].o_mid,m_fu[i].o_dir,m_fu[i].o_score,m_wt[i]); m_prevTip[i]=m_fu[i].o_tip; }
      double natr=(m5atr>0)?m5atr:MathMax(m5close*0.001,1e-10);
      int sz=ArraySize(m_nPx); bullAuth=0;bearAuth=0;eligibleNodes=0;
      for(int i=0;i<sz;i++)
        {
         if(m_nState[i]!=2)
           {
            double np=m_nPx[i]; int nd=m_nDir[i]; int age=m_barIndex-m_nBar[i];
            if(nd==-1?m5close>np:m5close<np) m_nState[i]=2;
            else { if(MathAbs(m5close-np)<natr*0.25) m_nRev[i]++; int wtn=m_nWt[i]; m_nState[i]=age>InpHistoryBars*wtn?3:age>InpDormantBars*wtn?1:0; }
           }
         if(m_nState[i]!=2){ double au=Auth(i); if(m_nDir[i]==1) bullAuth+=au; else if(m_nDir[i]==-1) bearAuth+=au; if(au>=InpAuthMin) eligibleNodes++; }
        }
      nodeCount=sz; double tot=bullAuth+bearAuth;
      pressure=tot>0?(bullAuth-bearAuth)/tot*100.0:0.0;
      pdir=pressure>12.0?1:pressure<-12.0?-1:0;
      netBias=0;
      for(int i=0;i<7;i++) if(m_fu[i].o_valid&&m_fu[i].o_dir!=0){ netBias=m_fu[i].o_dir; break; }
      if(netBias==0) netBias=m5close>m_ema50?1:m5close<m_ema50?-1:0;
     }
   bool   FUValid(int idx) const { return m_fu[idx].o_valid; }
   int    FUDir(int idx)   const { return m_fu[idx].o_dir; }
   double FUScore(int idx) const { return m_fu[idx].o_score; }
  };

#endif // __HYPEROMEGA_F60_NETWORK_MQH__
