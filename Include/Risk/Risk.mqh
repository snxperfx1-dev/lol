//+------------------------------------------------------------------+
//|                                                   Risk/Risk.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Risk is Omega's inheritance and the MASTER OVERRIDE (spec      |
//|   7.5 / commander model): F60 was perception, Omega was survival.|
//|     Trinity        : life / stability / confidence — FED FROM    |
//|                      F60 + observers (the organism's vitals).    |
//|     OmegaCapital   : daily/weekly/hard drawdown state machine +  |
//|                      continuous throttle.                        |
//|     OmegaRisk      : conviction- & exposure-scaled sizing +      |
//|                      portfolio open-risk accounting.             |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_RISK_MQH__
#define __HYPEROMEGA_RISK_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"
#include "../Observers/ObserverBus.mqh"

//=== Trinity — fed FROM F60 + observers =============================
struct Trinity
  {
   double life, stability, confidence;
   void Feed(const F60State &s, const ObserverBus &o)
     {
      // life       = residual energy + chain vitality (is the story alive?)
      // stability  = MTF/narrative coherence
      // confidence = qualification + chain vitality + stability
      life       = OmegaMath::Clamp(o.erf_residual*0.50 + s.chainVitality*0.50, 0.0, 100.0);
      stability  = OmegaMath::Clamp(s.fractalStackScore*0.50 + s.timeAlign*0.30 + (100.0-o.mce_conflict)*0.20, 0.0, 100.0);
      confidence = OmegaMath::Clamp(o.tqe_quality*0.50 + s.chainVitality*0.30 + stability*0.20, 0.0, 100.0);
     }
   void Reset(){ life=stability=confidence=OMEGA_TRINITY_NEUTRAL; }
  };

//=== Capital drawdown state machine =================================
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
   void Init(double d,double w,double h){ m_d=d;m_w=w;m_h=h; double e=Eq(); m_base=m_peak=m_day=m_week=e; m_dayS=DayStart(TimeCurrent()); m_weekS=WeekStart(TimeCurrent()); m_state=CAP_HEALTHY;
      OmegaLogger::LogInfo("CAPITAL",StringFormat("Init eq=%.2f daily=%.1f%% weekly=%.1f%% hard=%.1f%%",e,d,w,h)); }
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
      if(m_state!=prev) OmegaLogger::LogWarning("CAPITAL",StringFormat("%s -> %s (ddD=%.2f ddW=%.2f ddH=%.2f)",CapName(prev),CapName(m_state),ddD,ddW,ddH));
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

//=== Position sizing + portfolio exposure ===========================
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
      pct=MathMin(pct,MathMax(exposureBudgetPct,0.0));
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

#endif // __HYPEROMEGA_RISK_MQH__
