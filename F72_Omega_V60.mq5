//+------------------------------------------------------------------+
//|                                            F72_Omega_V60.mq5      |
//|                                                        F72 OMEGA  |
//|       *** AUTONOMOUS · V60 CORE · PRODUCTION ***                  |
//|                                                                  |
//|   This is the complete port of the Pine "F16 Raptor v60" engine  |
//|   (the Master Senseei) into the F72 Omega MT5 expert advisor.    |
//|                                                                  |
//|   V60 IS THE CORE. The Senseei meta-intelligence is the sole     |
//|   decision authority — there is NO V72 layer and NO competing    |
//|   Phase-5.6 DecisionEngine/DOE here. Anything that contradicted  |
//|   or overrode V60 in the legacy build has been removed.          |
//|                                                                  |
//|   Pipeline (faithful to the Pine source):                        |
//|     f_phys / f_se (6-TF ladder) -> fractal stack -> physics      |
//|     observation -> Engine 1A phase machine -> EDE/RE/EAE energy  |
//|     -> liquidation engine -> belief -> spawn/wave state machine  |
//|     -> attack sequence -> Network FU pools -> TIE -> SENSEEI.    |
//|                                                                  |
//|   Senseei.action drives the engine:                              |
//|     ATTACK        -> open / add in master direction              |
//|     PREPARE/WAIT  -> no new entry (hold what exists)             |
//|     MANAGE / EXIT -> close the campaign                          |
//|     master flip   -> reverse                                     |
//|                                                                  |
//|   The Omega safety shell (Logger, Trinity, Capital drawdown      |
//|   state machine, Risk sizing, CTrade execution) is preserved.    |
//|   The Trinity (life/stability/confidence) is now FED FROM V60,   |
//|   making V60 the genuine organism core.                          |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "60.0"
#property strict
#property description "F72 OMEGA — V60 (F16 Raptor v60) ported as the decision core."
#property description "AUTONOMOUS. Senseei meta-intelligence is the sole authority."

#include <Trade/Trade.mqh>

//==================================================================
//= INPUTS
//==================================================================
input group "=== Senseei (V60 core) ==="
input int    InpSenseeiMinConf   = 55;     // Min confidence to ATTACK
input bool   InpAllowAdds        = true;   // Allow pyramiding (ADD) on continued ATTACK
input int    InpMaxAddsPerCampaign = 2;    // Max adds per campaign

input group "=== V60 Letra engine (exact f_phys / f_se) ==="
input int    InpPivotLen         = 5;      // Pivot Length
input int    InpStructLen        = 10;     // Structure Pivot Length
input int    InpAtrLen           = 14;     // ATR Length
input int    InpEffLen           = 10;     // Efficiency Lookback
input double InpEffThresh        = 0.65;   // Efficiency Threshold
input double InpDispThresh       = 1.5;    // Displacement ATR Threshold
input double InpConvMult         = 0.01;   // Convexity ATR Multiplier
input double InpImpulseAtrMult   = 1.5;    // Impulse ATR Multiple
input double InpChochBufferATR   = 0.75;   // Direction CHoCH Buffer (ATR)
input bool   InpUseStrictStruct  = true;   // Use Strict Structure
input int    InpInducLookback    = 80;     // Inducement Lookback Bars
input double InpInducZoneWidth   = 0.25;   // Inducement Zone Half-Width (ATR)
input int    InpLiqSweepLookback = 10;     // Sweep Lookback Bars
input bool   InpRequireLiqSweep  = true;   // Require Liquidity Sweep
input int    InpResetBars        = 20;     // Min Bars Before Reset
input int    InpBeliefSmooth     = 3;      // Belief EMA Smoothing

input group "=== FU node network ==="
input double InpWickFrac         = 0.3;    // FU spike: min wick / range
input int    InpFuLookback       = 3;      // FU spike: structure lookback
input int    InpAuthMin          = 45;     // Min node authority
input int    InpNodeMax          = 250;    // Max remembered nodes
input int    InpDormantBars      = 120;    // Bars until dormant
input int    InpHistoryBars      = 600;    // Bars until historical

input group "=== Risk / Capital ==="
input double InpRiskPctBase      = 0.5;    // Base risk % per trade (at full conviction)
input double InpRiskPctMin       = 0.10;   // Floor risk %
input double InpDailyLimitPct    = 3.0;    // Daily drawdown limit %
input double InpWeeklyLimitPct   = 8.0;    // Weekly drawdown limit %
input double InpHardLimitPct     = 15.0;   // Hard (kill-switch) drawdown %
input bool   InpCentAccount      = false;  // Cent account (equity/100)

input group "=== Execution ==="
input long   InpMagic            = 720600; // Magic number
input int    InpSlippagePoints   = 30;     // Max slippage (points)
input bool   InpUseTargetTP      = true;   // Place TP at wave objective
input double InpMinStopAtr       = 0.75;   // Min stop distance (ATR multiple)
input bool   InpTrailStops       = true;   // Trail stop to invalidation

input group "=== Diagnostics ==="
input int    InpHeartbeatSec     = 60;     // Heartbeat log interval (sec)
input bool   InpShowComment      = true;   // Show on-chart status comment
input int    InpWarmupBars       = 600;    // Warmup bars per timeframe at init

//==================================================================
//= MODULE: Common — universe primitives (single source of truth)
//==================================================================
enum ENUM_OMEGA_DECISION
  {
   OMEGA_DEC_OBSERVE       = 0,
   OMEGA_DEC_ENTER_LONG    = 1,
   OMEGA_DEC_ENTER_SHORT   = 2,
   OMEGA_DEC_HOLD          = 3,
   OMEGA_DEC_ADD           = 4,
   OMEGA_DEC_REVERSE       = 6,
   OMEGA_DEC_EXIT          = 7
  };

enum ENUM_OMEGA_CAPITAL_STATE
  {
   CAPITAL_HEALTHY     = 0,
   CAPITAL_WARNING     = 1,
   CAPITAL_RESTRICTED  = 2,
   CAPITAL_SUSPENDED   = 3
  };

#define OMEGA_VERSION         "60.0"
#define OMEGA_TRINITY_NEUTRAL 50.0

//=== Math helpers =================================================
class OmegaMath
  {
public:
   static double Clamp(double v, double lo, double hi) { return MathMax(lo, MathMin(hi, v)); }
   static double Lerp(double a, double b, double t)    { return a + (b - a) * t; }
   static double SafeDiv(double n, double d, double fb = 0.0) { return (MathAbs(d) < 1e-10) ? fb : (n / d); }
   static double Pct(double v, double total, double fb = 0.0)  { return SafeDiv(v, total, fb) * 100.0; }
  };

//=== String helpers ===============================================
class OmegaStr
  {
public:
   static string DecisionToString(ENUM_OMEGA_DECISION d)
     {
      switch(d)
        {
         case OMEGA_DEC_OBSERVE:     return "OBSERVE";
         case OMEGA_DEC_ENTER_LONG:  return "ENTER_LONG";
         case OMEGA_DEC_ENTER_SHORT: return "ENTER_SHORT";
         case OMEGA_DEC_HOLD:        return "HOLD";
         case OMEGA_DEC_ADD:         return "ADD";
         case OMEGA_DEC_REVERSE:     return "REVERSE";
         case OMEGA_DEC_EXIT:        return "EXIT";
        }
      return "UNKNOWN";
     }
   static string CapitalStateToString(ENUM_OMEGA_CAPITAL_STATE s)
     {
      switch(s)
        {
         case CAPITAL_HEALTHY:    return "HEALTHY";
         case CAPITAL_WARNING:    return "WARNING";
         case CAPITAL_RESTRICTED: return "RESTRICTED";
         case CAPITAL_SUSPENDED:  return "SUSPENDED";
        }
      return "UNKNOWN";
     }
  };

//==================================================================
//= MODULE: Logger — explainability backbone (Print sink)
//==================================================================
enum ENUM_OMEGA_LOG_LEVEL { LOG_DEBUG=0, LOG_INFO=1, LOG_DECISION=2, LOG_EXEC=3, LOG_WARN=4, LOG_EXCEPT=5 };

class OmegaLogger
  {
private:
   static ENUM_OMEGA_LOG_LEVEL s_minLevel;
   static string LevelStr(ENUM_OMEGA_LOG_LEVEL l)
     {
      switch(l)
        {
         case LOG_DEBUG:  return "DEBUG";
         case LOG_INFO:   return "INFO";
         case LOG_DECISION:return "DECIDE";
         case LOG_EXEC:   return "EXEC";
         case LOG_WARN:   return "WARN";
         case LOG_EXCEPT: return "EXCEPT";
        }
      return "?";
     }
public:
   static void SetMinLevel(ENUM_OMEGA_LOG_LEVEL l) { s_minLevel = l; }
   static void Log(ENUM_OMEGA_LOG_LEVEL level, string module, string msg)
     {
      if((int)level < (int)s_minLevel) return;
      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      Print(StringFormat("[%s][%s][%s] %s", ts, LevelStr(level), module, msg));
     }
   static void LogDebug(string m, string s) { Log(LOG_DEBUG, m, s); }
   static void LogInfo(string m, string s)  { Log(LOG_INFO,  m, s); }
   static void LogWarning(string m, string s){ Log(LOG_WARN, m, s); }
   static void LogDecision(string m, string s){ Log(LOG_DECISION, m, s); }
   static void LogExec(string m, string s)  { Log(LOG_EXEC, m, s); }
   static void Flush() {}
  };
ENUM_OMEGA_LOG_LEVEL OmegaLogger::s_minLevel = LOG_INFO;

//==================================================================
//= MODULE: Memory — the TRINITY (life / stability / confidence)
//==================================================================
//   In the V60-core build the trinity is FED from V60:
//     life       <- curve/energy residual (is the story still alive?)
//     stability  <- Senseei alignment (how stable is the narrative?)
//     confidence <- Senseei confidence (how much do I trust myself?)
class OmegaState
  {
public:
   double   life;
   double   stability;
   double   confidence;
   datetime updated;
   long     tickCount;
   bool     primed;

            OmegaState() { Reset(); }
   void Reset()
     {
      life = stability = confidence = OMEGA_TRINITY_NEUTRAL;
      updated = 0; tickCount = 0; primed = false;
     }
   void Clamp()
     {
      life       = OmegaMath::Clamp(life,       0.0, 100.0);
      stability  = OmegaMath::Clamp(stability,  0.0, 100.0);
      confidence = OmegaMath::Clamp(confidence, 0.0, 100.0);
     }
   string Snapshot() const
     {
      return StringFormat("L=%.1f S=%.1f C=%.1f primed=%s tick=%I64d",
                          life, stability, confidence, primed ? "YES":"NO", tickCount);
     }
  };

//==================================================================
//= MODULE: Capital — drawdown state machine + continuous throttle
//==================================================================
class OmegaCapital
  {
private:
   double m_baseEq, m_dayEq, m_weekEq, m_peakEq;
   double m_dailyPct, m_weeklyPct, m_hardPct;
   datetime m_dayStart, m_weekStart;
   ENUM_OMEGA_CAPITAL_STATE m_state;

   static datetime DayStartOf(datetime t)
     {
      MqlDateTime dt; TimeToStruct(t, dt);
      dt.hour=0; dt.min=0; dt.sec=0;
      return StructToTime(dt);
     }
   static datetime WeekStartOf(datetime t)
     {
      datetime d = DayStartOf(t);
      MqlDateTime dt; TimeToStruct(d, dt);
      int dow = (int)dt.day_of_week;
      int back = (dow == 0) ? 6 : (dow - 1);
      return d - (datetime)((long)back * 86400);
     }
   double Eq() const
     {
      double e = AccountInfoDouble(ACCOUNT_EQUITY);
      return InpCentAccount ? e / 100.0 : e;
     }
public:
            OmegaCapital()
     {
      m_baseEq=m_dayEq=m_weekEq=m_peakEq=0;
      m_dailyPct=3.0; m_weeklyPct=8.0; m_hardPct=15.0;
      m_dayStart=m_weekStart=0; m_state=CAPITAL_HEALTHY;
     }
   void Init(double dailyPct, double weeklyPct, double hardPct)
     {
      m_dailyPct=dailyPct; m_weeklyPct=weeklyPct; m_hardPct=hardPct;
      double e = Eq();
      m_baseEq=m_peakEq=m_dayEq=m_weekEq=e;
      m_dayStart=DayStartOf(TimeCurrent());
      m_weekStart=WeekStartOf(TimeCurrent());
      m_state=CAPITAL_HEALTHY;
      OmegaLogger::LogInfo("CAPITAL",
         StringFormat("Init equity=%.2f daily=%.1f%% weekly=%.1f%% hard=%.1f%%",
                       e, dailyPct, weeklyPct, hardPct));
     }
   void Update()
     {
      double e = Eq();
      datetime now = TimeCurrent();
      datetime nd = DayStartOf(now);
      if(nd != m_dayStart) { m_dayStart=nd; m_dayEq=e; }
      datetime nw = WeekStartOf(now);
      if(nw != m_weekStart) { m_weekStart=nw; m_weekEq=e; }
      if(e > m_peakEq) m_peakEq=e;
      double ddDay  = OmegaMath::Pct(m_dayEq  - e, m_dayEq);
      double ddWeek = OmegaMath::Pct(m_weekEq - e, m_weekEq);
      double ddHard = OmegaMath::Pct(m_baseEq - e, m_baseEq);
      ENUM_OMEGA_CAPITAL_STATE prev = m_state;
      if(ddHard >= m_hardPct)             m_state=CAPITAL_SUSPENDED;
      else if(ddWeek >= m_weeklyPct)      m_state=CAPITAL_RESTRICTED;
      else if(ddDay  >= m_dailyPct)       m_state=CAPITAL_RESTRICTED;
      else if(ddDay >= m_dailyPct*0.66 || ddWeek >= m_weeklyPct*0.66) m_state=CAPITAL_WARNING;
      else                                m_state=CAPITAL_HEALTHY;
      if(m_state != prev)
         OmegaLogger::LogWarning("CAPITAL",
            StringFormat("State %s -> %s · ddDay=%.2f%% ddWeek=%.2f%% ddHard=%.2f%%",
               OmegaStr::CapitalStateToString(prev), OmegaStr::CapitalStateToString(m_state),
               ddDay, ddWeek, ddHard));
     }
   ENUM_OMEGA_CAPITAL_STATE State() const { return m_state; }
   double DailyDrawdownPct()  const { return OmegaMath::Pct(m_dayEq  - Eq(), m_dayEq); }
   double WeeklyDrawdownPct() const { return OmegaMath::Pct(m_weekEq - Eq(), m_weekEq); }
   double HardDrawdownPct()   const { return OmegaMath::Pct(m_baseEq - Eq(), m_baseEq); }
   bool   BlocksEntries()     const { return m_state == CAPITAL_RESTRICTED || m_state == CAPITAL_SUSPENDED; }
   bool   RequiresFlat()      const { return m_state == CAPITAL_SUSPENDED; }
   double Throttle() const
     {
      double dt = OmegaMath::Clamp(1.0 - (DailyDrawdownPct()  / m_dailyPct),  0.0, 1.0);
      double wt = OmegaMath::Clamp(1.0 - (WeeklyDrawdownPct() / m_weeklyPct), 0.0, 1.0);
      double ht = OmegaMath::Clamp(1.0 - (HardDrawdownPct()   / m_hardPct),   0.0, 1.0);
      return MathMin(dt, MathMin(wt, ht));
     }
  };

//==================================================================
//= MODULE: Risk — trinity/conviction-scaled position sizing
//==================================================================
class OmegaRisk
  {
public:
   // Lots from a stop distance (points) and a risk % of equity, scaled
   // by Senseei conviction (0..1) and the Capital throttle (0..1).
   static double LotsFor(string sym, double stopPoints, double riskPct,
                          double conviction, double throttle)
     {
      if(stopPoints <= 0.0) return 0.0;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double pct = OmegaMath::Clamp(riskPct, InpRiskPctMin, 100.0);
      pct *= OmegaMath::Clamp(conviction, 0.0, 1.0);
      pct *= OmegaMath::Clamp(throttle,   0.0, 1.0);
      pct  = MathMax(pct, InpRiskPctMin * 0.25);
      double riskMoney = eq * pct / 100.0;

      double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double point    = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(tickSize <= 0.0) tickSize = point;
      if(tickVal  <= 0.0 || tickSize <= 0.0 || point <= 0.0) return 0.0;

      double valuePerPoint = tickVal * (point / tickSize);
      double lossPerLot    = stopPoints * valuePerPoint;
      if(lossPerLot <= 0.0) return 0.0;

      double lots = riskMoney / lossPerLot;
      return NormalizeLots(sym, lots);
     }
   static double NormalizeLots(string sym, double lots)
     {
      double minLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      if(stepLot <= 0.0) stepLot = 0.01;
      if(minLot  <= 0.0) minLot  = stepLot;
      lots = MathFloor(lots / stepLot + 1e-9) * stepLot;
      if(lots < minLot) lots = minLot;
      if(maxLot > 0.0 && lots > maxLot) lots = maxLot;
      return NormalizeDouble(lots, 2);
     }
  };


//==================================================================
//= MODULE: V60/SEEngine — faithful port of f_phys + f_se
//==================================================================
//   The Pine f_se is the SOLE lifecycle authority. It runs once per
//   bar of its timeframe (request.security, lookahead_off). Here it
//   is a sequential state machine: Step() consumes ONE just-closed
//   bar of its timeframe and evolves all persistent state, exactly
//   like Pine's bar-by-bar 'var' evolution. f_phys is folded in (it
//   shares the identical physics primitives) and exposed via getters
//   so the canonical (M5) instance feeds the physics-observation
//   layer, EDE, belief and spawn engines downstream.
//==================================================================
#define NA_VAL DBL_MAX
bool   IsNa(double v) { return (v >= DBL_MAX * 0.5); }
double Nz(double v, double fb = 0.0) { return IsNa(v) ? fb : v; }

class SEEngine
  {
private:
   //--- params
   int    m_pvLen, m_atrL, m_effL;
   double m_effT, m_dispT, m_convM, m_impM, m_chBuf;
   bool   m_strict;
   //--- ring history (newest at end)
   double m_hi[64], m_lo[64], m_cl[64], m_op[64];
   int    m_n;                       // bars seen
   //--- physics recursive state
   double m_emaVel, m_emaCsm, m_atr;
   double m_prevClose;
   bool   m_haveEma, m_haveAtr, m_havePrevClose;
   double m_vel, m_vel1, m_vel2;     // velocity now / [1] / [2]
   double m_acc, m_acc1;
   double m_csm, m_csm1;
   //--- pivot memory
   double m_curSH, m_curSL, m_prSH, m_prSL;
   double m_lastP, m_prevP; int m_lastD, m_prevD;
   //--- wave context
   int    m_dir;
   double m_ft, m_fb, m_p4h, m_p4l, m_inv, m_tgt, m_cycH, m_cycL;
   //--- recursion / inducement
   bool   m_bos1, m_bos2, m_indBrk;
   double m_protSw, m_protSw2, m_indOrig, m_indExt;
   int    m_lastDirSeen;
   int    m_recBrk; bool m_recArm;
   int    m_pst;

public:
   //--- per-step physics outputs (canonical instance reads these)
   double atr, vel, acc, conv, convSmooth, eff, disp;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;
   //--- per-step structural outputs (mirror f_se return tuple)
   int    o_dir;          // _dirLabel (origin-based wdir)
   int    o_phase;        // 0..14
   double o_curSH, o_curSL, o_prSH, o_prSL;
   int    o_bos, o_ch;
   double o_p4h, o_p4l, o_inv, o_tgt, o_ft, o_fb;
   double o_frzS, o_wp, o_cm, o_mf, o_compIdx;
   int    o_recBrk; double o_recDom;
   bool   o_reset;        // direction reset this step
   bool   o_eLong, o_eShort, o_atExtreme;

            SEEngine() { }

   void Init(int pvLen, int atrL, int effL, double effT, double dispT,
              double convM, double impM, double chBuf, bool strict)
     {
      m_pvLen=pvLen; m_atrL=atrL; m_effL=effL;
      m_effT=effT; m_dispT=dispT; m_convM=convM; m_impM=impM; m_chBuf=chBuf;
      m_strict=strict;
      Reset();
     }

   void Reset()
     {
      ArrayInitialize(m_hi,0); ArrayInitialize(m_lo,0);
      ArrayInitialize(m_cl,0); ArrayInitialize(m_op,0);
      m_n=0;
      m_emaVel=m_emaCsm=m_atr=0; m_prevClose=0;
      m_haveEma=m_haveAtr=m_havePrevClose=false;
      m_vel=m_vel1=m_vel2=0; m_acc=m_acc1=0; m_csm=m_csm1=0;
      m_curSH=m_curSL=m_prSH=m_prSL=NA_VAL;
      m_lastP=m_prevP=NA_VAL; m_lastD=m_prevD=0;
      m_dir=0; m_ft=m_fb=m_p4h=m_p4l=m_inv=m_tgt=m_cycH=m_cycL=NA_VAL;
      m_bos1=m_bos2=m_indBrk=false;
      m_protSw=m_protSw2=m_indOrig=m_indExt=NA_VAL;
      m_lastDirSeen=0; m_recBrk=0; m_recArm=true; m_pst=0;
      ZeroOutputs();
     }

   void ZeroOutputs()
     {
      atr=vel=acc=conv=convSmooth=eff=disp=0;
      bullImp=bearImp=bullDec=bearDec=bullCS=bearCS=vd70=vd50=false;
      o_dir=o_phase=0; o_curSH=o_curSL=o_prSH=o_prSL=NA_VAL;
      o_bos=o_ch=0; o_p4h=o_p4l=o_inv=o_tgt=o_ft=o_fb=NA_VAL;
      o_frzS=o_wp=o_cm=o_mf=o_compIdx=0; o_recBrk=0; o_recDom=0;
      o_reset=false; o_eLong=o_eShort=o_atExtreme=false;
     }

private:
   void Push(double o, double h, double l, double c)
     {
      for(int i=0;i<63;i++)
        { m_hi[i]=m_hi[i+1]; m_lo[i]=m_lo[i+1]; m_cl[i]=m_cl[i+1]; m_op[i]=m_op[i+1]; }
      m_hi[63]=h; m_lo[63]=l; m_cl[63]=c; m_op[63]=o;
      m_n++;
     }
   double H(int back) const { return m_hi[63-back]; }   // back=0 newest
   double L(int back) const { return m_lo[63-back]; }
   double C(int back) const { return m_cl[63-back]; }

   double PivotHigh()
     {
      int L2 = m_pvLen;
      if(m_n < 2*L2+1) return NA_VAL;
      double cand = H(L2);
      for(int i=0;i<=2*L2;i++)
        {
         if(i==L2) continue;
         if(H(i) >= cand) return NA_VAL;   // strict pivot (ties disqualify)
        }
      return cand;
     }
   double PivotLow()
     {
      int L2 = m_pvLen;
      if(m_n < 2*L2+1) return NA_VAL;
      double cand = L(L2);
      for(int i=0;i<=2*L2;i++)
        {
         if(i==L2) continue;
         if(L(i) <= cand) return NA_VAL;
        }
      return cand;
     }

public:
   //--- process exactly one just-closed bar of this timeframe
   void Step(double o, double h, double l, double c)
     {
      Push(o,h,l,c);

      //=== ATR (Wilder RMA of true range) ============================
      double tr;
      if(!m_havePrevClose) tr = h - l;
      else tr = MathMax(h - l, MathMax(MathAbs(h - m_prevClose), MathAbs(l - m_prevClose)));
      if(!m_haveAtr) { m_atr = tr; m_haveAtr = true; }
      else m_atr = (m_atr * (m_atrL - 1) + tr) / m_atrL;
      atr = m_atr;

      //=== velocity / acceleration / convexity (ema-3) ===============
      double dClose = m_havePrevClose ? (c - m_prevClose) : 0.0;
      double aEma = 2.0 / (3.0 + 1.0);
      if(!m_haveEma) { m_emaVel = dClose; m_haveEma = true; }
      else m_emaVel = m_emaVel + aEma * (dClose - m_emaVel);
      m_vel2 = m_vel1; m_vel1 = m_vel; m_vel = m_emaVel;
      m_acc1 = m_acc;  m_acc  = m_vel - m_vel1;
      double convNow = m_acc - m_acc1;
      m_csm1 = m_csm;
      // ema(conv,3) — seed on first sample
      m_emaCsm = (m_n <= 1) ? convNow : (m_emaCsm + aEma * (convNow - m_emaCsm));
      m_csm = m_emaCsm;

      vel = m_vel; acc = m_acc; conv = convNow; convSmooth = m_csm;

      //=== efficiency / displacement =================================
      double mv = (m_n > m_effL) ? MathAbs(c - C(m_effL)) : 0.0;
      double ps = 0.0;
      for(int i=0; i<m_effL && i+1<m_n; i++)
         ps += MathAbs(C(i) - C(i+1));
      eff  = (ps > 0.0) ? mv / ps : 0.0;
      disp = (h - l) / MathMax(m_atr, 1e-10);

      //=== impulse / decay / convexity-shift =========================
      bullImp = eff > m_effT && m_vel > m_vel1 && m_acc > 0 && c > o && disp > m_dispT;
      bearImp = eff > m_effT && m_vel < m_vel1 && m_acc < 0 && c < o && disp > m_dispT;
      bullDec = MathAbs(m_acc) < MathAbs(m_acc1) * 0.8 && m_vel > 0;
      bearDec = MathAbs(m_acc) < MathAbs(m_acc1) * 0.8 && m_vel < 0;
      double cth = m_atr * m_convM;
      bullCS = (m_csm >  cth) && (m_csm1 <=  cth);
      bearCS = (m_csm < -cth) && (m_csm1 >= -cth);
      vd70 = MathAbs(m_vel) < MathAbs(m_vel1) * 0.7;
      vd50 = MathAbs(m_vel) < MathAbs(m_vel1) * 0.5;

      //=== pivots ====================================================
      double pH = PivotHigh();
      double pL = PivotLow();
      if(!IsNa(pH)) { m_prSH = IsNa(m_curSH) ? pH : m_curSH; m_curSH = pH; }
      if(!IsNa(pL)) { m_prSL = IsNa(m_curSL) ? pL : m_curSL; m_curSL = pL; }
      double eP = NA_VAL; int eD = 0;
      if(!IsNa(pH)) { eP = pH; eD = 1; }
      else if(!IsNa(pL)) { eP = pL; eD = -1; }
      if(eD != 0) { m_prevP = m_lastP; m_prevD = m_lastD; m_lastP = eP; m_lastD = eD; }

      //=== structure =================================================
      bool bullBOS = !IsNa(m_prSH) && c > m_prSH;
      bool bearBOS = !IsNa(m_prSL) && c < m_prSL;
      bool bullCH  = !IsNa(m_prSH) && c > m_prSH + m_atr * m_chBuf;
      bool bearCH  = !IsNa(m_prSL) && c < m_prSL - m_atr * m_chBuf;
      bool eLong   = !IsNa(pH) && m_prevD == -1 && !IsNa(m_prevP) && (pH - m_prevP) > m_atr * m_impM;
      bool eShort  = !IsNa(pL) && m_prevD ==  1 && !IsNa(m_prevP) && (m_prevP - pL) > m_atr * m_impM;

      //=== spawn =====================================================
      bool hasCtx = m_dir != 0 && !IsNa(m_ft);
      bool flipDn = m_dir == 1  && bearCH;
      bool flipUp = m_dir == -1 && bullCH;
      bool isRev  = (eLong && m_dir == -1) || (eShort && m_dir == 1) || flipUp || flipDn;
      bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);
      if(spawn)
        {
         int nd = eLong ? 1 : eShort ? -1 : flipUp ? 1 : -1;
         double hi = MathMax(Nz(m_lastP,c), Nz(m_prevP,c));
         double lo = MathMin(Nz(m_lastP,c), Nz(m_prevP,c));
         m_dir = nd; m_ft = hi; m_fb = lo; m_p4h = hi; m_p4l = lo;
         m_cycH = h; m_cycL = l;
         m_inv = (nd == 1) ? lo : hi;
         double rng = (!IsNa(m_prSH) && !IsNa(m_prSL)) ? MathAbs(m_prSH - m_prSL) : m_atr * 5.0;
         m_tgt = (nd == 1) ? Nz(hi, c) + rng : Nz(lo, c) - rng;
        }
      if(m_dir == 1)  m_cycH = IsNa(m_cycH) ? h : MathMax(m_cycH, h);
      if(m_dir == -1) m_cycL = IsNa(m_cycL) ? l : MathMin(m_cycL, l);

      int bosOut = bullBOS ? 1 : bearBOS ? -1 : 0;
      int chOut  = bullCH  ? 1 : bearCH  ? -1 : 0;

      //=== recursion / inducement ====================================
      bool reset = (m_dir != m_lastDirSeen);
      m_lastDirSeen = m_dir;
      if(reset)
        {
         m_bos1=false; m_bos2=false; m_protSw=NA_VAL; m_protSw2=NA_VAL;
         m_indOrig=NA_VAL; m_indExt=NA_VAL; m_indBrk=false;
        }
      if(m_dir == 1  && !IsNa(pL)) { m_protSw2 = m_protSw; m_protSw = pL; }
      if(m_dir == -1 && !IsNa(pH)) { m_protSw2 = m_protSw; m_protSw = pH; }
      bool oppBOS = (m_dir == 1  && !IsNa(m_protSw) && c < m_protSw) ||
                    (m_dir == -1 && !IsNa(m_protSw) && c > m_protSw);
      if(!m_bos1 && oppBOS)
        {
         m_bos1 = true;
         m_indOrig = (m_dir == 1) ? Nz(m_cycH, h) : Nz(m_cycL, l);
        }
      if(m_bos1 && !m_bos2 && oppBOS && !IsNa(m_protSw2) &&
         (m_dir == 1 ? c < m_protSw2 : c > m_protSw2))
         m_bos2 = true;
      if(m_bos1 && m_dir == 1)  m_indExt = IsNa(m_indExt) ? c : MathMin(m_indExt, c);
      if(m_bos1 && m_dir == -1) m_indExt = IsNa(m_indExt) ? c : MathMax(m_indExt, c);
      if(m_bos2 && !IsNa(m_indOrig))
        {
         if(m_dir == 1  && c > m_indOrig) m_indBrk = true;
         if(m_dir == -1 && c < m_indOrig) m_indBrk = true;
        }

      //=== scores ====================================================
      double convScore = MathMin(MathAbs(m_csm) / MathMax(m_atr * m_convM, 1e-10) * 50.0, 100.0);
      double expScore  = MathMin(eff / MathMax(m_effT, 1e-10) * 50.0 + disp / MathMax(m_dispT, 1e-10) * 50.0, 100.0);
      double absScore  = (eff < m_effT * 0.7 && MathAbs(m_vel) < MathAbs(m_vel1) * 0.6)
                          ? 60.0 + convScore * 0.4 : convScore * 0.3;
      bool momExpStrong = eff > m_effT * 0.75 && (m_dir == 1 ? m_vel > 0 : m_vel < 0);
      bool momDecaying  = (m_dir == 1) ? bullDec : bearDec;
      bool momCounter   = (m_dir == 1) ? bearImp : bullImp;
      bool momExhaust   = eff < m_effT * 0.65 && absScore > 40.0;
      bool physConvexDevel = convScore > 35.0;
      bool physTransfer    = convScore > 48.0 || absScore > 40.0;
      bool physCapacityLow = absScore > 45.0 || eff < m_effT * 0.6;

      //=== direction (origin-based) ==================================
      int wdir = !IsNa(m_inv) ? (c > m_inv ? 1 : c < m_inv ? -1 : m_dir) : m_dir;
      bool atFlip = !IsNa(m_ft) && !IsNa(m_fb) && c <= m_ft && c >= m_fb;
      bool expanding = momExpStrong || eLong || eShort || (wdir == 1 ? bullImp : bearImp);
      bool atExtreme = wdir == 1 ? h >= Nz(m_cycH, h) : wdir == -1 ? l <= Nz(m_cycL, l) : false;
      double extr = wdir == 1 ? Nz(m_cycH, c) : Nz(m_cycL, c);
      bool extended = !IsNa(m_inv) && MathAbs(extr - m_inv) > m_atr * 1.5;
      double fzMid = (!IsNa(m_ft) && !IsNa(m_fb)) ? (m_ft + m_fb) / 2.0 : NA_VAL;
      double retrFrac = (!IsNa(fzMid) && MathAbs(extr - fzMid) > 1e-10)
                         ? MathAbs(extr - c) / MathAbs(extr - fzMid) : 0.0;
      double compIdx = MathMin(100.0, MathMax(0.0,
                        (1.0 - MathMin(disp / MathMax(m_dispT, 1e-10), 1.0)) * 60.0 +
                        (1.0 - MathMin(eff  / MathMax(m_effT,  1e-10), 1.0)) * 40.0));

      //=== recursive transition ======================================
      bool phase2CH = (m_dir == 1 && bearCH) || (m_dir == -1 && bullCH);
      if(reset || (atExtreme && extended)) { m_recBrk = 0; m_recArm = true; }
      if((m_dir == 1 && !IsNa(pH)) || (m_dir == -1 && !IsNa(pL))) m_recArm = true;
      if((phase2CH || oppBOS) && m_recArm && !atExtreme) { m_recBrk++; m_recArm = false; }
      double recDom = MathMin(100.0, MathMax(m_recBrk * (30.0 - compIdx * 0.15), retrFrac * 80.0));
      bool transferDone = recDom >= 50.0;

      //=== phase state machine 0..14 =================================
      if(reset) m_pst = 0;
      if(m_dir != 0 && !reset)
        {
         if(m_pst == 0 && expanding) m_pst = 1;
         if(m_pst == 1 && !atExtreme && momDecaying && physConvexDevel) m_pst = 2;
         if(m_pst == 2 && !atExtreme && momCounter && physTransfer) m_pst = 3;
         if(m_pst == 3 && !atExtreme && (m_bos1 || m_bos2 || m_indBrk) && physTransfer) m_pst = 4;
         if(m_pst >= 1 && m_pst <= 7 && atExtreme && extended) m_pst = 5;
         if(m_pst == 5 && !atExtreme && (m_recBrk >= 1 || momExhaust)) m_pst = 7;
         if(m_pst == 7 && transferDone) m_pst = 8;
         if(m_pst == 8 && atFlip) m_pst = 9;
         if(m_pst == 9 && ((m_dir == 1 && bullImp) || (m_dir == -1 && bearImp))) m_pst = 10;
         if(m_pst == 10 && (oppBOS || physCapacityLow)) m_pst = 11;
         if(m_pst == 11 && ((m_dir == 1 && l < m_fb) || (m_dir == -1 && h > m_ft))) m_pst = 12;
         if(m_pst == 12 && ((m_dir == 1 && bullCH) || (m_dir == -1 && bearCH))) m_pst = 13;
        }
      int phase = m_pst;
      if(phase == 5  && m_dir == -1) phase = 6;
      if(phase == 13 && m_dir == -1) phase = 14;
      double wp = m_pst == 0 ? 5.0 : m_pst == 1 ? 15.0 : m_pst == 2 ? 25.0 : m_pst == 3 ? 33.0 :
                  m_pst == 4 ? 42.0 : m_pst == 5 ? 55.0 : m_pst == 7 ? 65.0 : m_pst == 8 ? 75.0 :
                  m_pst == 9 ? 85.0 : m_pst == 10 ? 90.0 : m_pst == 11 ? 94.0 : m_pst == 12 ? 97.0 : 100.0;
      double cm = MathMin(convScore, 100.0);
      double mf = MathMin(MathMax(expScore, MathMax(absScore, convScore)) * 0.70 + (m_dir != 0 ? 30.0 : 0.0), 100.0);
      double frzS = MathMin((eLong || eShort ? 50.0 : 0.0) + expScore * 0.30 + convScore * 0.20, 100.0);

      //=== publish outputs ===========================================
      o_dir = wdir; o_phase = phase;
      o_curSH=m_curSH; o_curSL=m_curSL; o_prSH=m_prSH; o_prSL=m_prSL;
      o_bos=bosOut; o_ch=chOut;
      o_p4h=m_p4h; o_p4l=m_p4l; o_inv=m_inv; o_tgt=m_tgt; o_ft=m_ft; o_fb=m_fb;
      o_frzS=frzS; o_wp=wp; o_cm=cm; o_mf=mf; o_compIdx=compIdx;
      o_recBrk=m_recBrk; o_recDom=recDom;
      o_reset=reset; o_eLong=eLong; o_eShort=eShort; o_atExtreme=atExtreme;

      m_prevClose = c; m_havePrevClose = true;
     }

   //--- helpers for downstream (canonical instance)
   double velPrev1() const { return m_vel1; }
   double velPrev2() const { return m_vel2; }
   int    dir()      const { return m_dir; }
   double cycH()     const { return m_cycH; }
   double cycL()     const { return m_cycL; }
  };


//==================================================================
//= MODULE: V60/FUEngine — faithful port of f_fuPool
//==================================================================
//   Detects the dominant rejection-wick (FU / flip) at a local
//   extreme, swept or not, on its own timeframe. One Step() per
//   just-closed bar of the timeframe. Outputs tip / mid / dir /
//   valid / score, exactly like the Pine tuple.
//==================================================================
class FUEngine
  {
private:
   double m_wf; int m_lb;
   double m_hi[48], m_lo[48], m_cl[48], m_op[48];
   int    m_n;
   double m_atr; bool m_haveAtr; double m_prevClose; bool m_havePC;
   //--- persistent FU state
   double m_tip, m_bH, m_bL, m_mid; int m_dir; bool m_have, m_conf;
public:
   double o_tip, o_mid; int o_dir; bool o_valid; double o_score;

   void Init(double wf, int lb)
     {
      m_wf=wf; m_lb=lb; Reset();
     }
   void Reset()
     {
      ArrayInitialize(m_hi,0); ArrayInitialize(m_lo,0);
      ArrayInitialize(m_cl,0); ArrayInitialize(m_op,0);
      m_n=0; m_atr=0; m_haveAtr=false; m_prevClose=0; m_havePC=false;
      m_tip=m_bH=m_bL=m_mid=NA_VAL; m_dir=0; m_have=false; m_conf=false;
      o_tip=NA_VAL; o_mid=NA_VAL; o_dir=0; o_valid=false; o_score=0;
     }
private:
   void Push(double o,double h,double l,double c)
     {
      for(int i=0;i<47;i++){ m_hi[i]=m_hi[i+1]; m_lo[i]=m_lo[i+1]; m_cl[i]=m_cl[i+1]; m_op[i]=m_op[i+1]; }
      m_hi[47]=h; m_lo[47]=l; m_cl[47]=c; m_op[47]=o; m_n++;
     }
   double H(int back) const { return m_hi[47-back]; }
   double L(int back) const { return m_lo[47-back]; }
   double HighestPrev(int len) const // highest(high,len)[1]
     {
      double m=-DBL_MAX; for(int i=1;i<=len && i<m_n;i++) m=MathMax(m,H(i));
      return (m==-DBL_MAX)?NA_VAL:m;
     }
   double LowestPrev(int len) const
     {
      double m=DBL_MAX; for(int i=1;i<=len && i<m_n;i++) m=MathMin(m,L(i));
      return (m==DBL_MAX)?NA_VAL:m;
     }
   double HighestNow(int len) const // highest(high,len) (current included)
     {
      double m=-DBL_MAX; for(int i=0;i<len && i<m_n;i++) m=MathMax(m,H(i));
      return (m==-DBL_MAX)?NA_VAL:m;
     }
   double LowestNow(int len) const
     {
      double m=DBL_MAX; for(int i=0;i<len && i<m_n;i++) m=MathMin(m,L(i));
      return (m==DBL_MAX)?NA_VAL:m;
     }
public:
   void Step(double o,double h,double l,double c)
     {
      Push(o,h,l,c);
      double tr = !m_havePC ? (h-l) : MathMax(h-l, MathMax(MathAbs(h-m_prevClose), MathAbs(l-m_prevClose)));
      if(!m_haveAtr){ m_atr=tr; m_haveAtr=true; } else m_atr=(m_atr*13.0+tr)/14.0;

      double rng = MathMax(h-l, 1e-10);
      double pHi = HighestPrev(m_lb);
      double pLo = LowestPrev(m_lb);
      double uw  = (h - MathMax(o,c)) / rng;
      double lw  = (MathMin(o,c) - l) / rng;
      double hNow = HighestNow(m_lb);
      double lNow = LowestNow(m_lb);
      bool localTop = !IsNa(hNow) && h >= hNow;
      bool localBot = !IsNa(lNow) && l <= lNow;
      bool bear = uw >= m_wf && ((!IsNa(pHi) && h >= pHi && c < pHi) || (localTop && c < o));
      bool bull = lw >= m_wf && ((!IsNa(pLo) && l <= pLo && c > pLo) || (localBot && c > o));
      if(bear)
        { m_dir=-1; m_tip=h; m_bH=MathMax(o,c); m_bL=MathMin(o,c); m_mid=m_bH+(m_tip-m_bH)*0.5; m_have=true; m_conf=false; }
      else if(bull)
        { m_dir=1; m_tip=l; m_bH=MathMax(o,c); m_bL=MathMin(o,c); m_mid=m_tip+(m_bL-m_tip)*0.5; m_have=true; m_conf=false; }
      if(m_have && m_dir==-1 && !m_conf && c < m_bL) m_conf=true;
      if(m_have && m_dir==1  && !m_conf && c > m_bH) m_conf=true;
      double wk = (m_dir==-1 && m_have) ? (m_tip-m_bH)/MathMax(m_atr,1e-10)
                : (m_dir==1  && m_have) ? (m_bL-m_tip)/MathMax(m_atr,1e-10) : 0.0;
      double score = 20.0 + MathMin(25.0, wk*15.0) + (m_conf?30.0:0.0) + (wk>1.0?15.0:0.0) + (wk>1.5?10.0:0.0);
      o_tip = m_have ? m_tip : NA_VAL; o_mid = m_mid; o_dir = m_dir; o_valid = m_have; o_score = score;
      m_prevClose=c; m_havePC=true;
     }
  };

//==================================================================
//= MODULE: V60/Network — Invisible Network node registry + netBias
//==================================================================
class NetworkEngine
  {
private:
   FUEngine m_fu[7];                       // MN,W,D,H4,H1,M15,M5
   int      m_wt[7];                        // weight per TF (9..3)
   double   m_prevTip[7];
   //--- registry
   double m_nPx[], m_nMid[], m_nSc[]; int m_nDir[], m_nWt[], m_nState[], m_nBar[], m_nRev[];
   int    m_barIndex;
   //--- chart (M5) reference
   double m_ema50; bool m_haveEma;
public:
   int    netBias, pdir, eligibleNodes, nodeCount;
   double pressure, bullAuth, bearAuth;

   void Init()
     {
      m_fu[0].Init(InpWickFrac, InpFuLookback); m_wt[0]=9;
      m_fu[1].Init(InpWickFrac, InpFuLookback); m_wt[1]=8;
      m_fu[2].Init(InpWickFrac, InpFuLookback); m_wt[2]=7;
      m_fu[3].Init(InpWickFrac, InpFuLookback); m_wt[3]=6;
      m_fu[4].Init(InpWickFrac, InpFuLookback); m_wt[4]=5;
      m_fu[5].Init(InpWickFrac, InpFuLookback); m_wt[5]=4;
      m_fu[6].Init(InpWickFrac, InpFuLookback); m_wt[6]=3;
      for(int i=0;i<7;i++) m_prevTip[i]=NA_VAL;
      ArrayResize(m_nPx,0); ArrayResize(m_nMid,0); ArrayResize(m_nSc,0);
      ArrayResize(m_nDir,0); ArrayResize(m_nWt,0); ArrayResize(m_nState,0);
      ArrayResize(m_nBar,0); ArrayResize(m_nRev,0);
      m_barIndex=0; m_ema50=0; m_haveEma=false;
      netBias=pdir=eligibleNodes=nodeCount=0; pressure=bullAuth=bearAuth=0;
     }

   //--- step a single network TF (idx 0..6) with a just-closed bar
   void StepTF(int idx, double o, double h, double l, double c)
     {
      m_fu[idx].Step(o,h,l,c);
     }

   void NodeAdd(double tip, double mid, int dir, double sc, int wt)
     {
      int sz=ArraySize(m_nPx);
      ArrayResize(m_nPx, sz+1); ArrayResize(m_nMid, sz+1); ArrayResize(m_nSc, sz+1);
      ArrayResize(m_nDir, sz+1); ArrayResize(m_nWt, sz+1); ArrayResize(m_nState, sz+1);
      ArrayResize(m_nBar, sz+1); ArrayResize(m_nRev, sz+1);
      m_nPx[sz]=tip; m_nMid[sz]=mid; m_nDir[sz]=dir; m_nSc[sz]=sc; m_nWt[sz]=wt;
      m_nState[sz]=0; m_nBar[sz]=m_barIndex; m_nRev[sz]=0;
      if(ArraySize(m_nPx) > InpNodeMax) ShiftFront();
     }
   void ShiftFront()
     {
      int sz=ArraySize(m_nPx); if(sz<=0) return;
      for(int i=0;i<sz-1;i++)
        {
         m_nPx[i]=m_nPx[i+1]; m_nMid[i]=m_nMid[i+1]; m_nSc[i]=m_nSc[i+1];
         m_nDir[i]=m_nDir[i+1]; m_nWt[i]=m_nWt[i+1]; m_nState[i]=m_nState[i+1];
         m_nBar[i]=m_nBar[i+1]; m_nRev[i]=m_nRev[i+1];
        }
      ArrayResize(m_nPx,sz-1); ArrayResize(m_nMid,sz-1); ArrayResize(m_nSc,sz-1);
      ArrayResize(m_nDir,sz-1); ArrayResize(m_nWt,sz-1); ArrayResize(m_nState,sz-1);
      ArrayResize(m_nBar,sz-1); ArrayResize(m_nRev,sz-1);
     }
   double Auth(int i) const { return m_nSc[i] + m_nWt[i]*4.0 + m_nRev[i]*3.0; }

   //--- called once per canonical (M5) closed bar: register fresh FU
   //    tips, update node states, recompute netBias/pressure.
   void Commit(double m5close, double m5atr)
     {
      m_barIndex++;
      // ema50 of canonical close
      double a = 2.0/(50.0+1.0);
      if(!m_haveEma){ m_ema50=m5close; m_haveEma=true; } else m_ema50 += a*(m5close-m_ema50);

      // register new FU tips per TF (when the tip changed)
      for(int i=0;i<7;i++)
        {
         if(m_fu[i].o_valid && !IsNa(m_fu[i].o_tip) &&
            (IsNa(m_prevTip[i]) || m_fu[i].o_tip != m_prevTip[i]))
           {
            NodeAdd(m_fu[i].o_tip, m_fu[i].o_mid, m_fu[i].o_dir, m_fu[i].o_score, m_wt[i]);
            m_prevTip[i] = m_fu[i].o_tip;
           }
        }

      // node state machine + authority tally
      double natr = (m5atr>0)? m5atr : MathMax(m5close*0.001,1e-10);
      int sz=ArraySize(m_nPx);
      bullAuth=0; bearAuth=0; eligibleNodes=0;
      for(int i=0;i<sz;i++)
        {
         if(m_nState[i] != 2)
           {
            double np=m_nPx[i]; int nd=m_nDir[i]; int age=m_barIndex-m_nBar[i];
            if(nd==-1 ? m5close>np : m5close<np)
               m_nState[i]=2;
            else
              {
               if(MathAbs(m5close-np) < natr*0.25) m_nRev[i]++;
               int wtn=m_nWt[i];
               m_nState[i] = age > InpHistoryBars*wtn ? 3 : age > InpDormantBars*wtn ? 1 : 0;
              }
           }
         if(m_nState[i] != 2)
           {
            double au=Auth(i);
            if(m_nDir[i]==1) bullAuth+=au; else if(m_nDir[i]==-1) bearAuth+=au;
            if(au>=InpAuthMin) eligibleNodes++;
           }
        }
      nodeCount=sz;
      double tot=bullAuth+bearAuth;
      pressure = tot>0 ? (bullAuth-bearAuth)/tot*100.0 : 0.0;
      pdir = pressure>12.0 ? 1 : pressure<-12.0 ? -1 : 0;

      // netBias: highest-TF active FU dir, fallback ema50
      netBias = 0;
      for(int i=0;i<7;i++)
         if(m_fu[i].o_valid && m_fu[i].o_dir!=0){ netBias=m_fu[i].o_dir; break; }
      if(netBias==0) netBias = m5close>m_ema50 ? 1 : m5close<m_ema50 ? -1 : 0;
     }
  };


//==================================================================
//= V60 phase strings (f_phaseStr) + helpers
//==================================================================
string V60PhaseStr(int c)
  {
   switch(c)
     {
      case 1:  return "Expansion";
      case 2:  return "Expansion Pre-Convexity";
      case 3:  return "Expansion Induction";
      case 4:  return "Expansion Liquidity";
      case 5:  return "New High";
      case 6:  return "New Low";
      case 7:  return "Transition";
      case 8:  return "Retracement";
      case 9:  return "HTF Flip Zone";
      case 10: return "Induction";
      case 11: return "Liquidation";
      case 12: return "Terminal Curve";
      case 13: return "Demand Return";
      case 14: return "Supply Return";
     }
   return "Point 4 Origin";
  }
bool Has(string s, string sub) { return StringFind(s, sub) >= 0; }

//==================================================================
//= MODULE: V60/Senseei result container (canonical decision)
//==================================================================
struct SenseeiOut
  {
   int    master;
   double alignment, conflict, threat, confidence, oppScore;
   string action, opportunity, intent, timing;
   // attack-sequence levels (entry / stop / targets) + wave geometry
   double atkEntry, atkStop, atkT1, atkT2, atkT3;
   double waveObj, waveOrigin;
   int    waveDir; double waveProgress;
   string phase;
  };

//==================================================================
//= MODULE: V60 — the unified engine (SE ladder + network + Senseei)
//==================================================================
class OmegaV60
  {
private:
   //--- the 6-TF SE ladder (M1,M3,M5,M15,H1,H4); M5 = canonical rung
   SEEngine        m_se[6];
   ENUM_TIMEFRAMES m_seTf[6];
   datetime        m_seLast[6];
   //--- the 7-TF FU network (MN,W,D,H4,H1,M15,M5)
   NetworkEngine   m_net;
   ENUM_TIMEFRAMES m_fuTf[7];
   datetime        m_fuLast[7];
   //--- canonical (M5) bar cache
   double          m_m5o, m_m5h, m_m5l, m_m5c, m_m5atr;
   //--- canonical bar counter
   int             m_barIndex;
   string          m_sym;

   //--- persistent structBias
   int             m_structBias;
   //--- spawn / wave state machine
   int             m_direction, m_lastSpawnDir;
   double          m_flipTop, m_flipBot, m_p4High, m_p4Low, m_cycleHigh, m_cycleLow;
   int             m_obBirthBar, m_contBar, m_entryCycle, m_waveDepth, m_waveGeneration;
   bool            m_isRecursive, m_recursiveComplete;
   int             m_recursiveFiredBar;
   //--- belief (smoothed)
   double          m_expBelief, m_convBelief, m_creatBelief, m_absBelief, m_retrBelief, m_dmdBelief;
   double          m_convexityMaturity, m_waveProgress, m_waveModelFit;
   bool            m_preConvEvidence, m_inductionEvidence;
   //--- liquidation engine (liqg) persistent state
   bool            m_liqgActive, m_liqgIsRetr; int m_liqgDir;
   double          m_liqgTarget, m_liqgInitDist;
   //--- attack-sequence latches
   bool            m_atkEntered, m_atkStop, m_atkT1, m_atkT2, m_atkT3;
   int             m_atkDirPrev;

public:
   SenseeiOut      out;

   //----------------------------------------------------------------
   void Init(string sym)
     {
      m_sym = sym;
      m_seTf[0]=PERIOD_M1;  m_seTf[1]=PERIOD_M3;  m_seTf[2]=PERIOD_M5;
      m_seTf[3]=PERIOD_M15; m_seTf[4]=PERIOD_H1;  m_seTf[5]=PERIOD_H4;
      for(int i=0;i<6;i++)
        {
         m_se[i].Init(InpPivotLen, InpAtrLen, InpEffLen, InpEffThresh, InpDispThresh,
                       InpConvMult, InpImpulseAtrMult, InpChochBufferATR, InpUseStrictStruct);
         m_seLast[i]=0;
        }
      m_fuTf[0]=PERIOD_MN1; m_fuTf[1]=PERIOD_W1;  m_fuTf[2]=PERIOD_D1;
      m_fuTf[3]=PERIOD_H4;  m_fuTf[4]=PERIOD_H1;  m_fuTf[5]=PERIOD_M15; m_fuTf[6]=PERIOD_M5;
      m_net.Init();
      for(int i=0;i<7;i++) m_fuLast[i]=0;
      m_barIndex=0; m_structBias=0;
      m_direction=m_lastSpawnDir=0;
      m_flipTop=m_flipBot=m_p4High=m_p4Low=m_cycleHigh=m_cycleLow=NA_VAL;
      m_obBirthBar=m_contBar=-1; m_entryCycle=m_waveDepth=m_waveGeneration=0;
      m_isRecursive=false; m_recursiveComplete=false; m_recursiveFiredBar=-100000;
      m_expBelief=m_convBelief=m_creatBelief=m_absBelief=m_retrBelief=m_dmdBelief=0;
      m_convexityMaturity=0; m_waveProgress=30.0; m_waveModelFit=50.0;
      m_preConvEvidence=m_inductionEvidence=false;
      m_liqgActive=false; m_liqgIsRetr=false; m_liqgDir=0;
      m_liqgTarget=NA_VAL; m_liqgInitDist=NA_VAL;
      m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=0;
      ZeroOut();
     }

   void ZeroOut()
     {
      out.master=0; out.alignment=out.conflict=out.threat=out.confidence=out.oppScore=0;
      out.action="WAIT"; out.opportunity="NONE"; out.intent="BALANCE"; out.timing="EARLY";
      out.atkEntry=out.atkStop=out.atkT1=out.atkT2=out.atkT3=NA_VAL;
      out.waveObj=out.waveOrigin=NA_VAL; out.waveDir=0; out.waveProgress=0; out.phase="—";
     }

   //----------------------------------------------------------------
   //  Warmup — seed every engine with history so the state machines
   //  are converged before live trading. Processes oldest -> newest.
   //----------------------------------------------------------------
   void Warmup(int bars)
     {
      // SE ladder
      for(int e=0;e<6;e++)
        {
         ENUM_TIMEFRAMES tf=m_seTf[e];
         int avail = Bars(m_sym, tf);
         int n = MathMin(bars, avail-2);
         for(int sh=n; sh>=1; sh--)
            m_se[e].Step(iOpen(m_sym,tf,sh), iHigh(m_sym,tf,sh), iLow(m_sym,tf,sh), iClose(m_sym,tf,sh));
         m_seLast[e]=iTime(m_sym,tf,0);
        }
      // FU network — step FU engines; canonical commits happen on M5 boundary,
      // but during warmup we approximate by committing once per processed M5 bar.
      for(int e=0;e<7;e++)
        {
         ENUM_TIMEFRAMES tf=m_fuTf[e];
         int avail = Bars(m_sym, tf);
         int n = MathMin(bars, avail-2);
         for(int sh=n; sh>=1; sh--)
            m_net.StepTF(e, iOpen(m_sym,tf,sh), iHigh(m_sym,tf,sh), iLow(m_sym,tf,sh), iClose(m_sym,tf,sh));
         m_fuLast[e]=iTime(m_sym,tf,0);
        }
      // prime canonical cache + register current FU tips / seed ema50 so the
      // node network contributes from the first live bar (rather than cold).
      m_m5o=iOpen(m_sym,PERIOD_M5,1); m_m5h=iHigh(m_sym,PERIOD_M5,1);
      m_m5l=iLow(m_sym,PERIOD_M5,1);  m_m5c=iClose(m_sym,PERIOD_M5,1);
      m_m5atr=m_se[2].atr;
      if(m_m5c>0) m_net.Commit(m_m5c, m_m5atr);
      OmegaLogger::LogInfo("V60", StringFormat("Warmup complete · %d bars/TF requested", bars));
     }

   //----------------------------------------------------------------
   //  Per-tick: advance any timeframe that printed a new closed bar.
   //  Returns true when a NEW canonical (M5) bar was processed (i.e.
   //  the Senseei verdict was refreshed).
   //----------------------------------------------------------------
   bool DriveBars()
     {
      bool canonStepped=false;
      // FU network TFs
      for(int e=0;e<7;e++)
        {
         ENUM_TIMEFRAMES tf=m_fuTf[e];
         datetime t0=iTime(m_sym,tf,0);
         if(t0!=0 && t0!=m_fuLast[e])
           {
            if(m_fuLast[e]!=0)
               m_net.StepTF(e, iOpen(m_sym,tf,1), iHigh(m_sym,tf,1), iLow(m_sym,tf,1), iClose(m_sym,tf,1));
            m_fuLast[e]=t0;
           }
        }
      // SE ladder TFs
      for(int e=0;e<6;e++)
        {
         ENUM_TIMEFRAMES tf=m_seTf[e];
         datetime t0=iTime(m_sym,tf,0);
         if(t0!=0 && t0!=m_seLast[e])
           {
            if(m_seLast[e]!=0)
              {
               double o=iOpen(m_sym,tf,1), h=iHigh(m_sym,tf,1), l=iLow(m_sym,tf,1), c=iClose(m_sym,tf,1);
               m_se[e].Step(o,h,l,c);
               if(e==2) // M5 canonical
                 {
                  m_m5o=o; m_m5h=h; m_m5l=l; m_m5c=c; m_m5atr=m_se[2].atr;
                  canonStepped=true;
                 }
              }
            m_seLast[e]=t0;
           }
        }
      if(canonStepped)
        {
         m_net.Commit(m_m5c, m_m5atr);
         ComputeCanonical();
        }
      return canonStepped;
     }

   //  ComputeCanonical defined below (continues this class).
   void ComputeCanonical();

   //--- accessors
   int    NodeBias()   const { return m_net.netBias; }
   double Pressure()   const { return m_net.pressure; }
   int    Pdir()       const { return m_net.pdir; }
   double CanonAtr()   const { return (m_m5atr>0)? m_m5atr : 0.0; }
   double CanonClose() const { return m_m5c; }
   int    Direction()  const { return m_direction; }
  };


//==================================================================
//= V60 helpers
//==================================================================
int DirByOrigin(double origin, int fallback, double close)
  {
   if(IsNa(origin)) return fallback;
   return close > origin ? 1 : close < origin ? -1 : fallback;
  }
double IdealSim(double e,double d,double v,double c,double eI,double dI,double vI,double cI)
  {
   double diff = (e-eI)*(e-eI)+(d-dI)*(d-dI)+(v-vI)*(v-vI)+(c-cI)*(c-cI);
   return MathMax(0.0, 100.0*(1.0 - diff/4.0));
  }

//==================================================================
//= OmegaV60::ComputeCanonical — the full V60 derived stack + Senseei
//==================================================================
void OmegaV60::ComputeCanonical()
  {
   m_barIndex++;
   double close=m_m5c, high=m_m5h, low=m_m5l, open=m_m5o;
   double atr=(m_m5atr>0)? m_m5atr : MathMax(close*0.001,1e-10);
   double m5Hi=high, m5Lo=low;

   //--- per-TF wave direction by origin (canonical close vs each inv)
   int m1_dir = DirByOrigin(m_se[0].o_inv, m_se[0].o_dir, close);
   int l3_dir = DirByOrigin(m_se[1].o_inv, m_se[1].o_dir, close);
   int l0_dir = DirByOrigin(m_se[2].o_inv, m_se[2].o_dir, close);
   int l1_dir = DirByOrigin(m_se[3].o_inv, m_se[3].o_dir, close);
   int l2_dir = DirByOrigin(m_se[4].o_inv, m_se[4].o_dir, close);
   int l4_dir = DirByOrigin(m_se[5].o_inv, m_se[5].o_dir, close);

   //--- fractal stack alignment
   int stackBull = (m1_dir==1?1:0)+(l3_dir==1?1:0)+(l0_dir==1?1:0)+(l1_dir==1?1:0)+(l2_dir==1?1:0)+(l4_dir==1?1:0);
   int stackBear = (m1_dir==-1?1:0)+(l3_dir==-1?1:0)+(l0_dir==-1?1:0)+(l1_dir==-1?1:0)+(l2_dir==-1?1:0)+(l4_dir==-1?1:0);
   int    fractalStackDir   = stackBull>stackBear?1:stackBear>stackBull?-1:0;
   double fractalStackScore = MathMax(stackBull,stackBear)/6.0*100.0;

   //--- M5-fixed market structure -> structBias
   double se5_sh=m_se[2].o_curSH, se5_sl=m_se[2].o_curSL, se5_psh=m_se[2].o_prSH, se5_psl=m_se[2].o_prSL;
   bool isHH=!IsNa(se5_sh)&&!IsNa(se5_psh)&&se5_sh>se5_psh;
   bool isLH=!IsNa(se5_sh)&&!IsNa(se5_psh)&&se5_sh<se5_psh;
   bool isHL=!IsNa(se5_sl)&&!IsNa(se5_psl)&&se5_sl>se5_psl;
   bool isLL=!IsNa(se5_sl)&&!IsNa(se5_psl)&&se5_sl<se5_psl;
   bool bullBOS=m_se[2].o_bos==1, bearBOS=m_se[2].o_bos==-1;
   if(InpUseStrictStruct){ if(isHH&&isHL) m_structBias=1; if(isLH&&isLL) m_structBias=-1; }
   else { if(bullBOS) m_structBias=1; if(bearBOS) m_structBias=-1; }
   int structBias=m_structBias;

   //--- canonical physics (from the M5 SE engine == f_phys)
   double velocity=m_se[2].vel, acceleration=m_se[2].acc, convSmooth=m_se[2].convSmooth;
   double efficiency=m_se[2].eff, displacement=m_se[2].disp;
   bool bullImpulse=m_se[2].bullImp, bearImpulse=m_se[2].bearImp;
   bool bullMomDecay=m_se[2].bullDec, bearMomDecay=m_se[2].bearDec;
   bool bullConvShift=m_se[2].bullCS, bearConvShift=m_se[2].bearCS;
   bool phys_vd70=m_se[2].vd70, phys_vd50=m_se[2].vd50;

   //--- physics observation layer
   double convexityScore = MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);
   double obs_Exp = MathMin((efficiency>InpEffThresh? efficiency*60.0: efficiency*30.0)
                    + (displacement>InpDispThresh? (displacement/MathMax(InpDispThresh,1e-10)-1.0)*20.0:0.0)
                    + (velocity>0&&acceleration>0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2
                       : velocity<0&&acceleration<0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2:0.0),100.0);
   double obs_Decay = MathMin((bullMomDecay||bearMomDecay?40.0:0.0)+(convexityScore>30.0?convexityScore*0.5:0.0)+(phys_vd70?30.0:0.0),100.0);
   double obs_Curv = convexityScore;
   double obs_Abs = MathMin((efficiency<InpEffThresh*0.7? (1.0-efficiency/MathMax(InpEffThresh,1e-10))*50.0:0.0)+(phys_vd50?30.0:0.0)+(displacement<InpDispThresh*0.5?20.0:0.0),100.0);
   double obs_Liq = MathMin(obs_Decay*0.4+obs_Curv*0.4+(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?20.0:0.0),100.0);

   //--- Engine 1A canonical phase
   string ie1a = V60PhaseStr(m_se[2].o_phase);

   //--- EDE
   int ede_state = (ie1a=="Point 4 Origin")?1:(ie1a=="Expansion")?1:(ie1a=="Expansion Pre-Convexity")?2:
                   (ie1a=="Expansion Induction")?3:(ie1a=="Expansion Liquidity")?4:
                   (ie1a=="New High")?5:(ie1a=="New Low")?5:6;
   double ede_expEnergy = MathMin(obs_Exp*0.50+(bullImpulse||bearImpulse?30.0:0.0)+efficiency*20.0,100.0);
   double ede_diss = MathMin((ede_state>=2?obs_Decay*0.40:0.0)+(ede_state>=3?obs_Curv*0.30:0.0)+(ede_state>=4?obs_Liq*0.30:0.0),100.0);
   double ede_dissProg = MathMin((ede_state>=2?25.0:0.0)+(ede_state>=3?25.0:0.0)+(ede_state>=4?25.0:0.0)+(ede_state>=5?25.0:0.0),100.0);

   //--- RE (consumes PREVIOUS spawn state)
   int re_expected = MathMax(1, MathMin(m_waveDepth+2, 4));
   int re_completed = MathMax(0, MathMin(m_entryCycle, re_expected));
   double re_recCompl = re_expected>0? MathMin((double)re_completed/(double)re_expected*100.0,100.0):0.0;
   double re_residual = MathMax(0.0, ede_expEnergy - ede_diss);
   bool re_objReached = ede_state>=5;
   bool re_fullDiss = ede_dissProg>=75.0;
   bool re_absRet = (ie1a=="Demand Return"||ie1a=="Supply Return") && m_recursiveComplete;
   string re_state = (re_absRet&&re_fullDiss&&re_recCompl>=75.0)?"RESOLVED":
                     (re_objReached&&ede_dissProg>=50.0)?"PARTIALLY RESOLVED":"UNRESOLVED";
   double re_residualScore = MathMin(re_residual,100.0);
   int resCode = re_state=="RESOLVED"?2: re_state=="PARTIALLY RESOLVED"?1:0;

   //--- EAE (consumes PREVIOUS spawn state)
   double eae_price = m_direction==0? NA_VAL :
                      re_state=="UNRESOLVED"? (m_direction==1? Nz(m_flipBot,close-atr*2.0): Nz(m_flipTop,close+atr*2.0)):
                      re_state=="PARTIALLY RESOLVED"? (m_direction==1? Nz(m_p4Low,close-atr): Nz(m_p4High,close+atr)) : NA_VAL;
   double eae_score = MathMin(re_residualScore*0.40 + (re_state=="UNRESOLVED"?30.0: re_state=="PARTIALLY RESOLVED"?20.0:5.0)
                      + (!IsNa(eae_price)? MathMax(0.0, 30.0 - MathAbs(close-eae_price)/MathMax(atr,1e-10)*5.0):0.0), 100.0);

   //--- liquidity sweep + heat (heat approximated; see note)
   double swH=-DBL_MAX, swL=DBL_MAX;
   for(int s=1;s<=InpLiqSweepLookback;s++){ swH=MathMax(swH,iHigh(m_sym,PERIOD_M5,s)); swL=MathMin(swL,iLow(m_sym,PERIOD_M5,s)); }
   bool liqSweepBull = !IsNa(m_flipTop) && swH>m_flipTop;
   bool liqSweepBear = !IsNa(m_flipBot) && swL<m_flipBot;
   // liqHeat: faithful heatmap dropped (panel-only); bounded proxy from dissipation/sweep.
   double liqHeat = OmegaMath::Clamp(obs_Liq*0.5 + (liqSweepBull||liqSweepBear?30.0:0.0), 0.0, 100.0);
   bool liqVacuum = liqHeat<10.0;
   bool liqSweepOK = !InpRequireLiqSweep
                     || (m_direction==1 && (liqSweepBull||liqVacuum))
                     || (m_direction==-1 && (liqSweepBear||liqVacuum));

   //--- liqg (liquidation engine; uses PREVIOUS convexityMaturity)
   double se5_tgt=m_se[2].o_tgt;
   bool liqgRetr = (ie1a=="Retracement Induction");
   bool liqgArm  = (ie1a=="Expansion Induction") || liqgRetr;
   double liqgObj = se5_tgt;
   if(liqgArm && !m_liqgActive && !IsNa(liqgObj))
     {
      m_liqgActive=true; m_liqgIsRetr=liqgRetr; m_liqgTarget=liqgObj;
      m_liqgDir = liqgObj>close?1:-1; m_liqgInitDist=MathMax(MathAbs(liqgObj-close),atr*0.5);
     }
   if(m_liqgActive && !IsNa(liqgObj)) m_liqgTarget=liqgObj;
   double liqgRemain = (m_liqgActive&&!IsNa(m_liqgTarget))? MathAbs(m_liqgTarget-close):NA_VAL;
   double liqgDistPct = (m_liqgActive&&!IsNa(liqgRemain))? MathMin(100.0, liqgRemain/MathMax(m_liqgInitDist,1e-10)*100.0):NA_VAL;
   bool liqgCapExh = ede_dissProg>60.0 || m_convexityMaturity>60.0;
   bool liqgResolved = re_state=="RESOLVED";
   bool liqgEnergyLo = efficiency < InpEffThresh*0.7;
   bool liqgMagnet = m_liqgActive && !IsNa(liqgDistPct) && liqgDistPct<20.0;
   bool liqgArrStruct = m_liqgActive && !IsNa(m_liqgTarget) && (m_liqgDir==1? close>=m_liqgTarget: close<=m_liqgTarget);
   bool liqgArrPhys = liqgCapExh && (liqgResolved||liqgMagnet);
   bool liqgObjArrival = liqgArrStruct && liqgEnergyLo && liqgArrPhys;
   bool liqgCounterBOS = m_liqgDir==1? bearBOS: bullBOS;
   bool liqgTrueCHoCH = liqgObjArrival && liqgCounterBOS && liqgEnergyLo && liqgResolved;
   bool liqgInWindow = ie1a=="Expansion Induction"||ie1a=="Expansion Liquidity"||ie1a=="Retracement Induction"||ie1a=="Retracement Liquidity";
   if(m_liqgActive && (!liqgInWindow || (liqgObjArrival && liqgTrueCHoCH))) m_liqgActive=false;

   //=== Section 11/12 — geometry · similarity · convexity maturity · progress
   double originToExtreme=NA_VAL;
   if(!IsNa(m_p4High)&&!IsNa(m_p4Low))
     {
      double org = m_direction==1? m_p4Low: m_p4High;
      double ext = m_direction==1? Nz(m_cycleHigh,org): Nz(m_cycleLow,org);
      originToExtreme = MathAbs(ext-org);
     }
   double flipzoneWidth = (!IsNa(m_flipTop)&&!IsNa(m_flipBot))? m_flipTop-m_flipBot:NA_VAL;
   double ref_eff  = MathMin(efficiency,1.0);
   double ref_disp = MathMin(displacement/MathMax(InpDispThresh*2.0,1e-10),1.0);
   double ref_vel  = MathMin(MathAbs(velocity)/MathMax(atr*0.15,1e-10),1.0);
   double ref_curv = MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult*2.0,1e-10),1.0);
   double sim_Exp   = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.85,0.80,0.80,0.10);
   double sim_PreC  = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.60,0.55,0.40,0.50);
   double sim_Ind   = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.65,0.60,0.30,0.60);
   double sim_Liqd  = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.45,0.85,0.15,0.80);
   double sim_Creat = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.30,0.70,0.05,0.90);
   double sim_Abs   = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.20,0.25,0.10,0.40);
   double sim_Retr  = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.70,0.65,0.65,0.25);
   double sim_DmdR  = IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.50,0.40,0.35,0.20);
   double waveTotalRange = !IsNa(originToExtreme)? originToExtreme : atr*5.0;
   double currentToExtreme = m_direction==1? MathAbs(Nz(m_cycleHigh,close+atr)-close): MathAbs(close-Nz(m_cycleLow,close-atr));
   double posNormDen = MathMax(waveTotalRange, atr*0.5);
   double posDistToCreation = MathMin(currentToExtreme/posNormDen*100.0,100.0);
   double expWeakness = MathMin(((efficiency<InpEffThresh? (1.0-efficiency/MathMax(InpEffThresh,1e-10))*40.0:0.0)
                        + obs_Decay*0.30
                        + (MathAbs(velocity)<MathAbs(m_se[2].velPrev2())*0.6?20.0:0.0)) * (100.0/90.0), 100.0);
   double inductionMat = MathMin((m_inductionEvidence?35.0:0.0)+obs_Curv*0.35+(m_preConvEvidence?20.0:0.0)
                         +(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?10.0:0.0),100.0);
   double liqMat = MathMin(obs_Liq*0.50+(liqSweepBull||liqSweepBear?30.0:0.0)+(liqHeat>60.0?20.0:liqHeat>30.0?10.0:0.0),100.0);
   double rawConvexityMaturity = MathMin(expWeakness*0.35+inductionMat*0.35+liqMat*0.30,100.0);
   double bSm = 2.0/(InpBeliefSmooth+1.0);
   m_convexityMaturity += bSm*(rawConvexityMaturity - m_convexityMaturity);
   double progressFromGeom=NA_VAL;
   if(!IsNa(m_p4High)&&!IsNa(m_flipTop)&&!IsNa(m_flipBot))
     {
      double org = m_direction==1? m_p4Low: m_p4High;
      double ext = m_direction==1? Nz(m_cycleHigh,close+atr): Nz(m_cycleLow,close-atr);
      double fzMid=(m_flipTop+m_flipBot)/2.0;
      double totalMove=MathAbs(ext-org);
      double toFzMid=MathAbs(ext-fzMid);
      double expProg = totalMove>1e-10? MathMin(MathAbs(close-org)/totalMove*60.0,60.0):30.0;
      double retrMove=MathAbs(close-ext);
      double retrProg = toFzMid>1e-10? MathMin(retrMove/MathMax(toFzMid,1e-10)*40.0,40.0):0.0;
      progressFromGeom = expProg + retrProg*MathMin(obs_Abs/40.0,1.0);
     }
   double geomProgress = Nz(progressFromGeom,30.0);
   double simAnchor = (sim_DmdR>=sim_Retr&&sim_DmdR>=sim_Abs&&sim_DmdR>=sim_Creat&&sim_DmdR>=sim_Exp)?95.0:
                      (sim_Retr>=sim_Abs&&sim_Retr>=sim_Creat&&sim_Retr>=sim_Exp)?87.0:
                      (sim_Abs>=sim_Creat&&sim_Abs>=sim_Exp)?75.0:
                      (sim_Creat>=sim_Liqd&&sim_Creat>=sim_Exp)?62.0:
                      (sim_Liqd>=sim_Ind&&sim_Liqd>=sim_Exp)?52.0:
                      (sim_Ind>=sim_PreC&&sim_Ind>=sim_Exp)?43.0:
                      (sim_PreC>=sim_Exp)?33.0:22.0;
   double convWeight = MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
   double physProgress = simAnchor + (m_convexityMaturity/100.0)*(simAnchor-33.0)*0.50*convWeight;
   double rawWaveProgress = geomProgress*0.60 + physProgress*0.40;
   m_waveProgress += bSm*(rawWaveProgress - m_waveProgress);
   m_waveProgress = OmegaMath::Clamp(m_waveProgress,0.0,100.0);
   double bestSim = MathMax(sim_Exp,MathMax(sim_PreC,MathMax(sim_Ind,MathMax(sim_Liqd,MathMax(sim_Creat,MathMax(sim_Abs,MathMax(sim_Retr,sim_DmdR)))))));
   double geomConsistency = MathMin((!IsNa(originToExtreme)&&originToExtreme>atr*2.0?30.0:0.0)
                            +(!IsNa(flipzoneWidth)&&flipzoneWidth<atr*4.0?25.0:0.0)
                            +((!IsNa(m_cycleHigh)||!IsNa(m_cycleLow))?20.0:0.0)
                            +(m_direction!=0?25.0:0.0),100.0);
   m_waveModelFit += bSm*((bestSim*0.55+geomConsistency*0.45)-m_waveModelFit);
   m_waveModelFit = OmegaMath::Clamp(m_waveModelFit,0.0,100.0);

   //=== Section 12A — belief engine
   m_preConvEvidence = bullMomDecay||bearMomDecay;
   m_inductionEvidence = (m_direction==1&&bearImpulse&&structBias==1)||(m_direction==-1&&bullImpulse&&structBias==-1);
   bool liquidityEvidence = obs_Liq>50.0 && obs_Decay>40.0;
   double expPosMult = m_waveProgress<40.0?1.20: m_waveProgress<60.0?0.80:0.50;
   double rawExp = MathMin((obs_Exp*0.45+(bullImpulse||bearImpulse?30.0:0.0)+(efficiency>InpEffThresh*1.1?15.0:0.0)+sim_Exp*0.10)*expPosMult,100.0);
   double convPosMult = (m_waveProgress>=30.0&&m_waveProgress<=65.0)?1.30:0.70;
   double rawConv = MathMin((obs_Decay*0.30+obs_Curv*0.25+(m_preConvEvidence?15.0:0.0)+(m_inductionEvidence?10.0:0.0)+(liquidityEvidence?5.0:0.0)+m_convexityMaturity*0.08)*convPosMult,100.0);
   double creatPosMult = (m_waveProgress>=45.0&&m_waveProgress<=68.0)?1.40:0.60;
   double creatExtra = (!IsNa(m_cycleHigh)&&!IsNa(m_cycleLow)&&((m_direction==1&&high>=Nz(m_cycleHigh,high)*0.998)||(m_direction==-1&&low<=Nz(m_cycleLow,low)*1.002))?20.0:0.0);
   double rawCreat = MathMin(((m_convexityMaturity>50.0?m_convexityMaturity*0.12:0.0)+(obs_Decay>60.0?obs_Decay*0.20:0.0)+(obs_Liq>50.0?obs_Liq*0.20:0.0)+(obs_Abs>20.0?obs_Abs*0.15:0.0)+creatExtra+sim_Creat*0.10+(posDistToCreation<15.0?(15.0-posDistToCreation)*1.0:0.0))*creatPosMult,100.0);
   double rawAbs = MathMin(obs_Abs*0.50+(efficiency<InpEffThresh*0.6?25.0:0.0)+(displacement<InpDispThresh*0.5?15.0:0.0)+sim_Abs*0.10,100.0);
   double rawRetr = MathMin(((m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse)?45.0:0.0)+(rawAbs>50.0?rawAbs*0.30:0.0)+(obs_Curv>40.0?15.0:0.0)+sim_Retr*0.10,100.0);
   double rawDmd = MathMin((!IsNa(m_flipTop)&&!IsNa(m_flipBot)&&close<=m_flipTop&&close>=m_flipBot?35.0:0.0)+(rawRetr>60.0?rawRetr*0.30:0.0)+(liqHeat>50.0?liqHeat*0.15:0.0)+(liqSweepBull||liqSweepBear?20.0:0.0)+sim_DmdR*0.10,100.0);
   m_expBelief   += bSm*(rawExp   - m_expBelief);
   m_convBelief  += bSm*(rawConv  - m_convBelief);
   m_creatBelief += bSm*(rawCreat - m_creatBelief);
   m_absBelief   += bSm*(rawAbs   - m_absBelief);
   m_retrBelief  += bSm*(rawRetr  - m_retrBelief);
   m_dmdBelief   += bSm*(rawDmd   - m_dmdBelief);

   //=== Section 13 — spawn / wave state machine (M5-governed)
   double l0_p4High=m_se[2].o_p4h, l0_p4Low=m_se[2].o_p4l;
   bool allowSpawn = l0_dir!=0 && l0_dir!=m_direction;
   if(allowSpawn)
     {
      double obTop=Nz(l0_p4High,close), obBot=Nz(l0_p4Low,close);
      m_lastSpawnDir=l0_dir; m_direction=l0_dir;
      m_flipTop=obTop; m_flipBot=obBot;
      m_obBirthBar=m_barIndex; m_contBar=-1;
      m_p4High=obTop; m_p4Low=obBot;
      m_cycleHigh=m5Hi; m_cycleLow=m5Lo;
      m_isRecursive=false; m_entryCycle=0; m_waveDepth=0;
     }
   if(m_direction==1  && m5Hi>Nz(m_cycleHigh,m5Hi)) m_cycleHigh=m5Hi;
   if(m_direction==-1 && m5Lo<Nz(m_cycleLow,m5Lo)) m_cycleLow=m5Lo;

   bool priceInDemand = !IsNa(m_flipBot)&&low<m_flipBot&&(!IsNa(m_p4High)&&low<=m_p4High);
   bool priceInSupply = !IsNa(m_flipTop)&&high>m_flipTop&&(!IsNa(m_p4Low)&&high>=m_p4Low);
   bool trueCHoCH_bull = m_direction==1&&priceInDemand&&bullImpulse&&liqSweepOK;
   bool trueCHoCH_bear = m_direction==-1&&priceInSupply&&bearImpulse&&liqSweepOK;
   bool structFlipBull = m_direction==1&&bullConvShift&&structBias==-1;
   bool structFlipBear = m_direction==-1&&bearConvShift&&structBias==1;
   bool recursiveTrigger = (trueCHoCH_bull||trueCHoCH_bear||structFlipBull||structFlipBear)
                           &&(ie1a=="Demand Return"||ie1a=="Supply Return")&&m_dmdBelief>40.0&&m_direction!=0&&!IsNa(m_flipTop);
   bool recursiveJustFired=false;
   if(recursiveTrigger && (m_barIndex-m_recursiveFiredBar)>InpResetBars)
     { recursiveJustFired=true; m_recursiveFiredBar=m_barIndex; m_recursiveComplete=true; }
   if(recursiveJustFired)
     {
      m_waveGeneration++; m_entryCycle=MathMin(m_entryCycle+1,4); m_isRecursive=true; m_waveDepth=m_entryCycle;
      int nextDir = l0_dir!=0? l0_dir : ((bullImpulse||bullConvShift)?1:-1);
      m_lastSpawnDir=nextDir; m_direction = l0_dir!=0? l0_dir: nextDir;
      m_flipTop=Nz(l0_p4High,close); m_flipBot=Nz(l0_p4Low,close);
      m_obBirthBar=m_barIndex; m_p4High=m_flipTop; m_p4Low=m_flipBot;
      m_cycleHigh=m5Hi; m_cycleLow=m5Lo; m_contBar=m_barIndex;
     }
   int barsSinceCont = (m_contBar>=0)? m_barIndex-m_contBar : (m_obBirthBar>=0? m_barIndex-m_obBirthBar:0);
   bool bullInvalid = m_direction==1 && !IsNa(m_flipBot) && close < m_flipBot - atr*0.5;
   bool bearInvalid = m_direction==-1 && !IsNa(m_flipTop) && close > m_flipTop + atr*0.5;
   bool opposingMove = (m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse);
   bool hardInvalid = bullInvalid||bearInvalid;
   bool softReset = barsSinceCont>InpResetBars && opposingMove && (ie1a!="Demand Return"&&ie1a!="Supply Return") && m_dmdBelief<30.0 && m_expBelief<30.0;
   if(m_direction!=l0_dir && (hardInvalid||softReset))
     {
      m_direction=0; m_lastSpawnDir=0; m_flipTop=NA_VAL; m_flipBot=NA_VAL;
      m_contBar=-1; m_obBirthBar=-1; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0; m_recursiveComplete=false;
     }

   //--- legacy aliases the Senseei layer reads
   int    waveDir   = l0_dir;
   int    stackDir  = fractalStackDir;
   double stackPct  = fractalStackScore;
   double waveOrigin= m_se[2].o_inv;
   double waveObj   = Nz(m_liqgTarget, m_se[2].o_tgt);

   //=== Attack sequence (entry / stop / targets)
   double atkEntry = (!IsNa(m_flipTop)&&!IsNa(m_flipBot))? (m_flipTop+m_flipBot)/2.0 : NA_VAL;
   double atkStop  = m_se[2].o_inv;
   double atkT1    = waveObj;
   double atkT2    = m_se[3].o_tgt;     // se15 objective
   double atkT3    = m_se[4].o_tgt;     // se60 (H1) objective
   int atkBias = (IsNa(atkEntry)||IsNa(atkT1))? (waveDir!=0?waveDir:m_direction) : (atkT1>=atkEntry?1:-1);
   double atkRef = Nz(atkEntry, close);
   if(atkBias!=m_atkDirPrev){ m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=atkBias; }
   if(!IsNa(atkEntry) && (atkBias==1? low<=atkEntry: high>=atkEntry)) m_atkEntered=true;
   if(!IsNa(atkStop) && (atkStop<atkRef? close<atkStop: close>atkStop)) m_atkStop=true;
   if(!IsNa(atkT1) && (atkT1>=atkRef? high>=atkT1: low<=atkT1)) m_atkT1=true;
   if(!IsNa(atkT2) && (atkT2>=atkRef? high>=atkT2: low<=atkT2)) m_atkT2=true;
   if(!IsNa(atkT3) && (atkT3>=atkRef? high>=atkT3: low<=atkT3)) m_atkT3=true;

   //=== TIE — time intelligence (5-cycle bias stack)
   double mnO=iOpen(m_sym,PERIOD_MN1,0), wO=iOpen(m_sym,PERIOD_W1,0), dO=iOpen(m_sym,PERIOD_D1,0);
   double h4O=iOpen(m_sym,PERIOD_H4,0), h1O=iOpen(m_sym,PERIOD_H1,0);
   int tBull=(close>mnO?1:0)+(close>wO?1:0)+(close>dO?1:0)+(close>h4O?1:0)+(close>h1O?1:0);
   int tBear=(close<mnO?1:0)+(close<wO?1:0)+(close<dO?1:0)+(close<h4O?1:0)+(close<h1O?1:0);
   double timeAlign = (tBull+tBear)>0? MathMax(tBull,tBear)/(double)(tBull+tBear)*100.0 : 50.0;
   double timeConflict = 100.0 - timeAlign;

   //=== PART C/D — SENSEEI meta-intelligence (the sole authority)
   int netBias = m_net.netBias;
   int pdir    = m_net.pdir;
   int eligN   = m_net.eligibleNodes;
   double residual = re_residualScore;
   double attractor = eae_score;

   int vt1=waveDir, vt2=stackDir, vt3=netBias, vt4=pdir;
   int sum=vt1+vt2+vt3+vt4;
   int master = sum>0?1:sum<0?-1:0;
   int cast=(vt1!=0?1:0)+(vt2!=0?1:0)+(vt3!=0?1:0)+(vt4!=0?1:0);
   int forV=(vt1==master&&vt1!=0?1:0)+(vt2==master&&vt2!=0?1:0)+(vt3==master&&vt3!=0?1:0)+(vt4==master&&vt4!=0?1:0);
   double alignment = cast>0? (double)forV/cast*100.0 : 50.0;
   double conflict  = cast>0? (double)(cast-forV)/cast*100.0 : 0.0;
   double threat = OmegaMath::Clamp(conflict*0.40 + residual*0.28 + timeConflict*0.12
                   + (pdir!=0&&pdir!=master?18.0:0.0) + (resCode==1?10.0:0.0), 0.0, 100.0);
   double confidence = OmegaMath::Clamp(alignment*0.40 + timeAlign*0.12 + stackPct*0.18
                       + attractor*0.15 + MathMin(15.0, eligN*1.2) - threat*0.20, 0.0, 100.0);
   string timing = (Has(ie1a,"Absorption")||resCode==2)?"RESOLVED":
                   m_waveProgress<15.0?"VERY EARLY": m_waveProgress<35.0?"EARLY":
                   m_waveProgress<55.0?"DEVELOPING": m_waveProgress<80.0?"MID CYCLE":
                   m_waveProgress<96.0?"LATE":"TERMINAL";
   string intent = conflict>55.0?"ABSORPTION": m_liqgActive?"DELIVERY":
                   (Has(ie1a,"Expansion")&&!Has(ie1a,"Pre-Convexity")&&!Has(ie1a,"Induction")&&!Has(ie1a,"Liquidity"))?"EXPANSION":
                   Has(ie1a,"Pre-Convexity")?"CONTINUATION":
                   Has(ie1a,"Induction")?"RESOLUTION":
                   Has(ie1a,"Liquidity")?"DELIVERY":
                   (Has(ie1a,"New High")||Has(ie1a,"New Low"))?"DELIVERY":
                   Has(ie1a,"Absorption")?"ABSORPTION":
                   master==0?"BALANCE":"CONTINUATION";
   double oppScore = OmegaMath::Clamp(alignment*0.40 + attractor*0.30 + stackPct*0.30 - threat*0.35, 0.0, 100.0);
   string opportunity = master==0?"NONE": conflict>60.0?"DEVELOPING":
                        oppScore<20.0?"NONE": oppScore<40.0?"DEVELOPING":
                        oppScore<62.0?"GOOD": oppScore<82.0?"STRONG":"EXCEPTIONAL";
   bool strong=(opportunity=="STRONG"||opportunity=="EXCEPTIONAL");
   bool good=(opportunity=="GOOD"||opportunity=="STRONG");
   string action = master==0?"WAIT": conflict>60.0?"WAIT": resCode==2?"MANAGE / EXIT":
                   (strong&&confidence>=(double)InpSenseeiMinConf&&threat<45.0)?"ATTACK":
                   good?"PREPARE":"WAIT";

   //--- publish
   out.master=master; out.alignment=alignment; out.conflict=conflict; out.threat=threat;
   out.confidence=confidence; out.oppScore=oppScore;
   out.action=action; out.opportunity=opportunity; out.intent=intent; out.timing=timing;
   out.atkEntry=atkEntry; out.atkStop=atkStop; out.atkT1=atkT1; out.atkT2=atkT2; out.atkT3=atkT3;
   out.waveObj=waveObj; out.waveOrigin=waveOrigin; out.waveDir=waveDir; out.waveProgress=m_waveProgress;
   out.phase=ie1a;
  }


//==================================================================
//= MODULE: Execution — CTrade router driven by Senseei.action
//==================================================================
//   The ONLY decision authority is V60's Senseei. There is no V72
//   DOE / DecisionEngine veto layer here — it was removed because it
//   contradicted V60. Capital drawdown guards may still stand the
//   engine down (risk safety is not a competing signal).
//==================================================================
class OmegaExec
  {
private:
   CTrade m_trade;
   string m_sym;
   long   m_magic;
   int    m_digits;
   double m_point;
   long   m_stopsLevel;

public:
   void Init(string sym, long magic, int slippage)
     {
      m_sym=sym; m_magic=magic;
      m_digits=(int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_point=SymbolInfoDouble(sym, SYMBOL_POINT);
      m_stopsLevel=(long)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFillingBySymbol(sym);
     }

   int CountActive(int dir=0)
     {
      int n=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong tk=PositionGetTicket(i);
         if(tk==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic) continue;
         int pd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
         if(dir==0 || pd==dir) n++;
        }
      return n;
     }
   int NetDir()
     {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong tk=PositionGetTicket(i);
         if(tk==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic) continue;
         return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
        }
      return 0;
     }
   void CloseAll(string why)
     {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong tk=PositionGetTicket(i);
         if(tk==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic) continue;
         if(m_trade.PositionClose(tk))
            OmegaLogger::LogExec("EXEC", StringFormat("Closed #%I64u · %s", tk, why));
         else
            OmegaLogger::LogWarning("EXEC", StringFormat("Close failed #%I64u ret=%d", tk, m_trade.ResultRetcode()));
        }
     }

private:
   double NormPx(double p) { return NormalizeDouble(p, m_digits); }
   double MinStopDist()    { return (double)m_stopsLevel * m_point; }

   double ComputeStop(int dir, SenseeiOut &o, double entry, double atr)
     {
      double stop;
      if(!IsNa(o.atkStop) && ((dir==1 && o.atkStop<entry) || (dir==-1 && o.atkStop>entry)))
         stop = o.atkStop;
      else
         stop = (dir==1)? entry - InpMinStopAtr*atr : entry + InpMinStopAtr*atr;
      // enforce broker minimum stop distance
      double md = MinStopDist();
      if(md>0)
        {
         if(dir==1  && (entry-stop)<md) stop = entry-md;
         if(dir==-1 && (stop-entry)<md) stop = entry+md;
        }
      return NormPx(stop);
     }
   double ComputeTP(int dir, SenseeiOut &o, double entry)
     {
      if(!InpUseTargetTP) return 0.0;
      if(IsNa(o.atkT1)) return 0.0;
      if((dir==1 && o.atkT1>entry) || (dir==-1 && o.atkT1<entry))
        {
         double tp=o.atkT1; double md=MinStopDist();
         if(md>0)
           {
            if(dir==1  && (tp-entry)<md) return 0.0;
            if(dir==-1 && (entry-tp)<md) return 0.0;
           }
         return NormPx(tp);
        }
      return 0.0;
     }

public:
   bool OpenCampaign(int dir, SenseeiOut &o, OmegaCapital &cap, double atr)
     {
      if(dir==0 || atr<=0) return false;
      double ask=SymbolInfoDouble(m_sym, SYMBOL_ASK);
      double bid=SymbolInfoDouble(m_sym, SYMBOL_BID);
      double entry=(dir==1)?ask:bid;
      double stop=ComputeStop(dir, o, entry, atr);
      double stopPts=MathAbs(entry-stop)/m_point;
      if(stopPts<=0) stopPts=InpMinStopAtr*atr/m_point;
      double conviction=OmegaMath::Clamp(o.confidence/100.0, 0.0, 1.0);
      double lots=OmegaRisk::LotsFor(m_sym, stopPts, InpRiskPctBase, conviction, cap.Throttle());
      if(lots<=0) { OmegaLogger::LogWarning("EXEC","Sizing returned 0 lots — skip"); return false; }
      double tp=ComputeTP(dir, o, entry);
      bool ok = (dir==1)? m_trade.Buy(lots, m_sym, 0.0, stop, tp, "OmegaV60 ATTACK")
                        : m_trade.Sell(lots, m_sym, 0.0, stop, tp, "OmegaV60 ATTACK");
      if(ok)
         OmegaLogger::LogExec("EXEC", StringFormat("OPEN %s · lots=%.2f · SL=%.5f TP=%.5f · conf=%.0f opp=%s",
                               dir==1?"LONG":"SHORT", lots, stop, tp, o.confidence, o.opportunity));
      else
         OmegaLogger::LogWarning("EXEC", StringFormat("OPEN failed ret=%d", m_trade.ResultRetcode()));
      return ok;
     }

   void TrailToInvalidation(SenseeiOut &o)
     {
      if(!InpTrailStops) return;
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong tk=PositionGetTicket(i);
         if(tk==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic) continue;
         int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
         double curSL=PositionGetDouble(POSITION_SL);
         double curTP=PositionGetDouble(POSITION_TP);
         double newSL=o.atkStop;
         if(IsNa(newSL)) continue;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         // only tighten in the trade's favour, never loosen
         bool improve = (dir==1)? (newSL>curSL && newSL<SymbolInfoDouble(m_sym,SYMBOL_BID))
                                : (newSL<curSL && newSL>SymbolInfoDouble(m_sym,SYMBOL_ASK));
         if(curSL==0.0) improve = (dir==1)? (newSL<SymbolInfoDouble(m_sym,SYMBOL_BID))
                                          : (newSL>SymbolInfoDouble(m_sym,SYMBOL_ASK));
         if(improve)
           {
            double md=MinStopDist();
            double px=(dir==1)?SymbolInfoDouble(m_sym,SYMBOL_BID):SymbolInfoDouble(m_sym,SYMBOL_ASK);
            if(md>0 && MathAbs(px-newSL)<md) continue;
            m_trade.PositionModify(tk, NormPx(newSL), curTP);
           }
        }
     }
  };

//==================================================================
//= GLOBALS
//==================================================================
OmegaState   g_state;
OmegaCapital g_capital;
OmegaV60     g_v60;
OmegaExec    g_exec;
datetime     g_lastHeartbeat = 0;
long         g_tickCount = 0;
string       g_lastAction = "WAIT";

//==================================================================
//= Feed the Omega Trinity FROM V60 (V60 is the organism core)
//==================================================================
void FeedTrinity()
  {
   // life       = residual energy proxy (story still alive)  -> attractor*0.5 + (100-threat)*0.5
   // stability  = Senseei alignment (narrative coherence)
   // confidence = Senseei self-trust
   g_state.life       = OmegaMath::Clamp((100.0 - g_v60.out.threat)*0.5 + g_v60.out.oppScore*0.5, 0.0, 100.0);
   g_state.stability  = g_v60.out.alignment;
   g_state.confidence = g_v60.out.confidence;
   g_state.primed     = true;
   g_state.Clamp();
  }

//==================================================================
//= Senseei decision router — the canonical authority
//==================================================================
void RouteSenseei()
  {
   SenseeiOut o = g_v60.out;
   double atr = g_v60.CanonAtr();
   int posDir = g_exec.NetDir();
   int adds   = g_exec.CountActive();

   // Capital safety (not a competing signal — pure risk guard)
   if(g_capital.RequiresFlat())
     {
      if(posDir!=0) g_exec.CloseAll("Capital SUSPENDED");
      return;
     }

   g_lastAction = o.action;

   if(o.action=="MANAGE / EXIT")
     {
      if(posDir!=0) g_exec.CloseAll("Senseei MANAGE/EXIT (energy resolved)");
      return;
     }

   if(o.action=="ATTACK" && o.master!=0)
     {
      if(g_capital.BlocksEntries())
        {
         OmegaLogger::LogWarning("EXEC","ATTACK suppressed · capital restricted");
         return;
        }
      if(posDir==0)
        {
         g_exec.OpenCampaign(o.master, o, g_capital, atr);
        }
      else if(posDir==o.master)
        {
         if(InpAllowAdds && adds < (InpMaxAddsPerCampaign+1))
            g_exec.OpenCampaign(o.master, o, g_capital, atr);   // pyramid add
        }
      else // holding opposite to master -> reverse
        {
         g_exec.CloseAll("Senseei reverse (master flip)");
         g_exec.OpenCampaign(o.master, o, g_capital, atr);
        }
      return;
     }

   // PREPARE / WAIT -> hold; protective stop trails to invalidation.
   g_exec.TrailToInvalidation(o);
  }

//==================================================================
//= OnInit
//==================================================================
int OnInit()
  {
   OmegaLogger::SetMinLevel(LOG_INFO);
   OmegaLogger::LogInfo("EA", StringFormat("F72 OMEGA · V60 CORE v%s · %s · TF=%s",
                         OMEGA_VERSION, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period)));

   g_capital.Init(InpDailyLimitPct, InpWeeklyLimitPct, InpHardLimitPct);
   g_exec.Init(_Symbol, InpMagic, InpSlippagePoints);
   g_v60.Init(_Symbol);
   g_v60.Warmup(InpWarmupBars);
   FeedTrinity();

   EventSetTimer(MathMax(5, InpHeartbeatSec));
   OmegaLogger::LogInfo("EA","Initialized · Senseei is the sole decision authority · V72/DOE removed.");
   return INIT_SUCCEEDED;
  }

//==================================================================
//= OnDeinit
//==================================================================
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
   OmegaLogger::LogInfo("EA", StringFormat("Deinit · reason=%d", reason));
  }

//==================================================================
//= OnTick — drive bars, refresh trinity, route the Senseei verdict
//==================================================================
void OnTick()
  {
   g_tickCount++;
   g_state.tickCount=g_tickCount;
   g_state.updated=TimeCurrent();

   g_capital.Update();

   if(g_capital.RequiresFlat() && g_exec.CountActive()>0)
      g_exec.CloseAll("Capital SUSPENDED — flat all");

   bool newCanonBar = g_v60.DriveBars();
   if(newCanonBar)
     {
      FeedTrinity();
      RouteSenseei();
     }

   if(InpShowComment)
     {
      SenseeiOut o=g_v60.out;
      string c=StringFormat(
        "F72 OMEGA · V60 CORE\n"
        "Senseei: %s %s · opp=%s · conf=%.0f thrt=%.0f align=%.0f\n"
        "Phase: %s · progress=%.0f%% · intent=%s · timing=%s\n"
        "Trinity: L=%.0f S=%.0f C=%.0f\n"
        "Net bias=%d pressure=%.0f pdir=%d · waveDir=%d\n"
        "Capital: %s · throttle=%.2f · pos=%d",
        o.master==1?"BULL":o.master==-1?"BEAR":"—", o.action, o.opportunity,
        o.confidence, o.threat, o.alignment,
        o.phase, o.waveProgress, o.intent, o.timing,
        g_state.life, g_state.stability, g_state.confidence,
        g_v60.NodeBias(), g_v60.Pressure(), g_v60.Pdir(), o.waveDir,
        OmegaStr::CapitalStateToString(g_capital.State()), g_capital.Throttle(),
        g_exec.CountActive());
      Comment(c);
     }
  }

//==================================================================
//= OnTimer — heartbeat
//==================================================================
void OnTimer()
  {
   datetime now=TimeCurrent();
   if(g_lastHeartbeat==0 || (now-g_lastHeartbeat)>=InpHeartbeatSec)
     {
      g_lastHeartbeat=now;
      SenseeiOut o=g_v60.out;
      OmegaLogger::LogInfo("HEARTBEAT", StringFormat(
         "%s · %s · cap=%s · %s",
         _Symbol, g_state.Snapshot(),
         OmegaStr::CapitalStateToString(g_capital.State()),
         StringFormat("SENSEEI %s %s opp=%s conf=%.0f thrt=%.0f · phase=%s prog=%.0f%% · netBias=%d pdir=%d",
                       o.master==1?"BULL":o.master==-1?"BEAR":"—", o.action, o.opportunity,
                       o.confidence, o.threat, o.phase, o.waveProgress, g_v60.NodeBias(), g_v60.Pdir())));
     }
  }
//+------------------------------------------------------------------+
