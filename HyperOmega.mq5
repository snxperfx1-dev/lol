//+------------------------------------------------------------------+
//|                                                  HyperOmega.mq5   |
//|                                            HYPEROMEGA  (F72)      |
//|                                                                  |
//|  A continuously self-aware, multi-symbol campaign manager.       |
//|                                                                  |
//|  This is NOT a signal->trade EA. It is the layered architecture  |
//|  defined in .kiro/specs/omega-f72/spec.md:                       |
//|                                                                  |
//|    Authentic F60 substrate   (f_phys · f_se · curve tree · FU ·  |
//|                               compression · Invisible Network ·  |
//|                               FCE · fractal stack · TIE)         |
//|         ↓  (information flows UPWARD only — never bypass/recompute)|
//|    Enhanced observers        (ERF·FRZ·RIE·MCE·NE·TQE·TE·IE2·WR/DWR)|
//|         ↓                                                         |
//|    HyperIntelligence         (opportunity sets · entry families · |
//|                               dynamic context weighting)         |
//|         ↓                                                         |
//|    Risk Intelligence         (Trinity · Capital · exposure)      |
//|         ↓                                                         |
//|    Execution Intelligence    (multi-style management)            |
//|         ↓                                                         |
//|    Position Intelligence ────► feeds back to HyperIntelligence    |
//|                                                                  |
//|  LAWS (enforced): L0 Ancestry (remember every generation; enrich  |
//|  don't delete) · L4 Enrichment (observers consume authentic F60) ·|
//|  L6 Senseei is a cockpit not the brain · L9 Tool Utilization      |
//|  (arsenal, not monarchy) · L10 Continuous Awareness (perception   |
//|  never stops) · L11 Opportunity / multi-context entries.          |
//+------------------------------------------------------------------+
#property copyright "F72 HYPEROMEGA"
#property version   "72.0"
#property strict
#property description "HyperOmega — authentic F60 substrate + full V72 observer stack +"
#property description "HyperIntelligence opportunity engine. Multi-symbol campaign manager."

#include <Trade/Trade.mqh>

//==================================================================
//= INPUTS
//==================================================================
input group "=== Universe (multi-symbol) ==="
input string InpSymbols          = "";     // Symbols CSV (empty = chart symbol)
input int    InpMaxConcurrent    = 3;       // Max concurrent campaigns (portfolio)
input long   InpMagic            = 720072;  // Magic number

input group "=== F60 · Letra structure engine (f_phys / f_se) ==="
input int    InpPivotLen         = 5;       // Pivot length
input int    InpAtrLen           = 14;      // ATR length
input int    InpEffLen           = 10;      // Efficiency lookback
input double InpEffThresh        = 0.65;    // Efficiency threshold
input double InpDispThresh       = 1.5;     // Displacement ATR threshold
input double InpConvMult         = 0.01;    // Convexity ATR multiplier
input double InpImpulseAtrMult   = 1.5;     // Impulse ATR multiple
input double InpChochBufferATR   = 0.75;    // CHoCH buffer (ATR)
input bool   InpUseStrictStruct  = true;    // Strict structure (HH/HL)

input group "=== F60 · Invisible Network (FU pools) ==="
input double InpWickFrac         = 0.3;     // FU spike: min wick / range
input int    InpFuLookback       = 3;       // FU spike: structure lookback
input int    InpAuthMin          = 45;      // Min node authority (eligible)
input int    InpNodeMax          = 250;     // Max remembered nodes
input int    InpDormantBars      = 120;     // Bars until dormant
input int    InpHistoryBars      = 600;     // Bars until historical

input group "=== HyperIntelligence ==="
input int    InpMinConviction    = 55;      // Min opportunity conviction to act
input double InpMinAsymmetry     = 1.3;     // Min reward:risk*prob to act
input bool   InpAllowCountertrend= true;    // Allow counter-trend (reduced) entries
input bool   InpAllowAdds        = true;    // Allow continuation adds
input int    InpMaxAddsPerCampaign = 2;     // Max adds per campaign

input group "=== Risk / Capital (Omega inheritance) ==="
input double InpRiskPctBase      = 0.5;     // Base risk % (full conviction, full size)
input double InpRiskPctMin       = 0.10;    // Floor risk %
input double InpDailyLimitPct    = 3.0;     // Daily drawdown limit %
input double InpWeeklyLimitPct   = 8.0;     // Weekly drawdown limit %
input double InpHardLimitPct     = 15.0;    // Hard kill-switch drawdown %
input double InpMaxPortfolioRisk = 2.0;     // Max aggregate open risk %
input bool   InpCentAccount      = false;   // Cent account (equity/100)

input group "=== Execution ==="
input int    InpSlippagePoints   = 30;      // Max slippage (points)
input double InpMinStopAtr       = 0.75;    // Min stop (ATR multiple)
input bool   InpTrailStops       = true;    // Trail stop to invalidation
input bool   InpUseTargetTP      = true;    // Place TP at objective

input group "=== Diagnostics ==="
input int    InpWarmupBars       = 600;     // Warmup bars per TF
input int    InpHeartbeatSec     = 60;      // Heartbeat log interval (sec)
input bool   InpShowComment      = true;    // On-chart status comment

//==================================================================
//= MODULE: Common — math / string / logger primitives
//==================================================================
class OmegaMath
  {
public:
   static double Clamp(double v,double lo,double hi){ return MathMax(lo,MathMin(hi,v)); }
   static double Lerp(double a,double b,double t){ return a+(b-a)*t; }
   static double SafeDiv(double n,double d,double fb=0.0){ return (MathAbs(d)<1e-10)?fb:(n/d); }
   static double Pct(double v,double tot,double fb=0.0){ return SafeDiv(v,tot,fb)*100.0; }
  };

enum ENUM_OMEGA_LOG_LEVEL { LOG_DEBUG=0, LOG_INFO=1, LOG_DECISION=2, LOG_EXEC=3, LOG_WARN=4 };

class OmegaLogger
  {
private:
   static ENUM_OMEGA_LOG_LEVEL s_min;
   static string Lvl(ENUM_OMEGA_LOG_LEVEL l)
     {
      switch(l){ case LOG_DEBUG:return"DBG"; case LOG_INFO:return"INFO";
                 case LOG_DECISION:return"DECIDE"; case LOG_EXEC:return"EXEC"; case LOG_WARN:return"WARN"; }
      return "?";
     }
public:
   static void SetMin(ENUM_OMEGA_LOG_LEVEL l){ s_min=l; }
   static void Log(ENUM_OMEGA_LOG_LEVEL lv,string mod,string msg)
     {
      if((int)lv<(int)s_min) return;
      Print(StringFormat("[%s][%s][%s] %s", TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS), Lvl(lv), mod, msg));
     }
   static void Info(string m,string s){ Log(LOG_INFO,m,s); }
   static void Warn(string m,string s){ Log(LOG_WARN,m,s); }
   static void Decide(string m,string s){ Log(LOG_DECISION,m,s); }
   static void Exec(string m,string s){ Log(LOG_EXEC,m,s); }
  };
ENUM_OMEGA_LOG_LEVEL OmegaLogger::s_min = LOG_INFO;

#define NA_VAL DBL_MAX
bool   IsNa(double v){ return (v>=DBL_MAX*0.5); }
double Nz(double v,double fb=0.0){ return IsNa(v)?fb:v; }

//==================================================================
//= MODULE: F60 substrate — SEEngine (f_phys + f_se), authentic port
//==================================================================
class SEEngine
  {
private:
   int    m_pvLen,m_atrL,m_effL;
   double m_effT,m_dispT,m_convM,m_impM,m_chBuf;
   bool   m_strict;
   double m_hi[64],m_lo[64],m_cl[64],m_op[64];
   int    m_n;
   double m_emaVel,m_emaCsm,m_atr,m_prevClose;
   bool   m_haveEma,m_haveAtr,m_havePrevClose;
   double m_vel,m_vel1,m_vel2,m_acc,m_acc1,m_csm,m_csm1;
   double m_curSH,m_curSL,m_prSH,m_prSL,m_lastP,m_prevP; int m_lastD,m_prevD;
   int    m_dir;
   double m_ft,m_fb,m_p4h,m_p4l,m_inv,m_tgt,m_cycH,m_cycL;
   bool   m_bos1,m_bos2,m_indBrk;
   double m_protSw,m_protSw2,m_indOrig,m_indExt;
   int    m_lastDirSeen,m_recBrk; bool m_recArm; int m_pst;
public:
   double atr,vel,acc,conv,convSmooth,eff,disp;
   bool   bullImp,bearImp,bullDec,bearDec,bullCS,bearCS,vd70,vd50;
   int    o_dir,o_phase;
   double o_curSH,o_curSL,o_prSH,o_prSL;
   int    o_bos,o_ch;
   double o_p4h,o_p4l,o_inv,o_tgt,o_ft,o_fb,o_frzS,o_wp,o_cm,o_mf,o_compIdx;
   int    o_recBrk; double o_recDom;
   bool   o_reset,o_eLong,o_eShort,o_atExtreme;

            SEEngine(){}
   void Init(int pvLen,int atrL,int effL,double effT,double dispT,double convM,double impM,double chBuf,bool strict)
     {
      m_pvLen=pvLen;m_atrL=atrL;m_effL=effL;m_effT=effT;m_dispT=dispT;m_convM=convM;m_impM=impM;m_chBuf=chBuf;m_strict=strict;
      Reset();
     }
   void Reset()
     {
      ArrayInitialize(m_hi,0);ArrayInitialize(m_lo,0);ArrayInitialize(m_cl,0);ArrayInitialize(m_op,0);
      m_n=0;m_emaVel=m_emaCsm=m_atr=0;m_prevClose=0;m_haveEma=m_haveAtr=m_havePrevClose=false;
      m_vel=m_vel1=m_vel2=0;m_acc=m_acc1=0;m_csm=m_csm1=0;
      m_curSH=m_curSL=m_prSH=m_prSL=NA_VAL;m_lastP=m_prevP=NA_VAL;m_lastD=m_prevD=0;
      m_dir=0;m_ft=m_fb=m_p4h=m_p4l=m_inv=m_tgt=m_cycH=m_cycL=NA_VAL;
      m_bos1=m_bos2=m_indBrk=false;m_protSw=m_protSw2=m_indOrig=m_indExt=NA_VAL;
      m_lastDirSeen=0;m_recBrk=0;m_recArm=true;m_pst=0;
      ZeroOutputs();
     }
   void ZeroOutputs()
     {
      atr=vel=acc=conv=convSmooth=eff=disp=0;
      bullImp=bearImp=bullDec=bearDec=bullCS=bearCS=vd70=vd50=false;
      o_dir=o_phase=0;o_curSH=o_curSL=o_prSH=o_prSL=NA_VAL;o_bos=o_ch=0;
      o_p4h=o_p4l=o_inv=o_tgt=o_ft=o_fb=NA_VAL;o_frzS=o_wp=o_cm=o_mf=o_compIdx=0;
      o_recBrk=0;o_recDom=0;o_reset=false;o_eLong=o_eShort=o_atExtreme=false;
     }
private:
   void Push(double o,double h,double l,double c)
     {
      for(int i=0;i<63;i++){ m_hi[i]=m_hi[i+1];m_lo[i]=m_lo[i+1];m_cl[i]=m_cl[i+1];m_op[i]=m_op[i+1]; }
      m_hi[63]=h;m_lo[63]=l;m_cl[63]=c;m_op[63]=o;m_n++;
     }
   double H(int b) const { return m_hi[63-b]; }
   double L(int b) const { return m_lo[63-b]; }
   double C(int b) const { return m_cl[63-b]; }
   double PivotHigh()
     {
      int L2=m_pvLen; if(m_n<2*L2+1) return NA_VAL; double cand=H(L2);
      for(int i=0;i<=2*L2;i++){ if(i==L2)continue; if(H(i)>=cand) return NA_VAL; } return cand;
     }
   double PivotLow()
     {
      int L2=m_pvLen; if(m_n<2*L2+1) return NA_VAL; double cand=L(L2);
      for(int i=0;i<=2*L2;i++){ if(i==L2)continue; if(L(i)<=cand) return NA_VAL; } return cand;
     }
public:
   void Step(double o,double h,double l,double c)
     {
      Push(o,h,l,c);
      double tr = !m_havePrevClose ? (h-l) : MathMax(h-l,MathMax(MathAbs(h-m_prevClose),MathAbs(l-m_prevClose)));
      if(!m_haveAtr){ m_atr=tr; m_haveAtr=true; } else m_atr=(m_atr*(m_atrL-1)+tr)/m_atrL;
      atr=m_atr;
      double dC = m_havePrevClose ? (c-m_prevClose) : 0.0;
      double aE = 2.0/4.0;
      if(!m_haveEma){ m_emaVel=dC; m_haveEma=true; } else m_emaVel=m_emaVel+aE*(dC-m_emaVel);
      m_vel2=m_vel1; m_vel1=m_vel; m_vel=m_emaVel;
      m_acc1=m_acc; m_acc=m_vel-m_vel1;
      double convNow=m_acc-m_acc1; m_csm1=m_csm;
      m_emaCsm=(m_n<=1)?convNow:(m_emaCsm+aE*(convNow-m_emaCsm)); m_csm=m_emaCsm;
      vel=m_vel; acc=m_acc; conv=convNow; convSmooth=m_csm;
      double mv=(m_n>m_effL)?MathAbs(c-C(m_effL)):0.0;
      double ps=0.0; for(int i=0;i<m_effL && i+1<m_n;i++) ps+=MathAbs(C(i)-C(i+1));
      eff=(ps>0.0)?mv/ps:0.0; disp=(h-l)/MathMax(m_atr,1e-10);
      bullImp=eff>m_effT && m_vel>m_vel1 && m_acc>0 && c>o && disp>m_dispT;
      bearImp=eff>m_effT && m_vel<m_vel1 && m_acc<0 && c<o && disp>m_dispT;
      bullDec=MathAbs(m_acc)<MathAbs(m_acc1)*0.8 && m_vel>0;
      bearDec=MathAbs(m_acc)<MathAbs(m_acc1)*0.8 && m_vel<0;
      double cth=m_atr*m_convM;
      bullCS=(m_csm>cth)&&(m_csm1<=cth); bearCS=(m_csm<-cth)&&(m_csm1>=-cth);
      vd70=MathAbs(m_vel)<MathAbs(m_vel1)*0.7; vd50=MathAbs(m_vel)<MathAbs(m_vel1)*0.5;
      double pH=PivotHigh(),pL=PivotLow();
      if(!IsNa(pH)){ m_prSH=IsNa(m_curSH)?pH:m_curSH; m_curSH=pH; }
      if(!IsNa(pL)){ m_prSL=IsNa(m_curSL)?pL:m_curSL; m_curSL=pL; }
      double eP=NA_VAL; int eD=0;
      if(!IsNa(pH)){ eP=pH; eD=1; } else if(!IsNa(pL)){ eP=pL; eD=-1; }
      if(eD!=0){ m_prevP=m_lastP; m_prevD=m_lastD; m_lastP=eP; m_lastD=eD; }
      bool bullBOS=!IsNa(m_prSH)&&c>m_prSH, bearBOS=!IsNa(m_prSL)&&c<m_prSL;
      bool bullCH=!IsNa(m_prSH)&&c>m_prSH+m_atr*m_chBuf, bearCH=!IsNa(m_prSL)&&c<m_prSL-m_atr*m_chBuf;
      bool eLong=!IsNa(pH)&&m_prevD==-1&&!IsNa(m_prevP)&&(pH-m_prevP)>m_atr*m_impM;
      bool eShort=!IsNa(pL)&&m_prevD==1&&!IsNa(m_prevP)&&(m_prevP-pL)>m_atr*m_impM;
      bool hasCtx=m_dir!=0&&!IsNa(m_ft);
      bool flipDn=m_dir==1&&bearCH, flipUp=m_dir==-1&&bullCH;
      bool isRev=(eLong&&m_dir==-1)||(eShort&&m_dir==1)||flipUp||flipDn;
      bool spawn=(eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
      if(spawn)
        {
         int nd=eLong?1:eShort?-1:flipUp?1:-1;
         double hi=MathMax(Nz(m_lastP,c),Nz(m_prevP,c)), lo=MathMin(Nz(m_lastP,c),Nz(m_prevP,c));
         m_dir=nd; m_ft=hi; m_fb=lo; m_p4h=hi; m_p4l=lo; m_cycH=h; m_cycL=l; m_inv=(nd==1)?lo:hi;
         double rng=(!IsNa(m_prSH)&&!IsNa(m_prSL))?MathAbs(m_prSH-m_prSL):m_atr*5.0;
         m_tgt=(nd==1)?Nz(hi,c)+rng:Nz(lo,c)-rng;
        }
      if(m_dir==1)  m_cycH=IsNa(m_cycH)?h:MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL=IsNa(m_cycL)?l:MathMin(m_cycL,l);
      int bosOut=bullBOS?1:bearBOS?-1:0, chOut=bullCH?1:bearCH?-1:0;
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
      double convScore=MathMin(MathAbs(m_csm)/MathMax(m_atr*m_convM,1e-10)*50.0,100.0);
      double expScore=MathMin(eff/MathMax(m_effT,1e-10)*50.0+disp/MathMax(m_dispT,1e-10)*50.0,100.0);
      double absScore=(eff<m_effT*0.7&&MathAbs(m_vel)<MathAbs(m_vel1)*0.6)?60.0+convScore*0.4:convScore*0.3;
      bool momExpStrong=eff>m_effT*0.75&&(m_dir==1?m_vel>0:m_vel<0);
      bool momDecaying=(m_dir==1)?bullDec:bearDec;
      bool momCounter=(m_dir==1)?bearImp:bullImp;
      bool momExhaust=eff<m_effT*0.65&&absScore>40.0;
      bool physConvexDevel=convScore>35.0;
      bool physTransfer=convScore>48.0||absScore>40.0;
      bool physCapacityLow=absScore>45.0||eff<m_effT*0.6;
      int wdir=!IsNa(m_inv)?(c>m_inv?1:c<m_inv?-1:m_dir):m_dir;
      bool atFlip=!IsNa(m_ft)&&!IsNa(m_fb)&&c<=m_ft&&c>=m_fb;
      bool expanding=momExpStrong||eLong||eShort||(wdir==1?bullImp:bearImp);
      bool atExtreme=wdir==1?h>=Nz(m_cycH,h):wdir==-1?l<=Nz(m_cycL,l):false;
      double extr=wdir==1?Nz(m_cycH,c):Nz(m_cycL,c);
      bool extended=!IsNa(m_inv)&&MathAbs(extr-m_inv)>m_atr*1.5;
      double fzMid=(!IsNa(m_ft)&&!IsNa(m_fb))?(m_ft+m_fb)/2.0:NA_VAL;
      double retrFrac=(!IsNa(fzMid)&&MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-c)/MathAbs(extr-fzMid):0.0;
      double compIdx=MathMin(100.0,MathMax(0.0,(1.0-MathMin(disp/MathMax(m_dispT,1e-10),1.0))*60.0+(1.0-MathMin(eff/MathMax(m_effT,1e-10),1.0))*40.0));
      bool phase2CH=(m_dir==1&&bearCH)||(m_dir==-1&&bullCH);
      if(reset||(atExtreme&&extended)){ m_recBrk=0; m_recArm=true; }
      if((m_dir==1&&!IsNa(pH))||(m_dir==-1&&!IsNa(pL))) m_recArm=true;
      if((phase2CH||oppBOS)&&m_recArm&&!atExtreme){ m_recBrk++; m_recArm=false; }
      double recDom=MathMin(100.0,MathMax(m_recBrk*(30.0-compIdx*0.15),retrFrac*80.0));
      bool transferDone=recDom>=50.0;
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
      o_dir=wdir; o_phase=phase; o_curSH=m_curSH; o_curSL=m_curSL; o_prSH=m_prSH; o_prSL=m_prSL;
      o_bos=bosOut; o_ch=chOut; o_p4h=m_p4h; o_p4l=m_p4l; o_inv=m_inv; o_tgt=m_tgt; o_ft=m_ft; o_fb=m_fb;
      o_frzS=frzS; o_wp=wp; o_cm=cm; o_mf=mf; o_compIdx=compIdx; o_recBrk=m_recBrk; o_recDom=recDom;
      o_reset=reset; o_eLong=eLong; o_eShort=eShort; o_atExtreme=atExtreme;
      m_prevClose=c; m_havePrevClose=true;
     }
   double velPrev1() const { return m_vel1; }
   double velPrev2() const { return m_vel2; }
   int    dir()      const { return m_dir; }
   double cycH()     const { return m_cycH; }
   double cycL()     const { return m_cycL; }
  };


//==================================================================
//= MODULE: F60 substrate — FUEngine (f_fuPool), authentic port
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
   void Push(double o,double h,double l,double c)
     { for(int i=0;i<47;i++){m_hi[i]=m_hi[i+1];m_lo[i]=m_lo[i+1];m_cl[i]=m_cl[i+1];m_op[i]=m_op[i+1];} m_hi[47]=h;m_lo[47]=l;m_cl[47]=c;m_op[47]=o;m_n++; }
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
//= MODULE: F60 substrate — Invisible Network (node registry)
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
   //--- nearest live node above/below price (for FRZ / TE spatial intelligence)
   double NearestNode(double price,int dir,int wantDir) // dir: +1 above, -1 below; wantDir filters node side
     {
      double best=NA_VAL,bestDist=DBL_MAX; int sz=ArraySize(m_nPx);
      for(int i=0;i<sz;i++)
        {
         if(m_nState[i]==2) continue;
         if(wantDir!=0 && m_nDir[i]!=wantDir) continue;
         double p=m_nPx[i];
         if(dir==1 && p<=price) continue;
         if(dir==-1 && p>=price) continue;
         double d=MathAbs(p-price);
         if(d<bestDist){ bestDist=d; best=p; }
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
   bool FUValid(int idx) const { return m_fu[idx].o_valid; }
   int  FUDir(int idx)   const { return m_fu[idx].o_dir; }
   double FUScore(int idx) const { return m_fu[idx].o_score; }
  };

//==================================================================
//= F60 phase strings + helpers
//==================================================================
string V60PhaseStr(int c)
  {
   switch(c){ case 1:return"Expansion"; case 2:return"Expansion Pre-Convexity"; case 3:return"Expansion Induction";
              case 4:return"Expansion Liquidity"; case 5:return"New High"; case 6:return"New Low"; case 7:return"Transition";
              case 8:return"Retracement"; case 9:return"HTF Flip Zone"; case 10:return"Induction"; case 11:return"Liquidation";
              case 12:return"Terminal Curve"; case 13:return"Demand Return"; case 14:return"Supply Return"; }
   return "Point 4 Origin";
  }
bool   Has(string s,string sub){ return StringFind(s,sub)>=0; }
int    DirByOrigin(double origin,int fallback,double close){ if(IsNa(origin)) return fallback; return close>origin?1:close<origin?-1:fallback; }


//==================================================================
//= F60State — the aggregated substrate snapshot the observers read
//==================================================================
//  TF index: 0=M1 1=M3 2=M5(canonical) 3=M15 4=H1 5=H4 6=D1 7=W1 8=MN
//==================================================================
#define TF_COUNT 9
#define TF_CANON 2
struct F60State
  {
   // per-TF curve readouts
   int    tfDir[9], tfPhase[9], tfBos[9], tfCh[9], tfCompBars[9];
   double tfWp[9], tfComp[9], tfMf[9], tfFrz[9];
   double tfInv[9], tfTgt[9], tfFt[9], tfFb[9], tfCycH[9], tfCycL[9], tfP4h[9], tfP4l[9];
   double tfCompPersist[9];
   bool   tfELong[9], tfEShort[9], tfAtExt[9];
   string tfPhaseStr[9];
   // canonical physics (M5 == f_phys)
   double close, high, low, open, atr;
   double vel, acc, conv, convSmooth, eff, disp, velPrev2;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;
   // Invisible Network
   int    netBias, pdir, eligibleNodes, nodeCount;
   double pressure, bullAuth, bearAuth;
   double nodeAbove, nodeBelow;   // nearest live node above / below price
   // derived F60
   int    fractalStackDir, structBias, ownerTf, ownerDir, recursiveDepth;
   double fractalStackScore, recursiveDom;
   double chainVitality;
   // FCE (Force/Curve energy engine)
   double fce_residual, fce_convexity, fce_maturity, fce_budget, fce_travel, fce_progress;
   // TIE
   int    timeDir; double timeAlign, timeConflict;
  };

//==================================================================
//= MODULE: F60 substrate driver — 9-TF curve ladder + network +
//=         curve-tree ownership · chain vitality · compression
//=         persistence · FCE · fractal stack · TIE  (per symbol)
//==================================================================
class SubstrateEngine
  {
private:
   string          m_sym;
   SEEngine        m_se[9];
   ENUM_TIMEFRAMES m_seTf[9];
   datetime        m_seLast[9];
   NetworkEngine   m_net;
   ENUM_TIMEFRAMES m_fuTf[7];
   datetime        m_fuLast[7];
   double          m_m5o,m_m5h,m_m5l,m_m5c,m_m5atr;
   // persistent derived
   int             m_structBias;
   double          m_compPersist[9]; int m_compBars[9];
   double          m_chainVit;
public:
   void Init(string sym)
     {
      m_sym=sym;
      m_seTf[0]=PERIOD_M1; m_seTf[1]=PERIOD_M3; m_seTf[2]=PERIOD_M5; m_seTf[3]=PERIOD_M15;
      m_seTf[4]=PERIOD_H1; m_seTf[5]=PERIOD_H4; m_seTf[6]=PERIOD_D1; m_seTf[7]=PERIOD_W1; m_seTf[8]=PERIOD_MN1;
      for(int i=0;i<9;i++){ m_se[i].Init(InpPivotLen,InpAtrLen,InpEffLen,InpEffThresh,InpDispThresh,InpConvMult,InpImpulseAtrMult,InpChochBufferATR,InpUseStrictStruct); m_seLast[i]=0; m_compPersist[i]=0; m_compBars[i]=0; }
      m_fuTf[0]=PERIOD_MN1; m_fuTf[1]=PERIOD_W1; m_fuTf[2]=PERIOD_D1; m_fuTf[3]=PERIOD_H4; m_fuTf[4]=PERIOD_H1; m_fuTf[5]=PERIOD_M15; m_fuTf[6]=PERIOD_M5;
      m_net.Init(); for(int i=0;i<7;i++) m_fuLast[i]=0;
      m_structBias=0; m_chainVit=0; m_m5o=m_m5h=m_m5l=m_m5c=m_m5atr=0;
     }
   void Warmup(int bars)
     {
      for(int e=0;e<9;e++)
        {
         ENUM_TIMEFRAMES tf=m_seTf[e]; int avail=Bars(m_sym,tf); int n=MathMin(bars,avail-2);
         for(int sh=n; sh>=1; sh--) m_se[e].Step(iOpen(m_sym,tf,sh),iHigh(m_sym,tf,sh),iLow(m_sym,tf,sh),iClose(m_sym,tf,sh));
         m_seLast[e]=iTime(m_sym,tf,0);
        }
      for(int e=0;e<7;e++)
        {
         ENUM_TIMEFRAMES tf=m_fuTf[e]; int avail=Bars(m_sym,tf); int n=MathMin(bars,avail-2);
         for(int sh=n; sh>=1; sh--) m_net.StepTF(e,iOpen(m_sym,tf,sh),iHigh(m_sym,tf,sh),iLow(m_sym,tf,sh),iClose(m_sym,tf,sh));
         m_fuLast[e]=iTime(m_sym,tf,0);
        }
      m_m5o=iOpen(m_sym,PERIOD_M5,1); m_m5h=iHigh(m_sym,PERIOD_M5,1); m_m5l=iLow(m_sym,PERIOD_M5,1); m_m5c=iClose(m_sym,PERIOD_M5,1); m_m5atr=m_se[2].atr;
      if(m_m5c>0) m_net.Commit(m_m5c,m_m5atr);
     }
   //--- advance closed bars; returns true if any TF stepped
   bool DriveBars()
     {
      bool any=false, canon=false;
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
               m_se[e].Step(o,h,l,c); any=true;
               if(e==2){ m_m5o=o;m_m5h=h;m_m5l=l;m_m5c=c;m_m5atr=m_se[2].atr; canon=true; }
              }
            m_seLast[e]=t0;
           }
        }
      if(canon) m_net.Commit(m_m5c,m_m5atr);
      return any;
     }
   double NearestNodeAbove(double price,int wantDir){ return m_net.NearestNode(price,1,wantDir); }
   double NearestNodeBelow(double price,int wantDir){ return m_net.NearestNode(price,-1,wantDir); }
   double CanonAtr() const { return (m_m5atr>0)?m_m5atr:0.0; }

   //--- fill the aggregated F60 snapshot
   void Compute(F60State &s)
     {
      double close=m_m5c, high=m_m5h, low=m_m5l, atr=(m_m5atr>0?m_m5atr:MathMax(close*0.001,1e-10));
      s.close=close; s.high=high; s.low=low; s.open=m_m5o; s.atr=atr;
      int sb=0,ss=0;
      for(int i=0;i<9;i++)
        {
         s.tfDir[i]=DirByOrigin(m_se[i].o_inv,m_se[i].o_dir,close);
         s.tfPhase[i]=m_se[i].o_phase; s.tfPhaseStr[i]=V60PhaseStr(m_se[i].o_phase);
         s.tfWp[i]=m_se[i].o_wp; s.tfComp[i]=m_se[i].o_compIdx; s.tfMf[i]=m_se[i].o_mf; s.tfFrz[i]=m_se[i].o_frzS;
         s.tfInv[i]=m_se[i].o_inv; s.tfTgt[i]=m_se[i].o_tgt; s.tfFt[i]=m_se[i].o_ft; s.tfFb[i]=m_se[i].o_fb;
         s.tfCycH[i]=m_se[i].cycH(); s.tfCycL[i]=m_se[i].cycL(); s.tfP4h[i]=m_se[i].o_p4h; s.tfP4l[i]=m_se[i].o_p4l;
         s.tfBos[i]=m_se[i].o_bos; s.tfCh[i]=m_se[i].o_ch; s.tfELong[i]=m_se[i].o_eLong; s.tfEShort[i]=m_se[i].o_eShort; s.tfAtExt[i]=m_se[i].o_atExtreme;
         double cp=m_se[i].o_compIdx; m_compPersist[i]+=0.2*(cp-m_compPersist[i]);
         if(cp>55.0) m_compBars[i]++; else m_compBars[i]=0;
         s.tfCompPersist[i]=m_compPersist[i]; s.tfCompBars[i]=m_compBars[i];
         if(s.tfDir[i]==1) sb++; else if(s.tfDir[i]==-1) ss++;
        }
      // canonical physics
      s.vel=m_se[2].vel; s.acc=m_se[2].acc; s.conv=m_se[2].conv; s.convSmooth=m_se[2].convSmooth;
      s.eff=m_se[2].eff; s.disp=m_se[2].disp; s.velPrev2=m_se[2].velPrev2();
      s.bullImp=m_se[2].bullImp; s.bearImp=m_se[2].bearImp; s.bullDec=m_se[2].bullDec; s.bearDec=m_se[2].bearDec;
      s.bullCS=m_se[2].bullCS; s.bearCS=m_se[2].bearCS; s.vd70=m_se[2].vd70; s.vd50=m_se[2].vd50;
      // network
      s.netBias=m_net.netBias; s.pressure=m_net.pressure; s.pdir=m_net.pdir; s.eligibleNodes=m_net.eligibleNodes;
      s.bullAuth=m_net.bullAuth; s.bearAuth=m_net.bearAuth; s.nodeCount=m_net.nodeCount;
      s.nodeAbove=m_net.NearestNode(close,1,0); s.nodeBelow=m_net.NearestNode(close,-1,0);
      // fractal stack
      s.fractalStackDir=sb>ss?1:ss>sb?-1:0; s.fractalStackScore=MathMax(sb,ss)/9.0*100.0;
      // structBias (M5 strict HH/HL)
      double sh=m_se[2].o_curSH,sl=m_se[2].o_curSL,psh=m_se[2].o_prSH,psl=m_se[2].o_prSL;
      bool isHH=!IsNa(sh)&&!IsNa(psh)&&sh>psh, isLH=!IsNa(sh)&&!IsNa(psh)&&sh<psh;
      bool isHL=!IsNa(sl)&&!IsNa(psl)&&sl>psl, isLL=!IsNa(sl)&&!IsNa(psl)&&sl<psl;
      if(InpUseStrictStruct){ if(isHH&&isHL) m_structBias=1; if(isLH&&isLL) m_structBias=-1; }
      else { if(m_se[2].o_bos==1) m_structBias=1; if(m_se[2].o_bos==-1) m_structBias=-1; }
      s.structBias=m_structBias;
      // curve-tree ownership: highest TF mid-progress with strongest model fit
      int owner=-1; double bestMf=-1;
      for(int i=8;i>=0;i--) if(s.tfDir[i]!=0 && s.tfWp[i]>=15.0 && s.tfWp[i]<=92.0 && s.tfMf[i]>bestMf){ bestMf=s.tfMf[i]; owner=i; }
      if(owner<0) for(int i=8;i>=0;i--) if(s.tfDir[i]!=0){ owner=i; break; }
      s.ownerTf=owner; s.ownerDir=owner>=0?s.tfDir[owner]:0;
      s.recursiveDepth=m_se[2].o_recBrk; s.recursiveDom=m_se[2].o_recDom;
      // chain vitality
      double netAlign=(m_net.netBias==m_structBias&&m_structBias!=0)?1.0:0.0;
      double rawVit=OmegaMath::Clamp(s.tfMf[2]*0.4+MathMin(s.eligibleNodes*8.0,40.0)+netAlign*20.0,0.0,100.0);
      m_chainVit+=0.2*(rawVit-m_chainVit); s.chainVitality=m_chainVit;
      // FCE
      double cvx=MathMin(MathAbs(s.convSmooth)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);
      double obsExp=MathMin((s.eff>InpEffThresh?s.eff*60.0:s.eff*30.0)+(s.bullImp||s.bearImp?30.0:0.0),100.0);
      double obsDecay=MathMin((s.bullDec||s.bearDec?40.0:0.0)+(s.vd70?30.0:0.0)+cvx*0.4,100.0);
      double expEnergy=MathMin(obsExp*0.5+(s.bullImp||s.bearImp?30.0:0.0)+s.eff*20.0,100.0);
      s.fce_residual=MathMax(0.0,expEnergy-obsDecay); s.fce_convexity=cvx;
      s.fce_maturity=owner>=0?s.tfWp[owner]:s.tfWp[2];
      double otgt=owner>=0?s.tfTgt[owner]:s.tfTgt[2], oinv=owner>=0?s.tfInv[owner]:s.tfInv[2];
      if(!IsNa(otgt)&&!IsNa(oinv)&&MathAbs(otgt-oinv)>1e-10){ double tr=OmegaMath::Clamp(MathAbs(close-oinv)/MathAbs(otgt-oinv)*100.0,0.0,100.0); s.fce_travel=tr; s.fce_budget=MathMax(0.0,100.0-tr); }
      else { s.fce_travel=50.0; s.fce_budget=50.0; }
      s.fce_progress=s.fce_maturity;
      // TIE — bias of canonical close vs cycle opens
      double mnO=iOpen(m_sym,PERIOD_MN1,0),wO=iOpen(m_sym,PERIOD_W1,0),dO=iOpen(m_sym,PERIOD_D1,0),h4O=iOpen(m_sym,PERIOD_H4,0),h1O=iOpen(m_sym,PERIOD_H1,0);
      int tBull=(close>mnO?1:0)+(close>wO?1:0)+(close>dO?1:0)+(close>h4O?1:0)+(close>h1O?1:0);
      int tBear=(close<mnO?1:0)+(close<wO?1:0)+(close<dO?1:0)+(close<h4O?1:0)+(close<h1O?1:0);
      s.timeDir=tBull>tBear?1:tBear>tBull?-1:0;
      s.timeAlign=(tBull+tBear)>0?MathMax(tBull,tBear)/(double)(tBull+tBear)*100.0:50.0;
      s.timeConflict=100.0-s.timeAlign;
     }
  };


//==================================================================
//= ObserverBus — outputs of the full V72 observer stack.
//= Per L4 each observer is FED by authentic F60 substrate values
//= (FCE residual, curve ownership, chain vitality, compression
//= persistence, Invisible Network nodes) — NOT by EMA/ATR proxies.
//==================================================================
struct ObserverBus
  {
   // ERF — unresolved / residual energy
   double erf_residual; int erf_unresolvedDir; double erf_exhaustScore; int erf_exhaustDir;
   // FRZ — supply/demand geometry · attractors
   double frz_supplyDistAtr, frz_demandDistAtr, frz_attractor, frz_attractorScore, frz_approachQ; int frz_dir;
   // RIE — rotation / control transfer
   double rie_rotationProb; int rie_transferDir;
   // MCE — MTF consensus
   int    mce_dir; double mce_score, mce_conflict;
   // NE — narrative
   int    ne_dir; double ne_maturity; string ne_story;
   // TQE — trade qualification (veto gate)
   double tqe_quality;
   // TE — targets
   double te_target, te_quality, te_travelAtr; int te_dir;
   // IE2 — invalidation
   double ie2_inv, ie2_roomAtr;
   // WR/DWR — wave registry / depth
   int    wr_depth; bool wr_recursive;
  };

//==================================================================
//= MODULE: Observers — compute the entire V72 stack from F60State
//==================================================================
class Observers
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      double atr=MathMax(s.atr,1e-10), close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //--- ERF (fed by FCE residual + compression persistence + chain vitality + curve maturity)
      o.erf_residual = OmegaMath::Clamp(s.fce_residual*0.55 + s.chainVitality*0.20
                       + s.tfCompPersist[own]*0.15 + (100.0-s.fce_maturity)*0.10, 0.0, 100.0);
      o.erf_unresolvedDir = od;     // unfinished business carries the owner's direction
      // exhaustion: high maturity + decaying momentum + low budget + at extreme
      double exh = OmegaMath::Clamp((s.fce_maturity>70.0?40.0:0.0) + ((s.bullDec||s.bearDec)?20.0:0.0)
                   + (s.fce_budget<25.0?25.0:0.0) + (s.tfAtExt[own]?15.0:0.0), 0.0, 100.0);
      o.erf_exhaustScore = exh; o.erf_exhaustDir = od;

      //--- FRZ (fed by Invisible Network nodes + curve ownership + flip zones + attractor)
      double sup = s.nodeAbove;
      double dem = s.nodeBelow;
      double oft=s.tfFt[own], ofb=s.tfFb[own];
      if(!IsNa(oft) && oft>close && (IsNa(sup)||oft<sup)) sup=oft;
      if(!IsNa(ofb) && ofb<close && (IsNa(dem)||ofb>dem)) dem=ofb;
      o.frz_supplyDistAtr = !IsNa(sup)? (sup-close)/atr : 99.0;
      o.frz_demandDistAtr = !IsNa(dem)? (close-dem)/atr : 99.0;
      // attractor = owner objective if present else nearest aligned node ahead
      double attr = s.tfTgt[own];
      if(IsNa(attr)) attr = (od==1)? sup : dem;
      o.frz_attractor = attr;
      o.frz_attractorScore = OmegaMath::Clamp(s.fce_budget*0.5 + s.chainVitality*0.3 + (s.eligibleNodes>0?20.0:0.0),0.0,100.0);
      o.frz_dir = od;
      // approach quality: are we approaching a demand (for longs) / supply (for shorts) cleanly?
      double approachDist = (od==1)? o.frz_demandDistAtr : (od==-1)? o.frz_supplyDistAtr : 99.0;
      o.frz_approachQ = OmegaMath::Clamp(100.0 - approachDist*30.0, 0.0, 100.0);

      //--- RIE (fed by ownership transfer + recursion + participant interference/compression)
      bool ownerVsStruct = (od!=0 && s.structBias!=0 && od!=s.structBias);
      double rot = OmegaMath::Clamp(s.recursiveDom*0.5 + (ownerVsStruct?25.0:0.0)
                   + (s.tfCompPersist[TF_CANON]>60.0?15.0:0.0) + ((s.bullCS||s.bearCS)?15.0:0.0), 0.0, 100.0);
      o.rie_rotationProb = rot;
      o.rie_transferDir = s.bullCS?1:s.bearCS?-1:(s.recursiveDom>50.0? -od : 0);

      //--- MCE (fed by fractal stack + curve map + TIE)  — not naive % alignment
      o.mce_dir = s.fractalStackDir;
      o.mce_score = OmegaMath::Clamp(s.fractalStackScore*0.6 + s.timeAlign*0.4, 0.0, 100.0);
      // conflict: owner direction disagreeing with the stack / time
      o.mce_conflict = OmegaMath::Clamp((od!=0&&s.fractalStackDir!=0&&od!=s.fractalStackDir?50.0:0.0)
                       + s.timeConflict*0.5, 0.0, 100.0);

      //--- NE (fed by owner phase lineage + campaign ownership + chain vitality)
      o.ne_dir = od; o.ne_maturity = s.fce_maturity;
      string ph = (own>=0)? s.tfPhaseStr[own] : s.tfPhaseStr[TF_CANON];
      string story;
      if(Has(ph,"Expansion")&&!Has(ph,"Induction")&&!Has(ph,"Liquidity")) story="EXPANSION";
      else if(Has(ph,"Induction")||Has(ph,"Liquidity")) story="DISTRIBUTION";
      else if(Has(ph,"Retracement")||Has(ph,"Flip")) story="ACCUMULATION";
      else if(Has(ph,"Liquidation")||Has(ph,"Terminal")) story="LIQUIDATION";
      else if(Has(ph,"Demand Return")||Has(ph,"Supply Return")) story="CAMPAIGN TRANSITION";
      else if(Has(ph,"New High")||Has(ph,"New Low")) story="DELIVERY";
      else story="BALANCE";
      o.ne_story=story;

      //--- TQE (fed by ERF + FRZ convergence + chain vitality + network pressure + interference)
      double q = OmegaMath::Clamp(s.chainVitality*0.30 + o.frz_attractorScore*0.20
                 + MathAbs(s.pressure)*0.20 + o.frz_approachQ*0.15
                 + (s.eligibleNodes>0?MathMin(s.eligibleNodes*3.0,15.0):0.0), 0.0, 100.0);
      // penalise high MCE conflict + late maturity
      q -= o.mce_conflict*0.20 + (s.fce_maturity>90.0?15.0:0.0);
      o.tqe_quality = OmegaMath::Clamp(q,0.0,100.0);

      //--- TE (fed by network path nodes + FCE trajectory + owner objective + attractor)
      double tgt = s.tfTgt[own];
      double pathNode = (od==1)? s.nodeAbove : (od==-1)? s.nodeBelow : NA_VAL;
      if(IsNa(tgt) && !IsNa(pathNode)) tgt=pathNode;
      // if a node sits between price and tgt in trade direction, it is the nearer realistic objective
      if(!IsNa(tgt)&&!IsNa(pathNode)){ if(od==1 && pathNode>close && pathNode<tgt) tgt=pathNode; if(od==-1 && pathNode<close && pathNode>tgt) tgt=pathNode; }
      o.te_target = tgt; o.te_dir = od;
      o.te_travelAtr = (!IsNa(tgt))? MathAbs(tgt-close)/atr : 0.0;
      o.te_quality = OmegaMath::Clamp(s.fce_budget*0.5 + o.frz_attractorScore*0.3 + s.chainVitality*0.2, 0.0, 100.0);

      //--- IE2 (fed by recursive origin / parent curve / owner invalidation / p4)
      double inv = s.tfInv[own];
      if(IsNa(inv)) inv = (od==1)? s.tfP4l[own] : s.tfP4h[own];
      // widen to the parent (next higher) curve invalidation if available and more protective
      if(own<8 && !IsNa(s.tfInv[own+1])){ double pinv=s.tfInv[own+1]; if(od==1 && pinv<Nz(inv,pinv)) inv=pinv; if(od==-1 && pinv>Nz(inv,pinv)) inv=pinv; }
      o.ie2_inv = inv;
      o.ie2_roomAtr = (!IsNa(inv))? MathAbs(close-inv)/atr : InpMinStopAtr;

      //--- WR / DWR (wave registry / depth)
      o.wr_depth = s.recursiveDepth;
      o.wr_recursive = (s.recursiveDom>=50.0);
     }
  };


//==================================================================
//= TF helpers
//==================================================================
ENUM_TIMEFRAMES TfEnum(int i)
  {
   switch(i){ case 0:return PERIOD_M1; case 1:return PERIOD_M3; case 2:return PERIOD_M5; case 3:return PERIOD_M15;
              case 4:return PERIOD_H1; case 5:return PERIOD_H4; case 6:return PERIOD_D1; case 7:return PERIOD_W1; case 8:return PERIOD_MN1; }
   return PERIOD_M5;
  }
string TfName(int i)
  {
   switch(i){ case 0:return"M1"; case 1:return"M3"; case 2:return"M5"; case 3:return"M15"; case 4:return"H1";
              case 5:return"H4"; case 6:return"D1"; case 7:return"W1"; case 8:return"MN"; }
   return "?";
  }

//==================================================================
//= HyperIntelligence — Opportunity / entry families / weighting
//==================================================================
enum EntryFamily
  {
   FAM_NONE=0, FAM_COMPRESSION, FAM_ROTATION, FAM_NETWORK, FAM_CONTINUATION,
   FAM_EXHAUSTION, FAM_FLIPZONE, FAM_LIQUIDATION, FAM_EXPANSION
  };
enum MgmtStyle { MGMT_NORMAL=0, MGMT_AGGRESSIVE, MGMT_SCALP, MGMT_RUNNER, MGMT_COUNTERTREND };

string FamilyName(EntryFamily f)
  {
   switch(f){ case FAM_COMPRESSION:return"Compression"; case FAM_ROTATION:return"Rotation"; case FAM_NETWORK:return"Network";
              case FAM_CONTINUATION:return"Continuation"; case FAM_EXHAUSTION:return"Exhaustion"; case FAM_FLIPZONE:return"FlipZone";
              case FAM_LIQUIDATION:return"Liquidation"; case FAM_EXPANSION:return"Expansion"; }
   return "None";
  }
string MgmtName(MgmtStyle m)
  {
   switch(m){ case MGMT_AGGRESSIVE:return"AGGR"; case MGMT_SCALP:return"SCALP"; case MGMT_RUNNER:return"RUNNER"; case MGMT_COUNTERTREND:return"CTREND"; }
   return "NORMAL";
  }

struct Opportunity
  {
   EntryFamily     family;
   ENUM_TIMEFRAMES tf;
   int             tfIdx, direction;
   double          conviction, entry, target, invalidation, asymmetry, stopAtr;
   MgmtStyle       mgmt;
   bool            valid;
   string          label;
  };

class HyperIntelligence
  {
private:
   static MgmtStyle PickMgmt(EntryFamily fam, bool countertrend, const F60State &s)
     {
      if(countertrend) return MGMT_COUNTERTREND;
      if(fam==FAM_EXHAUSTION) return MGMT_SCALP;
      if((fam==FAM_CONTINUATION||fam==FAM_EXPANSION) && s.fce_budget>55.0) return MGMT_RUNNER;
      if(fam==FAM_LIQUIDATION||fam==FAM_FLIPZONE) return MGMT_AGGRESSIVE;
      return MGMT_NORMAL;
     }
   static Opportunity Make(EntryFamily fam,int tfIdx,int dir,double entry,double target,double inv,
                            double conv,const F60State &s)
     {
      Opportunity op;
      op.family=fam; op.tfIdx=tfIdx; op.tf=TfEnum(tfIdx); op.direction=dir;
      op.entry=entry; op.target=target; op.invalidation=inv; op.label=FamilyName(fam);
      bool ct = (dir!=0 && s.fractalStackDir!=0 && dir!=s.fractalStackDir);
      if(ct) conv*=0.78;                                  // counter-trend penalty
      op.conviction=OmegaMath::Clamp(conv,0.0,100.0);
      op.mgmt=PickMgmt(fam,ct,s);
      double atr=MathMax(s.atr,1e-10);
      double riskAtr = (!IsNa(inv))? MathAbs(entry-inv)/atr : InpMinStopAtr;
      if(riskAtr<InpMinStopAtr) riskAtr=InpMinStopAtr;
      double rewardAtr = (!IsNa(target))? MathAbs(target-entry)/atr : riskAtr*1.5;
      // counter-trend & scalp tighten reward expectation
      if(op.mgmt==MGMT_SCALP||op.mgmt==MGMT_COUNTERTREND) rewardAtr=MathMin(rewardAtr, riskAtr*2.0);
      op.stopAtr=riskAtr;
      op.asymmetry=(rewardAtr/riskAtr)*(op.conviction/100.0);
      bool ctOk = (!ct) || InpAllowCountertrend;
      op.valid = dir!=0 && ctOk && op.conviction>=(double)InpMinConviction && op.asymmetry>=InpMinAsymmetry;
      return op;
     }
public:
   //--- scan all entry families across timeframes, return the best opportunity
   static bool Scan(const F60State &s, const ObserverBus &o, Opportunity &best)
     {
      Opportunity cand[9]; int n=0;
      double close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;
      // ---- global context modifiers (commander, not dictator) ----
      double conflictPenalty = o.mce_conflict*0.25;
      double tqeGate = (o.tqe_quality<35.0)? (o.tqe_quality/35.0) : 1.0;   // soft gate
      bool   tqeVeto = (o.tqe_quality<20.0);                               // hard veto of new entries

      // 1) CONTINUATION — chain vitality · campaign ownership · curve progression
      if(od!=0 && s.tfWp[own]>=18.0 && s.tfWp[own]<=85.0)
        {
         double conv = s.chainVitality*0.40 + s.fractalStackScore*0.25 + s.fce_budget*0.20 + o.te_quality*0.15 - conflictPenalty;
         cand[n++]=Make(FAM_CONTINUATION,own,od,close,o.te_target,o.ie2_inv,conv*tqeGate,s);
        }
      // 2) EXPANSION — compression release · FU progression · curve-tree inheritance
      if(s.structBias!=0 && (s.bullImp||s.bearImp))
        {
         int dir=(s.bullImp?1:-1);
         double conv = s.tfMf[TF_CANON]*0.35 + s.fce_residual*0.30 + s.fractalStackScore*0.20 + (s.eligibleNodes>0?15.0:0.0) - conflictPenalty;
         cand[n++]=Make(FAM_EXPANSION,TF_CANON,dir,close,o.te_target,o.ie2_inv,conv*tqeGate,s);
        }
      // 3) COMPRESSION RELEASE — compression persistence · FU chains · FCE
      {
       int relIdx=TF_CANON; double bestCp=0; for(int i=1;i<=4;i++){ if(s.tfCompPersist[i]>bestCp){ bestCp=s.tfCompPersist[i]; relIdx=i; } }
       if(bestCp>58.0 && s.tfCompBars[relIdx]>=3 && (s.bullCS||s.bearCS||s.bullImp||s.bearImp))
         {
          int dir=(s.bullCS||s.bullImp)?1:-1;
          double conv = bestCp*0.40 + s.fce_residual*0.30 + s.tfMf[relIdx]*0.20 + (s.eligibleNodes>0?10.0:0.0) - conflictPenalty;
          cand[n++]=Make(FAM_COMPRESSION,relIdx,dir,close,o.te_target,o.ie2_inv,conv*tqeGate,s);
         }
      }
      // 4) ROTATION — RIE · ownership transfer · MCE  (often counter-trend)
      if(o.rie_rotationProb>55.0 && o.rie_transferDir!=0)
        {
         int dir=o.rie_transferDir;
         double tgt = (dir==1)? s.nodeAbove : s.nodeBelow;
         double conv = o.rie_rotationProb*0.50 + s.recursiveDom*0.25 + (s.structBias==dir?15.0:0.0) - conflictPenalty*0.5;
         cand[n++]=Make(FAM_ROTATION,TF_CANON,dir,close,tgt,o.ie2_inv,conv*tqeGate,s);
        }
      // 5) NETWORK — Invisible Network · node pressure · attractors
      if(s.eligibleNodes>0 && MathAbs(s.pressure)>25.0 && s.pdir!=0)
        {
         int dir=s.pdir;
         double tgt=(dir==1)? s.nodeAbove : s.nodeBelow;
         double conv = MathAbs(s.pressure)*0.45 + o.frz_attractorScore*0.30 + MathMin(s.eligibleNodes*4.0,25.0) - conflictPenalty;
         cand[n++]=Make(FAM_NETWORK,TF_CANON,dir,close,tgt,o.ie2_inv,conv*tqeGate,s);
        }
      // 6) FLIP-ZONE — FRZ · supply/demand geometry · approach quality
      if(od!=0 && o.frz_approachQ>55.0)
        {
         bool inZone = !IsNa(s.tfFt[own])&&!IsNa(s.tfFb[own])&&close<=s.tfFt[own]&&close>=s.tfFb[own];
         double conv = o.frz_approachQ*0.40 + o.frz_attractorScore*0.30 + s.chainVitality*0.20 + (inZone?10.0:0.0) - conflictPenalty;
         cand[n++]=Make(FAM_FLIPZONE,own,od,close,o.te_target,o.ie2_inv,conv*tqeGate,s);
        }
      // 7) LIQUIDATION — attack sequence · wave registry · phase engine
      {
       string ph=s.tfPhaseStr[TF_CANON];
       if((Has(ph,"Liquidation")||Has(ph,"Terminal")||Has(ph,"Demand Return")||Has(ph,"Supply Return")) && od!=0)
         {
          double conv = 50.0 + (o.wr_recursive?20.0:0.0) + s.chainVitality*0.20 + s.fce_residual*0.15 - conflictPenalty;
          cand[n++]=Make(FAM_LIQUIDATION,TF_CANON,od,close,o.te_target,o.ie2_inv,conv*tqeGate,s);
         }
      }
      // 8) EXHAUSTION — residual energy · convexity · maturity  (fade, counter-trend)
      if(o.erf_exhaustScore>60.0 && od!=0)
        {
         int dir=-od;                                  // fade the exhausted leg
         double tgt=(dir==1)? s.nodeAbove : s.nodeBelow;
         if(IsNa(tgt)) tgt=(dir==1)? close+s.atr*2.0 : close-s.atr*2.0;
         double conv = o.erf_exhaustScore*0.55 + s.fce_convexity*0.25 + (s.tfAtExt[own]?15.0:0.0) - conflictPenalty*0.5;
         cand[n++]=Make(FAM_EXHAUSTION,own,dir,close,tgt,o.ie2_inv,conv*tqeGate,s);
        }

      // ---- selection: best valid asymmetry; TQE hard veto blocks all ----
      best.valid=false; double bestA=-1.0;
      if(tqeVeto) return false;
      for(int i=0;i<n;i++)
         if(cand[i].valid && cand[i].asymmetry>bestA){ bestA=cand[i].asymmetry; best=cand[i]; }
      return best.valid;
     }
  };


//==================================================================
//= MODULE: Risk — Trinity (per symbol) + Capital (account) + sizing
//=         Omega's inheritance. Risk is the MASTER OVERRIDE.
//==================================================================
struct Trinity   // fed FROM F60 + observers (the organism's vitals)
  {
   double life;        // residual energy — is the story still alive?
   double stability;   // MTF/narrative coherence
   double confidence;  // self-trust
   void Feed(const F60State &s, const ObserverBus &o)
     {
      life       = OmegaMath::Clamp(o.erf_residual*0.5 + s.chainVitality*0.5, 0.0, 100.0);
      stability  = OmegaMath::Clamp(s.fractalStackScore*0.5 + s.timeAlign*0.3 + (100.0-o.mce_conflict)*0.2, 0.0, 100.0);
      confidence = OmegaMath::Clamp(o.tqe_quality*0.5 + s.chainVitality*0.3 + stability*0.2, 0.0, 100.0);
     }
  };

enum ENUM_CAP_STATE { CAP_HEALTHY=0, CAP_WARNING=1, CAP_RESTRICTED=2, CAP_SUSPENDED=3 };
string CapName(ENUM_CAP_STATE s){ switch(s){ case CAP_HEALTHY:return"HEALTHY"; case CAP_WARNING:return"WARNING"; case CAP_RESTRICTED:return"RESTRICTED"; case CAP_SUSPENDED:return"SUSPENDED"; } return"?"; }

class OmegaCapital
  {
private:
   double m_base,m_day,m_week,m_peak,m_d,m_w,m_h; datetime m_dayS,m_weekS; ENUM_CAP_STATE m_state;
   static datetime DayStart(datetime t){ MqlDateTime dt; TimeToStruct(t,dt); dt.hour=0;dt.min=0;dt.sec=0; return StructToTime(dt); }
   static datetime WeekStart(datetime t){ datetime d=DayStart(t); MqlDateTime dt; TimeToStruct(d,dt); int dow=(int)dt.day_of_week; int back=(dow==0)?6:(dow-1); return d-(datetime)((long)back*86400); }
   double Eq() const { double e=AccountInfoDouble(ACCOUNT_EQUITY); return InpCentAccount?e/100.0:e; }
public:
   void Init(double d,double w,double h){ m_d=d;m_w=w;m_h=h; double e=Eq(); m_base=m_peak=m_day=m_week=e; m_dayS=DayStart(TimeCurrent()); m_weekS=WeekStart(TimeCurrent()); m_state=CAP_HEALTHY; }
   void Update()
     {
      double e=Eq(); datetime now=TimeCurrent();
      datetime nd=DayStart(now); if(nd!=m_dayS){ m_dayS=nd; m_day=e; }
      datetime nw=WeekStart(now); if(nw!=m_weekS){ m_weekS=nw; m_week=e; }
      if(e>m_peak) m_peak=e;
      double ddD=OmegaMath::Pct(m_day-e,m_day), ddW=OmegaMath::Pct(m_week-e,m_week), ddH=OmegaMath::Pct(m_base-e,m_base);
      ENUM_CAP_STATE prev=m_state;
      if(ddH>=m_h) m_state=CAP_SUSPENDED;
      else if(ddW>=m_w||ddD>=m_d) m_state=CAP_RESTRICTED;
      else if(ddD>=m_d*0.66||ddW>=m_w*0.66) m_state=CAP_WARNING;
      else m_state=CAP_HEALTHY;
      if(m_state!=prev) OmegaLogger::Warn("CAPITAL",StringFormat("%s -> %s (ddD=%.2f ddW=%.2f ddH=%.2f)",CapName(prev),CapName(m_state),ddD,ddW,ddH));
     }
   ENUM_CAP_STATE State() const { return m_state; }
   bool BlocksEntries() const { return m_state==CAP_RESTRICTED||m_state==CAP_SUSPENDED; }
   bool RequiresFlat()  const { return m_state==CAP_SUSPENDED; }
   double DDd() const { return OmegaMath::Pct(m_day-Eq(),m_day); }
   double DDw() const { return OmegaMath::Pct(m_week-Eq(),m_week); }
   double DDh() const { return OmegaMath::Pct(m_base-Eq(),m_base); }
   double Throttle() const
     {
      double dt=OmegaMath::Clamp(1.0-DDd()/m_d,0.0,1.0), wt=OmegaMath::Clamp(1.0-DDw()/m_w,0.0,1.0), ht=OmegaMath::Clamp(1.0-DDh()/m_h,0.0,1.0);
      return MathMin(dt,MathMin(wt,ht));
     }
  };

class OmegaRisk
  {
public:
   static double NormalizeLots(string sym,double lots)
     {
      double mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX), st=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
      if(st<=0) st=0.01; if(mn<=0) mn=st;
      lots=MathFloor(lots/st+1e-9)*st; if(lots<mn) lots=mn; if(mx>0&&lots>mx) lots=mx;
      return NormalizeDouble(lots,2);
     }
   static double LotsFor(string sym,double stopPoints,double riskPct,double conviction,double throttle,double exposureBudgetPct)
     {
      if(stopPoints<=0) return 0.0;
      double pct=OmegaMath::Clamp(riskPct,InpRiskPctMin,100.0);
      pct*=OmegaMath::Clamp(conviction,0.0,1.0);
      pct*=OmegaMath::Clamp(throttle,0.0,1.0);
      pct=MathMin(pct,MathMax(exposureBudgetPct,0.0));        // exposure cap
      if(pct<=0.0) return 0.0;
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney=eq*pct/100.0;
      double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE), pt=SymbolInfoDouble(sym,SYMBOL_POINT);
      if(ts<=0) ts=pt; if(tv<=0||ts<=0||pt<=0) return 0.0;
      double vpp=tv*(pt/ts), lossPerLot=stopPoints*vpp;
      if(lossPerLot<=0) return 0.0;
      return NormalizeLots(sym, riskMoney/lossPerLot);
     }
   //--- aggregate open risk % across all our positions (portfolio exposure)
   static double OpenRiskPct(long magic)
     {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return 0.0; double risk=0.0;
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         string sym=PositionGetString(POSITION_SYMBOL);
         double sl=PositionGetDouble(POSITION_SL); if(sl<=0) continue;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN), vol=PositionGetDouble(POSITION_VOLUME);
         double pt=SymbolInfoDouble(sym,SYMBOL_POINT), tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
         if(ts<=0) ts=pt; if(pt<=0||tv<=0) continue;
         double vpp=tv*(pt/ts); double pts=MathAbs(entry-sl)/pt;
         risk+=pts*vpp*vol;
        }
      return OmegaMath::Pct(risk,eq);
     }
  };

//==================================================================
//= MODULE: Position Intelligence — post-entry continuous verdict.
//=         Reads the curve tree / chain / narrative (does NOT
//=         recompute). Feeds back into the decision loop (L10).
//==================================================================
struct Campaign
  {
   bool   active; int dir; double entry, initialSL, initTarget, origVol;
   EntryFamily family; MgmtStyle mgmt; bool partialDone; int adds; ulong ticket;
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
      // --- is the campaign still progressing / alive? (curve tree + chain) ---
      bool ownerFlipped = (s.ownerDir!=0 && s.ownerDir!=dir);
      bool structFlipped= (s.structBias!=0 && s.structBias!=dir);
      bool lowVitality  = (s.chainVitality<35.0);
      bool resolvedAgainst = (o.erf_exhaustDir==dir && o.erf_exhaustScore>70.0);   // our leg exhausted
      bool phaseTerminal = Has(s.tfPhaseStr[TF_CANON],"Liquidation")||Has(s.tfPhaseStr[TF_CANON],"Terminal");
      bool rotationAgainst = (o.rie_rotationProb>70.0 && o.rie_transferDir!=0 && o.rie_transferDir!=dir);

      // --- EXIT: narrative changed against us with conviction ---
      if((ownerFlipped && lowVitality) || (structFlipped && rotationAgainst) ||
         (resolvedAgainst && phaseTerminal))
        { v.doExit=true; v.reason="campaign invalidated (owner/struct flip · exhaustion · terminal)"; return; }

      // --- REVERSE flag: strong opposite rotation while we are exhausted ---
      if(rotationAgainst && resolvedAgainst)
        { v.doReverse=true; v.reason="control transfer against position"; }

      // --- PARTIAL: first objective reached or maturity high + budget low ---
      if(!c.partialDone)
        {
         bool tgtHit = (!IsNa(c.initTarget)) && ((dir==1 && curPrice>=c.initTarget) || (dir==-1 && curPrice<=c.initTarget));
         bool matureFade = (s.fce_maturity>82.0 && s.fce_budget<25.0);
         if(tgtHit || matureFade){ v.doPartial=true; v.reason="first objective / maturity — bank partial"; }
        }
      // --- TRAIL: pull stop to live invalidation if it improves protection ---
      if(InpTrailStops && !IsNa(o.ie2_inv))
        { v.doTrail=true; v.newSL=o.ie2_inv; }
     }
  };

//==================================================================
//= MODULE: Execution — CTrade router (multi-style management)
//==================================================================
class Execution
  {
private:
   CTrade m_trade; string m_sym; long m_magic; int m_digits; double m_point; long m_stops;
public:
   void Init(string sym,long magic)
     {
      m_sym=sym; m_magic=magic;
      m_digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS); m_point=SymbolInfoDouble(sym,SYMBOL_POINT);
      m_stops=(long)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
      m_trade.SetExpertMagicNumber(magic); m_trade.SetDeviationInPoints(InpSlippagePoints); m_trade.SetTypeFillingBySymbol(sym);
     }
   double NormPx(double p){ return NormalizeDouble(p,m_digits); }
   double MinStopDist(){ return (double)m_stops*m_point; }
   int CountActive(){ int n=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; n++; } return n; }
   int NetDir(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; return PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1; } return 0; }
   double TotalVolume(){ double v=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; v+=PositionGetDouble(POSITION_VOLUME); } return v; }
   void CloseAll(string why)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         if(m_trade.PositionClose(tk)) OmegaLogger::Exec("EXEC",StringFormat("%s close #%I64u · %s",m_sym,tk,why)); }
     }
   void ClosePartial(double fraction,string why)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         double vol=PositionGetDouble(POSITION_VOLUME); double part=OmegaRisk::NormalizeLots(m_sym,vol*fraction);
         double mn=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN); if(part<mn||vol-part<mn) continue;
         if(m_trade.PositionClosePartial(tk,part)) OmegaLogger::Exec("EXEC",StringFormat("%s partial %.2f #%I64u · %s",m_sym,part,tk,why)); }
     }
   void ModifySL(double newSL)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1; double curSL=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
         double px=(dir==1)?SymbolInfoDouble(m_sym,SYMBOL_BID):SymbolInfoDouble(m_sym,SYMBOL_ASK);
         bool improve=(dir==1)?(curSL==0.0||newSL>curSL):(curSL==0.0||newSL<curSL);
         bool side=(dir==1)?(newSL<px):(newSL>px);
         double md=MinStopDist(); if(md>0&&MathAbs(px-newSL)<md) continue;
         if(improve&&side) m_trade.PositionModify(tk,NormPx(newSL),tp); }
     }
   //--- open an opportunity (sizing by conviction · throttle · exposure; SL/TP by mgmt)
   bool Open(const Opportunity &op,double atr,double convFrac,double throttle,double exposureBudgetPct,ulong &ticketOut,double &volOut)
     {
      ticketOut=0; volOut=0; if(op.direction==0||atr<=0) return false;
      double ask=SymbolInfoDouble(m_sym,SYMBOL_ASK), bid=SymbolInfoDouble(m_sym,SYMBOL_BID);
      double entry=(op.direction==1)?ask:bid;
      // stop
      double stop;
      if(!IsNa(op.invalidation)&&((op.direction==1&&op.invalidation<entry)||(op.direction==-1&&op.invalidation>entry))) stop=op.invalidation;
      else stop=(op.direction==1)?entry-InpMinStopAtr*atr:entry+InpMinStopAtr*atr;
      double md=MinStopDist();
      if(md>0){ if(op.direction==1&&(entry-stop)<md) stop=entry-md; if(op.direction==-1&&(stop-entry)<md) stop=entry+md; }
      stop=NormPx(stop);
      double stopPts=MathAbs(entry-stop)/m_point; if(stopPts<=0) return false;
      // target by mgmt style
      double tp=0.0;
      if(InpUseTargetTP)
        {
         double riskDist=MathAbs(entry-stop);
         double tgt=op.target;
         if(op.mgmt==MGMT_SCALP||op.mgmt==MGMT_COUNTERTREND){ double cap=(op.direction==1)?entry+riskDist*1.8:entry-riskDist*1.8; tgt=IsNa(tgt)?cap:(op.direction==1?MathMin(tgt,cap):MathMax(tgt,cap)); }
         if(op.mgmt==MGMT_RUNNER) tgt=op.target;     // let it run (may be NA -> no TP)
         if(!IsNa(tgt)&&((op.direction==1&&tgt>entry)||(op.direction==-1&&tgt<entry)))
           { if(md<=0||MathAbs(tgt-entry)>=md) tp=NormPx(tgt); }
        }
      // conviction & style-scaled risk
      double riskPct=InpRiskPctBase*OmegaMath::Clamp(convFrac,0.0,1.0);
      if(op.mgmt==MGMT_COUNTERTREND) riskPct*=0.5;
      else if(op.mgmt==MGMT_SCALP)   riskPct*=0.7;
      else if(op.mgmt==MGMT_AGGRESSIVE) riskPct*=1.15;
      double lots=OmegaRisk::LotsFor(m_sym,stopPts,riskPct,1.0,throttle,exposureBudgetPct);
      if(lots<=0){ OmegaLogger::Warn("EXEC",m_sym+" sizing=0 (exposure/throttle) — skip"); return false; }
      string cmt=StringFormat("HO %s/%s %s",FamilyName(op.family),MgmtName(op.mgmt),TfName(op.tfIdx));
      bool ok=(op.direction==1)?m_trade.Buy(lots,m_sym,0.0,stop,tp,cmt):m_trade.Sell(lots,m_sym,0.0,stop,tp,cmt);
      if(ok){ ticketOut=m_trade.ResultOrder(); volOut=lots;
              OmegaLogger::Decide("HYPER",StringFormat("%s OPEN %s %s/%s lots=%.2f conv=%.0f asym=%.2f SL=%.5f TP=%.5f",
                 m_sym,op.direction==1?"LONG":"SHORT",FamilyName(op.family),MgmtName(op.mgmt),lots,op.conviction,op.asymmetry,stop,tp)); }
      else OmegaLogger::Warn("EXEC",StringFormat("%s OPEN failed ret=%d",m_sym,m_trade.ResultRetcode()));
      return ok;
     }
  };


//==================================================================
//= MODULE: SymbolEngine — ONE symbol's full continuous loop
//=   substrate -> observers -> trinity -> opportunities ->
//=   risk/exposure -> execution -> position intelligence -> feedback
//==================================================================
class SymbolEngine
  {
private:
   string           m_sym;
   SubstrateEngine  m_sub;
   Execution        m_exec;
   F60State         m_f60;
   ObserverBus      m_obs;
   Trinity          m_trinity;
   Campaign         m_camp;
   Opportunity      m_best;
   bool             m_haveScan, m_primed;
public:
   void Init(string sym)
     {
      m_sym=sym; m_sub.Init(sym); m_exec.Init(sym,InpMagic);
      m_camp.active=false; m_camp.adds=0; m_camp.partialDone=false; m_camp.dir=0; m_camp.ticket=0;
      m_haveScan=false; m_primed=false;
     }
   void Warmup(int bars){ m_sub.Warmup(bars); m_sub.Compute(m_f60); Observers::Update(m_f60,m_obs); m_trinity.Feed(m_f60,m_obs); m_primed=true; }
   string Sym() const { return m_sym; }
   bool   HasPosition(){ return m_exec.CountActive()>0; }
   double Mid(){ return (SymbolInfoDouble(m_sym,SYMBOL_ASK)+SymbolInfoDouble(m_sym,SYMBOL_BID))/2.0; }

   void Record(const Opportunity &op,ulong tk,double vol)
     {
      m_camp.active=true; m_camp.dir=op.direction; m_camp.entry=op.entry; m_camp.initialSL=op.invalidation;
      m_camp.initTarget=op.target; m_camp.origVol=vol; m_camp.family=op.family; m_camp.mgmt=op.mgmt;
      m_camp.partialDone=false; m_camp.adds=0; m_camp.ticket=tk;
     }

   void ManagePosition()
     {
      if(m_exec.CountActive()==0){ m_camp.active=false; return; }
      PositionVerdict v; PositionIntelligence::Evaluate(m_f60,m_obs,m_camp,Mid(),v);
      if(v.doExit){ m_exec.CloseAll(v.reason); m_camp.active=false; return; }
      if(v.doPartial && !m_camp.partialDone){ m_exec.ClosePartial(0.5,v.reason); m_camp.partialDone=true; }
      if(v.doTrail && !IsNa(v.newSL)) m_exec.ModifySL(v.newSL);
     }

   void ConsiderEntry(OmegaCapital &cap,int concurrentActive,double exposureBudget)
     {
      if(!m_haveScan || !m_best.valid) return;
      if(cap.BlocksEntries()) return;
      int posDir=m_exec.NetDir();
      Opportunity op=m_best;
      // reverse: holding opposite to a strong opportunity
      if(posDir!=0 && op.direction!=0 && op.direction!=posDir)
        {
         if(op.conviction>=(double)InpMinConviction+10.0 && op.asymmetry>=InpMinAsymmetry*1.2)
           { m_exec.CloseAll("reverse -> "+FamilyName(op.family)); m_camp.active=false; posDir=0; }
         else return;
        }
      double atr=m_sub.CanonAtr(); if(atr<=0) return;
      if(posDir==0)
        {
         if(concurrentActive>=InpMaxConcurrent) return;
         if(exposureBudget<=0.05) return;
         ulong tk; double vol;
         if(m_exec.Open(op,atr,op.conviction/100.0,cap.Throttle(),exposureBudget,tk,vol)) Record(op,tk,vol);
        }
      else if(posDir==op.direction)
        {
         if(InpAllowAdds && m_camp.adds<InpMaxAddsPerCampaign && (op.family==FAM_CONTINUATION||op.family==FAM_EXPANSION)
            && op.conviction>=(double)InpMinConviction+5.0 && exposureBudget>0.05)
           {
            ulong tk; double vol;
            if(m_exec.Open(op,atr,op.conviction/100.0*0.7,cap.Throttle(),exposureBudget,tk,vol)) m_camp.adds++;
           }
        }
     }

   void Process(OmegaCapital &cap,int concurrentActive,double exposureBudget)
     {
      bool stepped=m_sub.DriveBars();
      if(stepped)
        {
         m_sub.Compute(m_f60);
         Observers::Update(m_f60,m_obs);
         m_trinity.Feed(m_f60,m_obs);
         m_haveScan=HyperIntelligence::Scan(m_f60,m_obs,m_best);
        }
      if(cap.RequiresFlat()){ if(m_exec.CountActive()>0){ m_exec.CloseAll("Capital SUSPENDED"); m_camp.active=false; } return; }
      ManagePosition();                                   // continuous post-entry intelligence (every tick)
      if(stepped) ConsiderEntry(cap,concurrentActive,exposureBudget);
     }

   string Diag()
     {
      string fam = (m_haveScan&&m_best.valid)? StringFormat("%s/%s %s conv=%.0f asym=%.2f",
                     FamilyName(m_best.family),MgmtName(m_best.mgmt),m_best.direction==1?"L":m_best.direction==-1?"S":"-",
                     m_best.conviction,m_best.asymmetry) : "no qualified opportunity";
      return StringFormat("%-9s own=%s%d stk=%d net=%d prs=%.0f vit=%.0f res=%.0f mat=%.0f | %s | pos=%d",
              m_sym, TfName(m_f60.ownerTf>=0?m_f60.ownerTf:TF_CANON), m_f60.ownerDir,
              m_f60.fractalStackDir, m_f60.netBias, m_f60.pressure, m_f60.chainVitality,
              m_f60.fce_residual, m_f60.fce_maturity, fam, m_exec.CountActive());
     }
   void Trinity3(double &l,double &s,double &c){ l=m_trinity.life; s=m_trinity.stability; c=m_trinity.confidence; }
  };

//==================================================================
//= MODULE: Portfolio — multi-symbol container + cross-symbol caps
//==================================================================
class Portfolio
  {
private:
   SymbolEngine m_eng[32]; int m_count;
public:
   void Init()
     {
      m_count=0;
      string list=InpSymbols; StringTrimLeft(list); StringTrimRight(list);
      if(list=="")
        { m_eng[0].Init(_Symbol); m_count=1; }
      else
        {
         string parts[]; int k=StringSplit(list,',',parts);
         for(int i=0;i<k && m_count<32;i++)
           {
            string sym=parts[i]; StringTrimLeft(sym); StringTrimRight(sym);
            if(sym=="") continue;
            if(!SymbolSelect(sym,true)){ OmegaLogger::Warn("PORT","cannot select "+sym); continue; }
            m_eng[m_count].Init(sym); m_count++;
           }
         if(m_count==0){ m_eng[0].Init(_Symbol); m_count=1; }
        }
      for(int i=0;i<m_count;i++) m_eng[i].Warmup(InpWarmupBars);
      OmegaLogger::Info("PORT",StringFormat("Tracking %d symbol(s)",m_count));
     }
   int CountActiveCampaigns(){ int n=0; for(int i=0;i<m_count;i++) if(m_eng[i].HasPosition()) n++; return n; }
   void Update(OmegaCapital &cap)
     {
      double openRisk=OmegaRisk::OpenRiskPct(InpMagic);
      double budget=MathMax(0.0,InpMaxPortfolioRisk-openRisk);
      for(int i=0;i<m_count;i++)
        {
         int concurrent=CountActiveCampaigns();
         m_eng[i].Process(cap,concurrent,budget);
         openRisk=OmegaRisk::OpenRiskPct(InpMagic);             // refresh after any fill
         budget=MathMax(0.0,InpMaxPortfolioRisk-openRisk);
        }
     }
   string Diag()
     {
      string s="";
      for(int i=0;i<m_count && i<8;i++) s+=m_eng[i].Diag()+"\n";
      return s;
     }
   int Count(){ return m_count; }
  };

//==================================================================
//= EA lifecycle
//==================================================================
OmegaCapital g_capital;
Portfolio    g_port;
datetime     g_lastBeat=0;

int OnInit()
  {
   OmegaLogger::SetMin(LOG_INFO);
   OmegaLogger::Info("EA",StringFormat("HYPEROMEGA v72 · %s · multi-context campaign manager",_Symbol));
   g_capital.Init(InpDailyLimitPct,InpWeeklyLimitPct,InpHardLimitPct);
   g_port.Init();
   EventSetTimer(MathMax(5,InpHeartbeatSec));
   OmegaLogger::Info("EA","Initialized · F60 substrate + full V72 observers + HyperIntelligence opportunity engine.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason){ EventKillTimer(); Comment(""); OmegaLogger::Info("EA",StringFormat("Deinit reason=%d",reason)); }

void OnTick()
  {
   g_capital.Update();
   g_port.Update(g_capital);
   if(InpShowComment)
     {
      string cm=StringFormat("HYPEROMEGA · %d sym · campaigns=%d/%d\nCapital: %s · thr=%.2f · ddD=%.2f%% ddW=%.2f%% openRisk=%.2f%%\n%s",
                  g_port.Count(), g_port.CountActiveCampaigns(), InpMaxConcurrent,
                  CapName(g_capital.State()), g_capital.Throttle(), g_capital.DDd(), g_capital.DDw(), OmegaRisk::OpenRiskPct(InpMagic),
                  g_port.Diag());
      Comment(cm);
     }
  }

void OnTimer()
  {
   datetime now=TimeCurrent();
   if(g_lastBeat==0||(now-g_lastBeat)>=InpHeartbeatSec)
     {
      g_lastBeat=now;
      OmegaLogger::Info("HEARTBEAT",StringFormat("cap=%s thr=%.2f campaigns=%d openRisk=%.2f%%",
         CapName(g_capital.State()),g_capital.Throttle(),g_port.CountActiveCampaigns(),OmegaRisk::OpenRiskPct(InpMagic)));
     }
  }
//+------------------------------------------------------------------+
