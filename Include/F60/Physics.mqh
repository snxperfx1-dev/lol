//+------------------------------------------------------------------+
//|                                                F60/Physics.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   f_phys — the authentic price-physics primitives. The deepest   |
//|   sensory layer of the substrate. Computes, per just-closed bar  |
//|   of any timeframe (sequential 'var'-style evolution like Pine): |
//|     ATR (Wilder RMA) · velocity/acceleration/convexity (EMA-3) · |
//|     efficiency · displacement · impulse/decay/convexity-shift.   |
//|                                                                  |
//|   Reusable: SEEngine, FUEngine and the curve framework all stand |
//|   on this. No higher layer recomputes these (Law L2).            |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_PHYSICS_MQH__
#define __HYPEROMEGA_F60_PHYSICS_MQH__

#include "../Common.mqh"

class PhysicsCore
  {
private:
   int    m_atrL, m_effL;
   double m_effT, m_dispT, m_convM;
   double m_cl[64];                       // close ring (newest at end)
   int    m_n;
   double m_emaVel, m_emaCsm, m_atr, m_prevClose;
   bool   m_haveEma, m_haveAtr, m_havePC;
public:
   //--- physics outputs (read by structure / curve layers)
   double atr, vel, vel1, vel2, acc, acc1, conv, csm, csm1, eff, disp;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;

   void Init(int atrL,int effL,double effT,double dispT,double convM)
     {
      m_atrL=atrL; m_effL=effL; m_effT=effT; m_dispT=dispT; m_convM=convM;
      Reset();
     }
   void Reset()
     {
      ArrayInitialize(m_cl,0); m_n=0;
      m_emaVel=m_emaCsm=m_atr=m_prevClose=0;
      m_haveEma=m_haveAtr=m_havePC=false;
      atr=vel=vel1=vel2=acc=acc1=conv=csm=csm1=eff=disp=0;
      bullImp=bearImp=bullDec=bearDec=bullCS=bearCS=vd70=vd50=false;
     }
private:
   void PushClose(double c){ for(int i=0;i<63;i++) m_cl[i]=m_cl[i+1]; m_cl[63]=c; m_n++; }
   double C(int back) const { return m_cl[63-back]; }
public:
   //--- process one just-closed bar of this timeframe
   void Step(double o,double h,double l,double c)
     {
      PushClose(c);
      //=== ATR (Wilder RMA of true range) =========================
      double tr = !m_havePC ? (h-l) : MathMax(h-l, MathMax(MathAbs(h-m_prevClose), MathAbs(l-m_prevClose)));
      if(!m_haveAtr){ m_atr=tr; m_haveAtr=true; } else m_atr=(m_atr*(m_atrL-1)+tr)/m_atrL;
      atr=m_atr;
      //=== velocity / acceleration / convexity (ema-3) ============
      double dC = m_havePC ? (c-m_prevClose) : 0.0;
      double aE = 2.0/4.0;
      if(!m_haveEma){ m_emaVel=dC; m_haveEma=true; } else m_emaVel=m_emaVel+aE*(dC-m_emaVel);
      vel2=vel1; vel1=vel; vel=m_emaVel;
      acc1=acc; acc=vel-vel1;
      double convNow=acc-acc1; csm1=csm;
      m_emaCsm=(m_n<=1)?convNow:(m_emaCsm+aE*(convNow-m_emaCsm)); csm=m_emaCsm;
      conv=convNow;
      //=== efficiency / displacement ==============================
      double mv=(m_n>m_effL)?MathAbs(c-C(m_effL)):0.0;
      double ps=0.0; for(int i=0;i<m_effL && i+1<m_n;i++) ps+=MathAbs(C(i)-C(i+1));
      eff=(ps>0.0)?mv/ps:0.0;
      disp=(h-l)/MathMax(m_atr,1e-10);
      //=== impulse / decay / convexity-shift ======================
      bullImp = eff>m_effT && vel>vel1 && acc>0 && c>o && disp>m_dispT;
      bearImp = eff>m_effT && vel<vel1 && acc<0 && c<o && disp>m_dispT;
      bullDec = MathAbs(acc)<MathAbs(acc1)*0.8 && vel>0;
      bearDec = MathAbs(acc)<MathAbs(acc1)*0.8 && vel<0;
      double cth=m_atr*m_convM;
      bullCS = (csm>cth)&&(csm1<=cth);
      bearCS = (csm<-cth)&&(csm1>=-cth);
      vd70 = MathAbs(vel)<MathAbs(vel1)*0.7;
      vd50 = MathAbs(vel)<MathAbs(vel1)*0.5;
      m_prevClose=c; m_havePC=true;
     }
   double EffThresh() const { return m_effT; }
   double DispThresh() const { return m_dispT; }
   double ConvMult()  const { return m_convM; }
  };

#endif // __HYPEROMEGA_F60_PHYSICS_MQH__
