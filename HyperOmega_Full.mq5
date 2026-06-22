//+------------------------------------------------------------------+
//|                                                  HyperOmega.mq5   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|  A continuously self-aware, multi-symbol campaign manager.       |
//|  Governed by .kiro/specs/omega-f72/spec.md.                      |
//|                                                                  |
//|  Architecture (upward-only flow; nothing deleted):               |
//|    F60 substrate  (physics · structure · curve framework ·       |
//|        recursive curve tree · Invisible Network · participants · |
//|        fractal stack · FCE · time intelligence · deep cognition) |
//|      -> Observers  (ERF·FRZ·RIE·MCE·NE·TQE·TE·IE2·WR/DWR)        |
//|      -> HyperIntelligence (opportunity engine · entry families)  |
//|      -> Risk (Trinity · Capital · exposure · master override)    |
//|      -> Execution (multi-style)                                  |
//|      -> Position Intelligence ──► feeds back to HyperIntelligence |
//|                                                                  |
//|  This is a MODULAR build. Each Include/*.mqh is one stratum.     |
//|  Built in parts (see .kiro task list); this is the integration   |
//|  unit that wires them together.                                  |
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
input int    InpMaxConcurrent    = 3;       // Max concurrent campaigns
input long   InpMagic            = 720072;  // Magic number

input group "=== F60 · structure engine (f_phys / f_se) ==="
input int    InpPivotLen         = 5;       // Pivot length
input int    InpAtrLen           = 14;      // ATR length
input int    InpEffLen           = 10;      // Efficiency lookback
input double InpEffThresh        = 0.65;    // Efficiency threshold
input double InpDispThresh       = 1.5;     // Displacement ATR threshold
input double InpConvMult         = 0.01;    // Convexity ATR multiplier
input double InpImpulseAtrMult   = 1.5;     // Impulse ATR multiple
input double InpChochBufferATR   = 0.75;    // CHoCH buffer (ATR)
input bool   InpUseStrictStruct  = true;    // Strict structure (HH/HL)

input group "=== F60 · Invisible Network ==="
input double InpWickFrac         = 0.3;     // FU spike: min wick / range
input int    InpFuLookback       = 3;       // FU spike: structure lookback
input int    InpAuthMin          = 45;      // Min node authority (eligible)
input int    InpNodeMax          = 250;     // Max remembered nodes
input int    InpDormantBars      = 120;     // Bars until dormant
input int    InpHistoryBars      = 600;     // Bars until historical

input group "=== F60 · curve tree / compression ==="
input int    InpBeliefSmooth     = 3;       // Belief / maturity EMA smoothing
input int    InpResetBars        = 20;      // Min bars before wave reset
input int    InpLiqSweepLookback = 10;      // Liquidity sweep lookback bars
input bool   InpRequireLiqSweep  = true;    // Require liquidity sweep for true CHoCH

input group "=== HyperIntelligence ==="
input int    InpMinConviction    = 55;      // Min opportunity conviction to act
input double InpMinAsymmetry     = 1.3;     // Min reward:risk*prob to act
input bool   InpAllowCountertrend= true;    // Allow counter-trend (reduced) entries
input bool   InpAllowAdds        = true;    // Allow continuation adds
input int    InpMaxAddsPerCampaign = 2;     // Max adds per campaign

input group "=== Risk / Capital (Omega inheritance) ==="
input double InpRiskPctBase      = 0.5;     // Base risk % (full conviction/size)
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
input bool   InpCsvLogs          = false;   // Write CSV logs


//==================================================================
//= INLINED MODULES (single-file build of the modular project)
//==================================================================

// ====================== Include/Common.mqh ======================
//+------------------------------------------------------------------+
//|                                                       Common.mqh |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Layer 0 — Universe primitives. Every other module includes     |
//|   this. NO module above this defines its own enums for           |
//|   cross-cutting concerns. Single source of truth.                |
//|                                                                  |
//|   Preserved from the F72 Omega lineage (Ancestry Preservation    |
//|   Law L0): the decision/reason/capital/session vocabulary is     |
//|   kept intact and extended, never deleted.                       |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_COMMON_MQH__
#define __HYPEROMEGA_COMMON_MQH__

//=== Operating mode ================================================
enum ENUM_OMEGA_MODE { OMEGA_MODE_AUTONOMOUS = 0 };

//=== Decisions (CONSEQUENCES of state, never direct signals) =======
enum ENUM_OMEGA_DECISION
  {
   OMEGA_DEC_OBSERVE     = 0,
   OMEGA_DEC_ENTER_LONG  = 1,
   OMEGA_DEC_ENTER_SHORT = 2,
   OMEGA_DEC_HOLD        = 3,
   OMEGA_DEC_ADD         = 4,
   OMEGA_DEC_REDUCE      = 5,
   OMEGA_DEC_REVERSE     = 6,
   OMEGA_DEC_EXIT        = 7,
   OMEGA_DEC_TRANSFER    = 8
  };

//=== Reason codes (explainability) =================================
enum ENUM_OMEGA_REASON
  {
   REASON_NONE                     = 0,
   REASON_LIFE_HEALTHY             = 1,
   REASON_LIFE_WEAKENING           = 2,
   REASON_LIFE_DECAY               = 3,
   REASON_LIFE_DEAD                = 4,
   REASON_STORY_STABLE             = 10,
   REASON_STORY_CONTRADICTION      = 11,
   REASON_STORY_STRENGTHENING      = 12,
   REASON_STORY_WEAKENING          = 13,
   REASON_CONFIDENCE_HIGH          = 20,
   REASON_CONFIDENCE_LOW           = 21,
   REASON_CONFIDENCE_DECAY         = 22,
   REASON_OWNERSHIP_TRANSFER       = 30,
   REASON_OWNERSHIP_PERSISTING     = 31,
   REASON_OWNERSHIP_LEAKING        = 32,
   REASON_CHAIN_HEALTHY            = 40,
   REASON_CHAIN_WEAKENING          = 41,
   REASON_CHAIN_DECAY              = 42,
   REASON_COMPRESSION_TIGHT        = 50,
   REASON_COMPRESSION_WIDE         = 51,
   REASON_COMPRESSION_TIGHTENING   = 52,
   REASON_FORCE_PERSISTING         = 60,
   REASON_FORCE_LEAKING            = 61,
   REASON_REGIME_HEALTHY           = 70,
   REASON_REGIME_SHIFT             = 71,
   REASON_RISK_LIMIT               = 80,
   REASON_DAILY_LIMIT              = 81,
   REASON_WEEKLY_LIMIT             = 82,
   REASON_HARD_LIMIT               = 83,
   REASON_DRAWDOWN_THROTTLE        = 84,
   REASON_EXPOSURE_LIMIT           = 85,
   REASON_NARRATIVE_ALIGN          = 90,
   REASON_NARRATIVE_DIVERGE        = 91,
   REASON_HEALTHY_CONTINUATION     = 100,
   REASON_TERMINAL_INDUCTION       = 101,
   REASON_FAILURE_SWING            = 102,
   REASON_RECURSION_BUDGET_FULL    = 110,
   REASON_RECURSION_BUDGET_LEFT    = 111,
   REASON_OPPORTUNITY_QUALIFIED    = 120,
   REASON_OPPORTUNITY_VETOED       = 121,
   REASON_HEARTBEAT                = 199,
   REASON_PHASE_NOT_BUILT          = 200
  };

//=== Capital state machine =========================================
enum ENUM_OMEGA_CAPITAL_STATE
  {
   CAPITAL_HEALTHY    = 0,
   CAPITAL_WARNING    = 1,
   CAPITAL_RESTRICTED = 2,
   CAPITAL_SUSPENDED  = 3
  };

//=== Sessions (informational) ======================================
enum ENUM_OMEGA_SESSION
  {
   SESSION_OFF        = 0,
   SESSION_ASIAN      = 1,
   SESSION_LONDON     = 2,
   SESSION_NY         = 3,
   SESSION_OVERLAP_LN = 4
  };

//=== Timeframe ladder (the F60 curve set) ==========================
//   index: 0=M1 1=M3 2=M5(canonical) 3=M15 4=H1 5=H4 6=D1 7=W1 8=MN
#define TF_COUNT 9
#define TF_CANON 2

//=== Constants =====================================================
#define OMEGA_VERSION         "72.0-hyperomega"
#define OMEGA_TRINITY_NEUTRAL 50.0
#define NA_VAL                DBL_MAX

bool   IsNa(double v)            { return (v >= DBL_MAX * 0.5); }
double Nz(double v, double fb=0) { return IsNa(v) ? fb : v; }

//=== Math helpers ==================================================
class OmegaMath
  {
public:
   static double Clamp(double v,double lo,double hi){ return MathMax(lo,MathMin(hi,v)); }
   static double Lerp(double a,double b,double t){ return a+(b-a)*t; }
   static double SafeDiv(double n,double d,double fb=0.0){ return (MathAbs(d)<1e-10)?fb:(n/d); }
   static double Pct(double v,double tot,double fb=0.0){ return SafeDiv(v,tot,fb)*100.0; }
   static int    Sign(double v){ return v>0?1:v<0?-1:0; }
  };

//=== Timeframe helpers =============================================
ENUM_TIMEFRAMES OmegaTfEnum(int i)
  {
   switch(i){ case 0:return PERIOD_M1; case 1:return PERIOD_M3; case 2:return PERIOD_M5; case 3:return PERIOD_M15;
              case 4:return PERIOD_H1; case 5:return PERIOD_H4; case 6:return PERIOD_D1; case 7:return PERIOD_W1; case 8:return PERIOD_MN1; }
   return PERIOD_M5;
  }
string OmegaTfName(int i)
  {
   switch(i){ case 0:return"M1"; case 1:return"M3"; case 2:return"M5"; case 3:return"M15"; case 4:return"H1";
              case 5:return"H4"; case 6:return"D1"; case 7:return"W1"; case 8:return"MN"; }
   return "?";
  }

//=== String helpers ================================================
class OmegaStr
  {
public:
   static string ModeToString(ENUM_OMEGA_MODE m){ return "AUTONOMOUS"; }
   static string DecisionToString(ENUM_OMEGA_DECISION d)
     {
      switch(d){ case OMEGA_DEC_OBSERVE:return"OBSERVE"; case OMEGA_DEC_ENTER_LONG:return"ENTER_LONG";
                 case OMEGA_DEC_ENTER_SHORT:return"ENTER_SHORT"; case OMEGA_DEC_HOLD:return"HOLD";
                 case OMEGA_DEC_ADD:return"ADD"; case OMEGA_DEC_REDUCE:return"REDUCE"; case OMEGA_DEC_REVERSE:return"REVERSE";
                 case OMEGA_DEC_EXIT:return"EXIT"; case OMEGA_DEC_TRANSFER:return"TRANSFER"; }
      return "UNKNOWN";
     }
   static string CapitalStateToString(ENUM_OMEGA_CAPITAL_STATE s)
     {
      switch(s){ case CAPITAL_HEALTHY:return"HEALTHY"; case CAPITAL_WARNING:return"WARNING";
                 case CAPITAL_RESTRICTED:return"RESTRICTED"; case CAPITAL_SUSPENDED:return"SUSPENDED"; }
      return "UNKNOWN";
     }
   static string SessionToString(ENUM_OMEGA_SESSION s)
     {
      switch(s){ case SESSION_ASIAN:return"ASIAN"; case SESSION_LONDON:return"LONDON"; case SESSION_NY:return"NY";
                 case SESSION_OVERLAP_LN:return"LN_OVERLAP"; case SESSION_OFF:return"OFF"; }
      return "UNKNOWN";
     }
   static bool Has(string s,string sub){ return StringFind(s,sub)>=0; }
  };

#endif // __HYPEROMEGA_COMMON_MQH__

// ====================== Include/Logger.mqh ======================
//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Explainability backbone. Every module logs through this.       |
//|   Sinks: Print() (always) + optional CSV decision/exec/except.   |
//|   Preserved from the F72 Omega lineage.                          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_LOGGER_MQH__
#define __HYPEROMEGA_LOGGER_MQH__


#define OMEGA_LOG_DIR "HyperOmega/logs"

enum ENUM_OMEGA_LOG_LEVEL
  {
   LOG_DEBUG     = 0,
   LOG_INFO      = 1,
   LOG_DECISION  = 2,
   LOG_EXECUTION = 3,
   LOG_WARNING   = 4,
   LOG_EXCEPTION = 5
  };

class OmegaLogger
  {
private:
   static int                  s_decisionFile, s_executionFile, s_exceptionFile;
   static bool                 s_initialized, s_csv;
   static ENUM_OMEGA_LOG_LEVEL s_minLevel;

   static string LevelString(ENUM_OMEGA_LOG_LEVEL l)
     {
      switch(l){ case LOG_DEBUG:return"DEBUG"; case LOG_INFO:return"INFO"; case LOG_DECISION:return"DECIDE";
                 case LOG_EXECUTION:return"EXEC"; case LOG_WARNING:return"WARN"; case LOG_EXCEPTION:return"EXCEPT"; }
      return "?";
     }
   static int OpenCsv(const string filename,const string header)
     {
      int h=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(h==INVALID_HANDLE){ Print("[HO-LOGGER] FileOpen failed ",filename," err=",GetLastError()); return INVALID_HANDLE; }
      FileSeek(h,0,SEEK_END);
      if(FileSize(h)==0) FileWriteString(h,header+"\n");
      return h;
     }
public:
   static bool Init(ENUM_OMEGA_LOG_LEVEL minLevel=LOG_INFO,bool csv=false)
     {
      s_minLevel=minLevel; s_csv=csv;
      if(s_csv)
        {
         s_decisionFile =OpenCsv(OMEGA_LOG_DIR+"/decision_log.csv","timestamp,symbol,decision,reason,life,stability,confidence,detail");
         s_executionFile=OpenCsv(OMEGA_LOG_DIR+"/execution_log.csv","timestamp,symbol,action,ticket,price,lots,reason,detail");
         s_exceptionFile=OpenCsv(OMEGA_LOG_DIR+"/exception_log.csv","timestamp,module,code,message");
        }
      s_initialized=true;
      LogInfo("LOGGER",StringFormat("Initialized · level=%s · csv=%s",LevelString(minLevel),csv?"on":"off"));
      return true;
     }
   static void Shutdown()
     {
      if(s_decisionFile!=INVALID_HANDLE){ FileClose(s_decisionFile); s_decisionFile=INVALID_HANDLE; }
      if(s_executionFile!=INVALID_HANDLE){ FileClose(s_executionFile); s_executionFile=INVALID_HANDLE; }
      if(s_exceptionFile!=INVALID_HANDLE){ FileClose(s_exceptionFile); s_exceptionFile=INVALID_HANDLE; }
      s_initialized=false;
     }
   static void Flush()
     {
      if(s_decisionFile!=INVALID_HANDLE) FileFlush(s_decisionFile);
      if(s_executionFile!=INVALID_HANDLE) FileFlush(s_executionFile);
      if(s_exceptionFile!=INVALID_HANDLE) FileFlush(s_exceptionFile);
     }
   static void SetMinLevel(ENUM_OMEGA_LOG_LEVEL l){ s_minLevel=l; }
   static ENUM_OMEGA_LOG_LEVEL MinLevel(){ return s_minLevel; }

   static void Log(ENUM_OMEGA_LOG_LEVEL level,string module,string msg)
     {
      if((int)level<(int)s_minLevel) return;
      string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      Print(StringFormat("[%s][%s][%s] %s",ts,LevelString(level),module,msg));
     }
   static void LogDebug(string m,string s){ Log(LOG_DEBUG,m,s); }
   static void LogInfo(string m,string s){ Log(LOG_INFO,m,s); }
   static void LogWarning(string m,string s){ Log(LOG_WARNING,m,s); }
   //--- short aliases
   static void Info(string m,string s){ Log(LOG_INFO,m,s); }
   static void Warn(string m,string s){ Log(LOG_WARNING,m,s); }
   static void Decide(string m,string s){ Log(LOG_DECISION,m,s); }
   static void Exec(string m,string s){ Log(LOG_EXECUTION,m,s); }
   static void LogException(string module,int code,string msg)
     {
      Log(LOG_EXCEPTION,module,StringFormat("[%d] %s",code,msg));
      if(s_exceptionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS); FileWriteString(s_exceptionFile,StringFormat("%s,%s,%d,%s\n",ts,module,code,msg)); }
     }
   static void LogDecision(string symbol,ENUM_OMEGA_DECISION decision,ENUM_OMEGA_REASON reason,
                           double life,double stability,double confidence,string detail)
     {
      Log(LOG_DECISION,"DECIDE",StringFormat("%s · %s · r=%d · L=%.1f S=%.1f C=%.1f · %s",
          symbol,OmegaStr::DecisionToString(decision),(int)reason,life,stability,confidence,detail));
      if(s_decisionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
         FileWriteString(s_decisionFile,StringFormat("%s,%s,%s,%d,%.2f,%.2f,%.2f,%s\n",ts,symbol,OmegaStr::DecisionToString(decision),(int)reason,life,stability,confidence,detail)); }
     }
   static void LogExecution(string symbol,string action,ulong ticket,double price,double lots,ENUM_OMEGA_REASON reason,string detail)
     {
      Log(LOG_EXECUTION,"EXEC",StringFormat("%s · %s · #%I64u · px=%.5f · vol=%.2f · %s",symbol,action,ticket,price,lots,detail));
      if(s_executionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
         FileWriteString(s_executionFile,StringFormat("%s,%s,%s,%I64u,%.5f,%.2f,%d,%s\n",ts,symbol,action,ticket,price,lots,(int)reason,detail)); }
     }
  };
int                  OmegaLogger::s_decisionFile  = INVALID_HANDLE;
int                  OmegaLogger::s_executionFile = INVALID_HANDLE;
int                  OmegaLogger::s_exceptionFile = INVALID_HANDLE;
bool                 OmegaLogger::s_initialized   = false;
bool                 OmegaLogger::s_csv           = false;
ENUM_OMEGA_LOG_LEVEL OmegaLogger::s_minLevel      = LOG_INFO;

#endif // __HYPEROMEGA_LOGGER_MQH__

// ====================== Include/F60State.mqh ======================
//+------------------------------------------------------------------+
//|                                                     F60State.mqh |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The aggregated F60 substrate snapshot — the single perception  |
//|   record every observer (ERF/FRZ/RIE/MCE/NE/TQE/TE/IE2/WR-DWR)   |
//|   and HyperIntelligence reads. Information flows UPWARD: this is  |
//|   filled by the SubstrateEngine; observers only READ it (L2).    |
//|                                                                  |
//|   TF index: 0=M1 1=M3 2=M5(canonical) 3=M15 4=H1 5=H4 6=D1 7=W1  |
//|             8=MN                                                  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60STATE_MQH__
#define __HYPEROMEGA_F60STATE_MQH__


struct F60State
  {
   //=== per-TF curve readouts (from the SEEngine ladder) ===========
   int    tfDir[9], tfPhase[9], tfBos[9], tfCh[9], tfCompBars[9];
   double tfWp[9], tfComp[9], tfMf[9], tfFrz[9];
   double tfInv[9], tfTgt[9], tfFt[9], tfFb[9], tfCycH[9], tfCycL[9], tfP4h[9], tfP4l[9];
   double tfCompPersist[9];
   bool   tfELong[9], tfEShort[9], tfAtExt[9];
   string tfPhaseStr[9];

   //=== canonical physics (M5 == f_phys) ===========================
   double close, high, low, open, atr;
   double vel, acc, conv, convSmooth, eff, disp, velPrev2;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;

   //=== Invisible Network ==========================================
   int    netBias, pdir, eligibleNodes, nodeCount;
   double pressure, bullAuth, bearAuth, nodeAbove, nodeBelow;

   //=== fractal stack + structure ==================================
   int    fractalStackDir, structBias;
   double fractalStackScore;

   //=== curve-tree lineage / ownership =============================
   int    ownerTf, ownerDir;          // ladder-rung owner (TF index + its dir)
   int    treeOwnerDir, treeDepth, treeRecursionBudget, treeTransferDir;
   double treeOwnerEnergy, treeOwnerStability, chainVitality;

   //=== FCE (force/curve energy) ===================================
   double fce_residual, fce_convexity, fce_maturity, fce_budget, fce_travel, fce_progress;
   double forceScore; int forceState;
   double compressionPersistChart, compressionTightenChart;

   //=== Time Intelligence ==========================================
   int    timeDir; double timeAlign, timeConflict;

   //=== participants ===============================================
   double participantStability, flipQuality, participantInterference;
   double flipTrueInductionPx; int flipTrueInductionDir; bool manipulationFlag;

   //=== energy framework (EDE / RE / EAE) ==========================
   int    ede_state, resCode;
   double ede_dissProg, ede_expEnergy, re_residualScore, eae_score, eae_price;
   //=== physics observation layer ==================================
   double obs_Exp, obs_Decay, obs_Curv, obs_Abs, obs_Liq, convexityScore;

   //=== liquidation engine =========================================
   bool   liqg_active, liqSweepBull, liqSweepBear;
   double liqg_target, liqg_distPct, liqHeat;

   //=== belief engine ==============================================
   double expBelief, convBelief, creatBelief, absBelief, retrBelief, dmdBelief;
   double convexityMaturity, waveProgress, waveModelFit;

   //=== spawn / wave geometry ======================================
   int    direction, entryCycle, waveDepth, recursiveDepth; bool recursiveComplete, isRecursive;
   double flipTop, flipBot, p4High, p4Low, cycleHigh, cycleLow;

   //=== attack sequence ============================================
   double atkEntry, atkStop, atkT1, atkT2, atkT3, waveObj, waveOrigin;
   bool   atkEntered, atkStopHit, atkT1Hit, atkT2Hit, atkT3Hit;

   //=== master-vote raw inputs (read by MCE / HyperIntelligence) ====
   int    waveDir, stackDir;
  };

#endif // __HYPEROMEGA_F60STATE_MQH__

// ====================== Include/F60/Physics.mqh ======================
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

// ====================== Include/F60/Structure.mqh ======================
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

// ====================== Include/F60/CurveFramework.mqh ======================
//+------------------------------------------------------------------+
//|                                          F60/CurveFramework.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Layer 5/7 — the curve-force framework that stands ON the       |
//|   structure authority (SEEngine), never duplicating it (L2):     |
//|     · CompressionTracker — rolling compression + tighten signal  |
//|     · ConvexityHelper     — convexity score / shift / maturity   |
//|     · ForceHelper          — Compression Persistence composite    |
//|       (PERSISTING / NEUTRAL / LEAKING)                           |
//|     · CurveForce          — the FCE base: aggregates the above   |
//|       into the force/curve-energy reading the observers consume. |
//|                                                                  |
//|   Preserved from the F72 Omega Curve/* lineage (Compression,     |
//|   Convexity, Force), re-pointed to read the authentic SEEngine.  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__
#define __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__


//==================================================================
//= Compression intelligence — can price BREATHE, or is it SQUEEZED?
//==================================================================
class CompressionTracker
  {
private:
   double m_history[]; int m_head, m_count, m_capacity;
public:
            CompressionTracker(){ m_capacity=16; ArrayResize(m_history,m_capacity); Reset(); }
   void Reset(){ m_head=0; m_count=0; ArrayInitialize(m_history,0.0); }
   void Push(double sample){ m_history[m_head]=sample; m_head=(m_head+1)%m_capacity; if(m_count<m_capacity) m_count++; }
   void Sample(double v){ Push(v); }
   //--- Δcompression over last `lookback` samples. + = TIGHTENING, - = BROADENING
   double Tightening(int lookback=5) const
     {
      if(m_count<2) return 0.0;
      int span=MathMin(lookback,m_count-1);
      int latest=(m_head-1+m_capacity)%m_capacity;
      int earlier=(m_head-1-span+m_capacity)%m_capacity;
      return m_history[latest]-m_history[earlier];
     }
   double Latest() const { if(m_count==0) return 0.0; int latest=(m_head-1+m_capacity)%m_capacity; return m_history[latest]; }
   string Tier() const
     {
      double v=Latest();
      if(v>=75.0) return "FAILURE_SWING";
      if(v>=50.0) return "COMPRESSED";
      if(v>=25.0) return "MEDIUM";
      return "WIDE";
     }
   int    Count() const { return m_count; }
  };

//==================================================================
//= Convexity helper — energy cannot travel infinitely straight
//==================================================================
class ConvexityHelper
  {
public:
   static double Score(SEEngine &se)    { return OmegaMath::Clamp(se.o_cm, 0.0, 100.0); }     // == convScore (no recompute)
   static int    ShiftSign(SEEngine &se){ if(se.BullCS()) return 1; if(se.BearCS()) return -1; return 0; }
   static double Maturity(SEEngine &se) { return OmegaMath::Clamp(se.o_wp, 0.0, 100.0); }
  };

//==================================================================
//= Force — Compression Persistence (can the COUNTER side build?)
//==================================================================
enum ENUM_OMEGA_FORCE_STATE { FORCE_LEAKING=0, FORCE_NEUTRAL=1, FORCE_PERSISTING=2 };

class ForceHelper
  {
public:
   static double Score(double compNow,double compTighten,double residualEnergy=0.0,int recursionDepth=0)
     {
      double s = compNow*0.50 + residualEnergy*0.20 - (double)recursionDepth*12.0
               + MathMax(0.0,compTighten)*0.8 + 8.0;
      return OmegaMath::Clamp(s,0.0,100.0);
     }
   static ENUM_OMEGA_FORCE_STATE State(double score){ if(score>=60.0) return FORCE_PERSISTING; if(score<=35.0) return FORCE_LEAKING; return FORCE_NEUTRAL; }
   static string StateString(ENUM_OMEGA_FORCE_STATE s){ switch(s){ case FORCE_PERSISTING:return"PERSISTING"; case FORCE_LEAKING:return"LEAKING"; case FORCE_NEUTRAL:return"NEUTRAL"; } return"UNKNOWN"; }
   static string TightenTrend(double t){ if(t>3.0) return"TIGHTENING"; if(t<-3.0) return"BROADENING"; return"STABLE"; }
  };

//==================================================================
//= CurveForce — the FCE base. One per timeframe curve. Aggregates
//= compression persistence + convexity into the force/curve-energy
//= reading. residualEnergy + recursionDepth are fed in by the deep
//= cognition layer (Part 8) — the L4 enrichment hook.
//==================================================================
class CurveForce
  {
private:
   CompressionTracker m_comp;
public:
   double                 convexityScore, convexityMaturity; int convShift;
   double                 compressionNow, compressionTighten;
   double                 forceScore;  ENUM_OMEGA_FORCE_STATE forceState;
   double                 curveEnergy;     // preliminary curve-energy estimate (residual proxy until Part 8)
   string                 compTier, tightenTrend, forceStr;

   void Reset()
     {
      m_comp.Reset();
      convexityScore=convexityMaturity=0; convShift=0;
      compressionNow=compressionTighten=0; forceScore=50; forceState=FORCE_NEUTRAL;
      curveEnergy=0; compTier="WIDE"; tightenTrend="STABLE"; forceStr="NEUTRAL";
     }
   void Update(SEEngine &se,double residualEnergy=0.0,int recursionDepth=0)
     {
      m_comp.Sample(se.o_compIdx);
      compressionNow     = m_comp.Latest();
      compressionTighten = m_comp.Tightening(5);
      convexityScore     = ConvexityHelper::Score(se);
      convexityMaturity  = ConvexityHelper::Maturity(se);
      convShift          = ConvexityHelper::ShiftSign(se);
      forceScore         = ForceHelper::Score(compressionNow,compressionTighten,residualEnergy,recursionDepth);
      forceState         = ForceHelper::State(forceScore);
      curveEnergy        = OmegaMath::Clamp(se.o_mf*0.6 + se.o_frzS*0.4 - convexityMaturity*0.2, 0.0, 100.0);
      compTier           = m_comp.Tier();
      tightenTrend       = ForceHelper::TightenTrend(compressionTighten);
      forceStr           = ForceHelper::StateString(forceState);
     }
  };

#endif // __HYPEROMEGA_F60_CURVEFRAMEWORK_MQH__

// ====================== Include/F60/Network.mqh ======================
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

// ====================== Include/F60/CurveTreeF60.mqh ======================
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

// ====================== Include/F60/FractalTime.mqh ======================
//+------------------------------------------------------------------+
//|                                            F60/FractalTime.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   F60 fractal stack + Time Intelligence Engine.                  |
//|     FractalStack     : alignment across the 9-TF curve ladder    |
//|       (M1..MN) — directional consensus + score. The spatial      |
//|       "how aligned is the whole fractal" reading MCE consumes.   |
//|     TimeIntelligence : the 5-cycle stack — bias of the canonical |
//|       close vs each higher cycle's OPEN (H1/H4/D/W/MN). The      |
//|       temporal consensus MCE / Senseei consume.                  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_FRACTALTIME_MQH__
#define __HYPEROMEGA_F60_FRACTALTIME_MQH__


//==================================================================
//= FractalStack — directional alignment across the TF ladder
//==================================================================
class FractalStack
  {
public:
   int    stackBull, stackBear, dir;
   double score;                 // 0..100 (dominant side / count)
   int    rungDir[9];            // per-rung resolved direction (curve map)

   void Reset(){ stackBull=0; stackBear=0; dir=0; score=0; for(int i=0;i<9;i++) rungDir[i]=0; }

   //--- dirs[] = origin-resolved direction per ladder rung (length=count)
   void Compute(const int &dirs[], int count)
     {
      stackBull=0; stackBear=0;
      int n=MathMin(count,9);
      for(int i=0;i<n;i++)
        {
         rungDir[i]=dirs[i];
         if(dirs[i]==1) stackBull++; else if(dirs[i]==-1) stackBear++;
        }
      dir   = stackBull>stackBear?1:stackBear>stackBull?-1:0;
      score = (n>0) ? (double)MathMax(stackBull,stackBear)/(double)n*100.0 : 0.0;
     }
   //--- alignment of a given direction with the stack (0..100)
   double AlignWith(int d) const
     {
      int total=stackBull+stackBear; if(total<=0) return 50.0;
      int forV=(d==1)?stackBull:(d==-1)?stackBear:0;
      return (double)forV/(double)total*100.0;
     }
  };

//==================================================================
//= TimeIntelligence — the 5-cycle bias stack (TIE)
//==================================================================
class TimeIntelligence
  {
public:
   int    timeDir;
   double timeAlign, timeConflict;
   int    cycleBias[5];          // MN,W,D,H4,H1 bias vs canonical close

   void Reset(){ timeDir=0; timeAlign=50.0; timeConflict=50.0; for(int i=0;i<5;i++) cycleBias[i]=0; }

   void Update(string sym,double close)
     {
      double mnO=iOpen(sym,PERIOD_MN1,0), wO=iOpen(sym,PERIOD_W1,0), dO=iOpen(sym,PERIOD_D1,0);
      double h4O=iOpen(sym,PERIOD_H4,0),  h1O=iOpen(sym,PERIOD_H1,0);
      cycleBias[0]=(close>mnO?1:close<mnO?-1:0);
      cycleBias[1]=(close>wO ?1:close<wO ?-1:0);
      cycleBias[2]=(close>dO ?1:close<dO ?-1:0);
      cycleBias[3]=(close>h4O?1:close<h4O?-1:0);
      cycleBias[4]=(close>h1O?1:close<h1O?-1:0);
      int tBull=0,tBear=0;
      for(int i=0;i<5;i++){ if(cycleBias[i]==1) tBull++; else if(cycleBias[i]==-1) tBear++; }
      timeDir=tBull>tBear?1:tBear>tBull?-1:0;
      timeAlign=(tBull+tBear)>0?(double)MathMax(tBull,tBear)/(double)(tBull+tBear)*100.0:50.0;
      timeConflict=100.0-timeAlign;
     }
   double AlignWith(int d) const
     {
      int tBull=0,tBear=0;
      for(int i=0;i<5;i++){ if(cycleBias[i]==1) tBull++; else if(cycleBias[i]==-1) tBear++; }
      int total=tBull+tBear; if(total<=0) return 50.0;
      int forV=(d==1)?tBull:(d==-1)?tBear:0;
      return (double)forV/(double)total*100.0;
     }
  };

#endif // __HYPEROMEGA_F60_FRACTALTIME_MQH__

// ====================== Include/F60/Participants.mqh ======================
//+------------------------------------------------------------------+
//|                                           F60/Participants.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Layer 13/14 — participant footprints.                          |
//|     ParticipantZone   : atomic zone state machine (touch/react/  |
//|                         violate/expire) + defence score.         |
//|     ParticipantEngine : Fibonacci 0.618/0.70/0.786 zones on the  |
//|                         owner leg; stability, reaction rate,      |
//|                         deepest-active, manipulation flag.        |
//|     FlipEngine         : FU-candle flip zones + "true induction". |
//|     OmegaParticipants  : orchestrator -> participantStability +  |
//|                         flipQuality (consumed by RIE / TQE).      |
//|                                                                  |
//|   Preserved from the F72 Omega Participant/* lineage, re-pointed |
//|   to drive from the curve-tree owner + canonical bar OHLC.       |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_PARTICIPANTS_MQH__
#define __HYPEROMEGA_F60_PARTICIPANTS_MQH__


//=== zone taxonomy / state =========================================
enum ENUM_ZONE_TYPE { ZONE_TYPE_NONE=0, ZONE_TYPE_FIB_618=1, ZONE_TYPE_FIB_70=2, ZONE_TYPE_FIB_786=3, ZONE_TYPE_FU_FLIP=4, ZONE_TYPE_TRUE_IND=5 };
enum ENUM_ZONE_STATE { ZONE_UNTESTED=0, ZONE_TOUCHED=1, ZONE_REACTED=2, ZONE_VIOLATED=3, ZONE_EXPIRED=4 };

//=== one zone ======================================================
struct ParticipantZone
  {
   ENUM_ZONE_TYPE type; int direction; double price, tolerance;
   ENUM_ZONE_STATE state; int touchCount, reactionCount, violationCount;
   datetime born, lastTouch, expired; int ageBars; bool active;
            ParticipantZone(){ Reset(); }
   void Reset()
     {
      type=ZONE_TYPE_NONE; direction=0; price=0; tolerance=0; state=ZONE_UNTESTED;
      touchCount=reactionCount=violationCount=0; born=lastTouch=expired=0; ageBars=0; active=false;
     }
   void Init(ENUM_ZONE_TYPE t,int dir,double px,double tol){ Reset(); type=t; direction=dir; price=px; tolerance=tol; born=TimeCurrent(); active=true; }
   double Lower() const { return price-tolerance; }
   double Upper() const { return price+tolerance; }
   bool BarTouches(double bh,double bl) const { return bh>=Lower() && bl<=Upper(); }
   bool CloseViolates(double bc) const { if(direction==1) return bc<Lower(); if(direction==-1) return bc>Upper(); return false; }
   bool Update(double bh,double bl,double bc,double atr)
     {
      if(!active) return false;
      ageBars++; bool advanced=false; bool touched=BarTouches(bh,bl); double reactDist=atr*0.5;
      if(CloseViolates(bc)){ violationCount++; state=ZONE_VIOLATED; active=false; expired=TimeCurrent(); return true; }
      if(touched){ touchCount++; lastTouch=TimeCurrent(); if(state==ZONE_UNTESTED){ state=ZONE_TOUCHED; advanced=true; } }
      if(state==ZONE_TOUCHED && !touched)
        {
         double awayDist=(direction==1)?(bl-Upper()):(Lower()-bh);
         if(awayDist>=reactDist){ reactionCount++; state=ZONE_REACTED; advanced=true; }
        }
      return advanced;
     }
   double DefenceScore() const { double s=50.0; s+=reactionCount*12.0; s+=touchCount*4.0; s-=violationCount*30.0; return OmegaMath::Clamp(s,0.0,100.0); }
   void ExpireIfOld(int maxAgeBars){ if(active && ageBars>maxAgeBars){ state=ZONE_EXPIRED; active=false; expired=TimeCurrent(); } }
   string TypeString() const { switch(type){ case ZONE_TYPE_FIB_618:return"0.618"; case ZONE_TYPE_FIB_70:return"0.70"; case ZONE_TYPE_FIB_786:return"0.786"; case ZONE_TYPE_FU_FLIP:return"FLIP"; case ZONE_TYPE_TRUE_IND:return"TRUE_IND"; } return"?"; }
   string StateString() const { switch(state){ case ZONE_UNTESTED:return"UNTESTED"; case ZONE_TOUCHED:return"TOUCHED"; case ZONE_REACTED:return"REACTED"; case ZONE_VIOLATED:return"VIOLATED"; case ZONE_EXPIRED:return"EXPIRED"; } return"?"; }
  };

//=== Fibonacci participant zones ===================================
#define OMEGA_PART_ZONE_AGE_MAX 200
class ParticipantEngine
  {
private:
   ParticipantZone m_fib618,m_fib70,m_fib786;
   int    m_lastOwnerDir; double m_lastLegOrigin,m_lastLegExtreme; long m_legSpawns;
   double m_stability,m_reactionRate; ENUM_ZONE_TYPE m_deepestActive; bool m_manipulationFlag;
   void SpawnZones(int dir,double origin,double extreme,double atr)
     {
      double leg=MathAbs(extreme-origin); if(leg<atr*1.5) return;
      double px618=(dir==1)?extreme-leg*0.618:extreme+leg*0.618;
      double px70 =(dir==1)?extreme-leg*0.70 :extreme+leg*0.70;
      double px786=(dir==1)?extreme-leg*0.786:extreme+leg*0.786;
      double tol=atr*0.25;
      m_fib618.Init(ZONE_TYPE_FIB_618,dir,px618,tol);
      m_fib70 .Init(ZONE_TYPE_FIB_70 ,dir,px70 ,tol);
      m_fib786.Init(ZONE_TYPE_FIB_786,dir,px786,tol);
      m_legSpawns++;
     }
   void Recompute()
     {
      int active=0,touches=0,reacts=0; double scoreSum=0.0;
      touches+=m_fib618.touchCount+m_fib70.touchCount+m_fib786.touchCount;
      reacts +=m_fib618.reactionCount+m_fib70.reactionCount+m_fib786.reactionCount;
      if(m_fib618.active){ active++; scoreSum+=m_fib618.DefenceScore(); }
      if(m_fib70 .active){ active++; scoreSum+=m_fib70 .DefenceScore(); }
      if(m_fib786.active){ active++; scoreSum+=m_fib786.DefenceScore(); }
      m_stability=(active>0)?(scoreSum/active):OMEGA_TRINITY_NEUTRAL;
      m_reactionRate=(touches>0)?((double)reacts/touches):0.0;
      m_deepestActive=ZONE_TYPE_NONE;
      if(m_fib618.active) m_deepestActive=ZONE_TYPE_FIB_618;
      if(m_fib70 .active) m_deepestActive=ZONE_TYPE_FIB_70;
      if(m_fib786.active) m_deepestActive=ZONE_TYPE_FIB_786;
      m_manipulationFlag=(m_fib70.state==ZONE_VIOLATED)&&(m_fib786.state==ZONE_REACTED);
     }
public:
            ParticipantEngine(){ Reset(); }
   void Reset()
     {
      m_fib618.Reset(); m_fib70.Reset(); m_fib786.Reset();
      m_lastOwnerDir=0; m_lastLegOrigin=0; m_lastLegExtreme=0; m_legSpawns=0;
      m_stability=OMEGA_TRINITY_NEUTRAL; m_reactionRate=0; m_deepestActive=ZONE_TYPE_NONE; m_manipulationFlag=false;
     }
   void Init(string sym){ Reset(); }
   //--- per canonical closed bar; owner leg from the curve tree
   void Update(int ownerDir,double ownerOrigin,double ownerExtreme,double atr,double bar1H,double bar1L,double bar1C)
     {
      if(atr<=0) return;
      bool dirChanged=(ownerDir!=m_lastOwnerDir);
      bool legShifted=(MathAbs(ownerExtreme-m_lastLegExtreme)>atr*2.0)||(MathAbs(ownerOrigin-m_lastLegOrigin)>atr*2.0);
      if(ownerDir!=0 && (dirChanged || (legShifted && m_legSpawns==0)))
        { SpawnZones(ownerDir,ownerOrigin,ownerExtreme,atr); m_lastOwnerDir=ownerDir; m_lastLegOrigin=ownerOrigin; m_lastLegExtreme=ownerExtreme; }
      m_fib618.Update(bar1H,bar1L,bar1C,atr); m_fib70.Update(bar1H,bar1L,bar1C,atr); m_fib786.Update(bar1H,bar1L,bar1C,atr);
      m_fib618.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX); m_fib70.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX); m_fib786.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);
      Recompute();
     }
   double Stability()    const { return m_stability; }
   double ReactionRate() const { return m_reactionRate; }
   int    ActiveCount()  const { int n=0; if(m_fib618.active)n++; if(m_fib70.active)n++; if(m_fib786.active)n++; return n; }
   ENUM_ZONE_TYPE DeepestActive() const { return m_deepestActive; }
   bool   ManipulationFlag() const { return m_manipulationFlag; }
   double PriceFor(ENUM_ZONE_TYPE t) const
     {
      switch(t){ case ZONE_TYPE_FIB_618:return m_fib618.active?m_fib618.price:0.0; case ZONE_TYPE_FIB_70:return m_fib70.active?m_fib70.price:0.0; case ZONE_TYPE_FIB_786:return m_fib786.active?m_fib786.price:0.0; }
      return 0.0;
     }
   string DeepestString() const { switch(m_deepestActive){ case ZONE_TYPE_FIB_618:return"0.618"; case ZONE_TYPE_FIB_70:return"0.70"; case ZONE_TYPE_FIB_786:return"0.786"; } return"none"; }
  };

//=== FU-candle flip zones ==========================================
#define OMEGA_FLIP_CAP        24
#define OMEGA_FLIP_AGE_MAX   300
#define OMEGA_FLIP_WICK_FRAC 0.30
class FlipEngine
  {
private:
   ParticipantZone m_zones[OMEGA_FLIP_CAP]; int m_count; long m_detectedTotal;
   double m_prevHigh,m_prevLow; double m_quality; int m_trueInductionIdx; double m_truePx; int m_truePxDir;
   int FindFreeSlot()
     {
      for(int i=0;i<m_count;i++) if(!m_zones[i].active && m_zones[i].state==ZONE_EXPIRED) return i;
      if(m_count<OMEGA_FLIP_CAP) return m_count++;
      int evict=0; datetime oldest=m_zones[0].born;
      for(int i=1;i<m_count;i++) if(m_zones[i].born<oldest){ oldest=m_zones[i].born; evict=i; }
      return evict;
     }
   void MaybeRecord(double tip,int dir,double atr,double bodyHi,double bodyLo)
     {
      int slot=FindFreeSlot(); if(slot<0) return;
      double midPx=(dir==-1)?(bodyHi+(tip-bodyHi)*0.5):(tip+(bodyLo-tip)*0.5);
      double tol=atr*0.30;
      m_zones[slot].Init(ZONE_TYPE_FU_FLIP,dir,midPx,tol); m_detectedTotal++;
     }
public:
            FlipEngine(){ Reset(); }
   void Reset()
     {
      for(int i=0;i<OMEGA_FLIP_CAP;i++) m_zones[i].Reset();
      m_count=0; m_detectedTotal=0; m_prevHigh=m_prevLow=0; m_quality=OMEGA_TRINITY_NEUTRAL;
      m_trueInductionIdx=-1; m_truePx=0; m_truePxDir=0;
     }
   void Init(string sym){ Reset(); }
   //--- per canonical closed bar (chart-TF OHLC) + owner direction
   void Update(double atr,double h1,double l1,double o1,double c1,int ownerDir)
     {
      if(atr<=0) return;
      double rng=MathMax(h1-l1,1e-10);
      double upperWick=h1-MathMax(o1,c1), lowerWick=MathMin(o1,c1)-l1;
      bool localTop=(m_prevHigh>0 && h1>=m_prevHigh), localBot=(m_prevLow>0 && l1<=m_prevLow);
      bool bearFu=(upperWick/rng)>=OMEGA_FLIP_WICK_FRAC && (localTop||c1<o1);
      bool bullFu=(lowerWick/rng)>=OMEGA_FLIP_WICK_FRAC && (localBot||c1>o1);
      if(bearFu) MaybeRecord(h1,-1,atr,MathMax(o1,c1),MathMin(o1,c1));
      if(bullFu) MaybeRecord(l1,+1,atr,MathMax(o1,c1),MathMin(o1,c1));
      m_prevHigh=h1; m_prevLow=l1;
      double scoreSum=0; int activeN=0;
      for(int i=0;i<m_count;i++)
        {
         if(m_zones[i].active){ m_zones[i].Update(h1,l1,c1,atr); m_zones[i].ExpireIfOld(OMEGA_FLIP_AGE_MAX); }
         if(m_zones[i].active){ activeN++; scoreSum+=m_zones[i].DefenceScore(); }
        }
      m_quality=(activeN>0)?(scoreSum/activeN):OMEGA_TRINITY_NEUTRAL;
      m_trueInductionIdx=-1;
      if(ownerDir!=0)
        {
         double bestScore=-1.0,bestPx=0.0;
         for(int i=0;i<m_count;i++)
           {
            if(!m_zones[i].active) continue;
            if(m_zones[i].direction!=ownerDir) continue;
            double s=m_zones[i].DefenceScore();
            if(s>bestScore || (MathAbs(s-bestScore)<1e-6 && ((ownerDir==1 && m_zones[i].price<bestPx)||(ownerDir==-1 && m_zones[i].price>bestPx))))
              { bestScore=s; bestPx=m_zones[i].price; m_trueInductionIdx=i; }
           }
         if(m_trueInductionIdx>=0){ m_truePx=m_zones[m_trueInductionIdx].price; m_truePxDir=ownerDir; }
        }
     }
   double Quality() const { return m_quality; }
   int    Active() const { int n=0; for(int i=0;i<m_count;i++) if(m_zones[i].active) n++; return n; }
   long   DetectedTotal() const { return m_detectedTotal; }
   bool   HasTrueInduction() const { return m_trueInductionIdx>=0; }
   double TrueInductionPrice() const { return m_truePx; }
   int    TrueInductionDir() const { return m_truePxDir; }
  };

//=== orchestrator ==================================================
class OmegaParticipants
  {
public:
   ParticipantEngine fib; FlipEngine flip;
   double participantStability, flipQuality;
   void Init(string sym){ fib.Init(sym); flip.Init(sym); participantStability=OMEGA_TRINITY_NEUTRAL; flipQuality=OMEGA_TRINITY_NEUTRAL; }
   void Reset(){ fib.Reset(); flip.Reset(); participantStability=OMEGA_TRINITY_NEUTRAL; flipQuality=OMEGA_TRINITY_NEUTRAL; }
   //--- ownerDir/origin/extreme from the curve tree; OHLC = canonical bar
   void Update(int ownerDir,double ownerOrigin,double ownerExtreme,double atr,double h1,double l1,double o1,double c1)
     {
      fib.Update(ownerDir,ownerOrigin,ownerExtreme,atr,h1,l1,c1);
      flip.Update(atr,h1,l1,o1,c1,ownerDir);
      participantStability=fib.Stability();
      flipQuality=flip.Quality();
     }
   //--- participant interference 0..100 (manipulation + low reaction + violations)
   double Interference() const
     {
      double s=0.0;
      if(fib.ManipulationFlag()) s+=40.0;
      s+=(1.0-fib.ReactionRate())*30.0;
      s+=(100.0-fib.Stability())*0.30;
      return OmegaMath::Clamp(s,0.0,100.0);
     }
  };

#endif // __HYPEROMEGA_F60_PARTICIPANTS_MQH__

// ====================== Include/F60/Cognition.mqh ======================
//+------------------------------------------------------------------+
//|                                             F60/Cognition.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The deep F60 cognition — the authentic V60 derived stack:      |
//|     physics observation -> EDE/RE/EAE energy framework ->        |
//|     liquidity sweep + liqg liquidation engine -> geometry /      |
//|     similarity / convexity-maturity / wave-progress -> belief    |
//|     engine (6 beliefs) -> spawn / wave state machine -> attack   |
//|     sequence.                                                    |
//|                                                                  |
//|   CognitionEngine holds the persistent wave/belief/liqg state    |
//|   and Compute() fills the F60State energy/belief/spawn/attack    |
//|   fields. Preserved faithfully from the V60 source. Forward-var  |
//|   ordering (EAE/RE/liqg read prev spawn state, then spawn        |
//|   updates) is honoured.                                          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_COGNITION_MQH__
#define __HYPEROMEGA_F60_COGNITION_MQH__


//--- ideal-state similarity kernel (curve phase fingerprinting)
double IdealSim(double e,double d,double v,double c,double eI,double dI,double vI,double cI)
  {
   double diff=(e-eI)*(e-eI)+(d-dI)*(d-dI)+(v-vI)*(v-vI)+(c-cI)*(c-cI);
   return MathMax(0.0,100.0*(1.0-diff/4.0));
  }

class CognitionEngine
  {
private:
   string m_sym; long m_barIndex;
   //--- spawn / wave state
   int    m_direction, m_lastSpawnDir;
   double m_flipTop, m_flipBot, m_p4High, m_p4Low, m_cycleHigh, m_cycleLow;
   int    m_obBirthBar, m_contBar, m_entryCycle, m_waveDepth, m_waveGeneration;
   bool   m_isRecursive, m_recursiveComplete; int m_recursiveFiredBar;
   //--- belief
   double m_expBelief, m_convBelief, m_creatBelief, m_absBelief, m_retrBelief, m_dmdBelief;
   double m_convexityMaturity, m_waveProgress, m_waveModelFit;
   bool   m_preConvEvidence, m_inductionEvidence;
   //--- liqg
   bool   m_liqgActive, m_liqgIsRetr; int m_liqgDir; double m_liqgTarget, m_liqgInitDist;
   //--- attack latches
   bool   m_atkEntered, m_atkStop, m_atkT1, m_atkT2, m_atkT3; int m_atkDirPrev;
public:
   void Init(string sym)
     {
      m_sym=sym; m_barIndex=0;
      m_direction=m_lastSpawnDir=0;
      m_flipTop=m_flipBot=m_p4High=m_p4Low=m_cycleHigh=m_cycleLow=NA_VAL;
      m_obBirthBar=m_contBar=-1; m_entryCycle=m_waveDepth=m_waveGeneration=0;
      m_isRecursive=false; m_recursiveComplete=false; m_recursiveFiredBar=-100000;
      m_expBelief=m_convBelief=m_creatBelief=m_absBelief=m_retrBelief=m_dmdBelief=0;
      m_convexityMaturity=0; m_waveProgress=30.0; m_waveModelFit=50.0;
      m_preConvEvidence=m_inductionEvidence=false;
      m_liqgActive=false; m_liqgIsRetr=false; m_liqgDir=0; m_liqgTarget=NA_VAL; m_liqgInitDist=NA_VAL;
      m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=0;
     }

   //--- fill the cognition fields of F60State. Substrate must already
   //    have filled per-TF, canonical physics, network, structBias.
   void Compute(F60State &s)
     {
      m_barIndex++;
      double close=s.close, high=s.high, low=s.low;
      double atr=(s.atr>0?s.atr:MathMax(close*0.001,1e-10));
      double m5Hi=high, m5Lo=low;
      int l0_dir=s.tfDir[2];
      int structBias=s.structBias;
      double velocity=s.vel, acceleration=s.acc, convSmooth=s.convSmooth, efficiency=s.eff, displacement=s.disp;
      bool bullImpulse=s.bullImp, bearImpulse=s.bearImp, bullMomDecay=s.bullDec, bearMomDecay=s.bearDec;
      bool bullConvShift=s.bullCS, bearConvShift=s.bearCS, phys_vd70=s.vd70, phys_vd50=s.vd50;
      string ie1a=s.tfPhaseStr[2];

      //--- physics observation layer
      double convexityScore=MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);
      double obs_Exp=MathMin((efficiency>InpEffThresh? efficiency*60.0: efficiency*30.0)
                     +(displacement>InpDispThresh? (displacement/MathMax(InpDispThresh,1e-10)-1.0)*20.0:0.0)
                     +(velocity>0&&acceleration>0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2
                        : velocity<0&&acceleration<0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2:0.0),100.0);
      double obs_Decay=MathMin((bullMomDecay||bearMomDecay?40.0:0.0)+(convexityScore>30.0?convexityScore*0.5:0.0)+(phys_vd70?30.0:0.0),100.0);
      double obs_Curv=convexityScore;
      double obs_Abs=MathMin((efficiency<InpEffThresh*0.7? (1.0-efficiency/MathMax(InpEffThresh,1e-10))*50.0:0.0)+(phys_vd50?30.0:0.0)+(displacement<InpDispThresh*0.5?20.0:0.0),100.0);
      double obs_Liq=MathMin(obs_Decay*0.4+obs_Curv*0.4+(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?20.0:0.0),100.0);

      //--- EDE
      int ede_state=(ie1a=="Point 4 Origin")?1:(ie1a=="Expansion")?1:(ie1a=="Expansion Pre-Convexity")?2:
                    (ie1a=="Expansion Induction")?3:(ie1a=="Expansion Liquidity")?4:
                    (ie1a=="New High")?5:(ie1a=="New Low")?5:6;
      double ede_expEnergy=MathMin(obs_Exp*0.50+(bullImpulse||bearImpulse?30.0:0.0)+efficiency*20.0,100.0);
      double ede_diss=MathMin((ede_state>=2?obs_Decay*0.40:0.0)+(ede_state>=3?obs_Curv*0.30:0.0)+(ede_state>=4?obs_Liq*0.30:0.0),100.0);
      double ede_dissProg=MathMin((ede_state>=2?25.0:0.0)+(ede_state>=3?25.0:0.0)+(ede_state>=4?25.0:0.0)+(ede_state>=5?25.0:0.0),100.0);

      //--- RE (uses PREVIOUS spawn state)
      int re_expected=MathMax(1,MathMin(m_waveDepth+2,4));
      int re_completed=MathMax(0,MathMin(m_entryCycle,re_expected));
      double re_recCompl=re_expected>0?MathMin((double)re_completed/(double)re_expected*100.0,100.0):0.0;
      double re_residual=MathMax(0.0,ede_expEnergy-ede_diss);
      bool re_objReached=ede_state>=5;
      bool re_fullDiss=ede_dissProg>=75.0;
      bool re_absRet=(ie1a=="Demand Return"||ie1a=="Supply Return")&&m_recursiveComplete;
      string re_state=(re_absRet&&re_fullDiss&&re_recCompl>=75.0)?"RESOLVED":(re_objReached&&ede_dissProg>=50.0)?"PARTIALLY RESOLVED":"UNRESOLVED";
      double re_residualScore=MathMin(re_residual,100.0);
      int resCode=re_state=="RESOLVED"?2:re_state=="PARTIALLY RESOLVED"?1:0;

      //--- EAE
      double eae_price=m_direction==0?NA_VAL:
                       re_state=="UNRESOLVED"? (m_direction==1? Nz(m_flipBot,close-atr*2.0): Nz(m_flipTop,close+atr*2.0)):
                       re_state=="PARTIALLY RESOLVED"? (m_direction==1? Nz(m_p4Low,close-atr): Nz(m_p4High,close+atr)) : NA_VAL;
      double eae_score=MathMin(re_residualScore*0.40+(re_state=="UNRESOLVED"?30.0:re_state=="PARTIALLY RESOLVED"?20.0:5.0)
                       +(!IsNa(eae_price)?MathMax(0.0,30.0-MathAbs(close-eae_price)/MathMax(atr,1e-10)*5.0):0.0),100.0);

      //--- liquidity sweep + heat
      double swH=-DBL_MAX,swL=DBL_MAX;
      for(int sx=1;sx<=InpLiqSweepLookback;sx++){ swH=MathMax(swH,iHigh(m_sym,PERIOD_M5,sx)); swL=MathMin(swL,iLow(m_sym,PERIOD_M5,sx)); }
      bool liqSweepBull=!IsNa(m_flipTop)&&swH>m_flipTop;
      bool liqSweepBear=!IsNa(m_flipBot)&&swL<m_flipBot;
      double liqHeat=OmegaMath::Clamp(obs_Liq*0.5+(liqSweepBull||liqSweepBear?30.0:0.0),0.0,100.0);
      bool liqVacuum=liqHeat<10.0;
      bool liqSweepOK=!InpRequireLiqSweep||(m_direction==1&&(liqSweepBull||liqVacuum))||(m_direction==-1&&(liqSweepBear||liqVacuum));

      //--- liqg (uses PREVIOUS convexityMaturity)
      bool bullBOS=s.tfBos[2]==1, bearBOS=s.tfBos[2]==-1;
      double se5_tgt=s.tfTgt[2];
      bool liqgRetr=(ie1a=="Retracement Induction");
      bool liqgArm=(ie1a=="Expansion Induction")||liqgRetr;
      double liqgObj=se5_tgt;
      if(liqgArm&&!m_liqgActive&&!IsNa(liqgObj))
        { m_liqgActive=true; m_liqgIsRetr=liqgRetr; m_liqgTarget=liqgObj; m_liqgDir=liqgObj>close?1:-1; m_liqgInitDist=MathMax(MathAbs(liqgObj-close),atr*0.5); }
      if(m_liqgActive&&!IsNa(liqgObj)) m_liqgTarget=liqgObj;
      double liqgRemain=(m_liqgActive&&!IsNa(m_liqgTarget))?MathAbs(m_liqgTarget-close):NA_VAL;
      double liqgDistPct=(m_liqgActive&&!IsNa(liqgRemain))?MathMin(100.0,liqgRemain/MathMax(m_liqgInitDist,1e-10)*100.0):NA_VAL;
      bool liqgCapExh=ede_dissProg>60.0||m_convexityMaturity>60.0;
      bool liqgResolved=re_state=="RESOLVED";
      bool liqgEnergyLo=efficiency<InpEffThresh*0.7;
      bool liqgMagnet=m_liqgActive&&!IsNa(liqgDistPct)&&liqgDistPct<20.0;
      bool liqgArrStruct=m_liqgActive&&!IsNa(m_liqgTarget)&&(m_liqgDir==1?close>=m_liqgTarget:close<=m_liqgTarget);
      bool liqgArrPhys=liqgCapExh&&(liqgResolved||liqgMagnet);
      bool liqgObjArrival=liqgArrStruct&&liqgEnergyLo&&liqgArrPhys;
      bool liqgCounterBOS=m_liqgDir==1?bearBOS:bullBOS;
      bool liqgTrueCHoCH=liqgObjArrival&&liqgCounterBOS&&liqgEnergyLo&&liqgResolved;
      bool liqgInWindow=ie1a=="Expansion Induction"||ie1a=="Expansion Liquidity"||ie1a=="Retracement Induction"||ie1a=="Retracement Liquidity";
      if(m_liqgActive&&(!liqgInWindow||(liqgObjArrival&&liqgTrueCHoCH))) m_liqgActive=false;

      //=== geometry · similarity · convexity maturity · progress
      double originToExtreme=NA_VAL;
      if(!IsNa(m_p4High)&&!IsNa(m_p4Low))
        { double org=m_direction==1?m_p4Low:m_p4High; double ext=m_direction==1?Nz(m_cycleHigh,org):Nz(m_cycleLow,org); originToExtreme=MathAbs(ext-org); }
      double flipzoneWidth=(!IsNa(m_flipTop)&&!IsNa(m_flipBot))?m_flipTop-m_flipBot:NA_VAL;
      double ref_eff=MathMin(efficiency,1.0);
      double ref_disp=MathMin(displacement/MathMax(InpDispThresh*2.0,1e-10),1.0);
      double ref_vel=MathMin(MathAbs(velocity)/MathMax(atr*0.15,1e-10),1.0);
      double ref_curv=MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult*2.0,1e-10),1.0);
      double sim_Exp =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.85,0.80,0.80,0.10);
      double sim_PreC=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.60,0.55,0.40,0.50);
      double sim_Ind =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.65,0.60,0.30,0.60);
      double sim_Liqd=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.45,0.85,0.15,0.80);
      double sim_Creat=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.30,0.70,0.05,0.90);
      double sim_Abs =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.20,0.25,0.10,0.40);
      double sim_Retr=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.70,0.65,0.65,0.25);
      double sim_DmdR=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.50,0.40,0.35,0.20);
      double waveTotalRange=!IsNa(originToExtreme)?originToExtreme:atr*5.0;
      double currentToExtreme=m_direction==1?MathAbs(Nz(m_cycleHigh,close+atr)-close):MathAbs(close-Nz(m_cycleLow,close-atr));
      double posNormDen=MathMax(waveTotalRange,atr*0.5);
      double posDistToCreation=MathMin(currentToExtreme/posNormDen*100.0,100.0);
      double expWeakness=MathMin(((efficiency<InpEffThresh?(1.0-efficiency/MathMax(InpEffThresh,1e-10))*40.0:0.0)
                         +obs_Decay*0.30+(MathAbs(velocity)<MathAbs(s.velPrev2)*0.6?20.0:0.0))*(100.0/90.0),100.0);
      double inductionMat=MathMin((m_inductionEvidence?35.0:0.0)+obs_Curv*0.35+(m_preConvEvidence?20.0:0.0)
                          +(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?10.0:0.0),100.0);
      double liqMat=MathMin(obs_Liq*0.50+(liqSweepBull||liqSweepBear?30.0:0.0)+(liqHeat>60.0?20.0:liqHeat>30.0?10.0:0.0),100.0);
      double rawConvexityMaturity=MathMin(expWeakness*0.35+inductionMat*0.35+liqMat*0.30,100.0);
      double bSm=2.0/(InpBeliefSmooth+1.0);
      m_convexityMaturity+=bSm*(rawConvexityMaturity-m_convexityMaturity);
      double progressFromGeom=NA_VAL;
      if(!IsNa(m_p4High)&&!IsNa(m_flipTop)&&!IsNa(m_flipBot))
        {
         double org=m_direction==1?m_p4Low:m_p4High;
         double ext=m_direction==1?Nz(m_cycleHigh,close+atr):Nz(m_cycleLow,close-atr);
         double fzMid=(m_flipTop+m_flipBot)/2.0;
         double totalMove=MathAbs(ext-org), toFzMid=MathAbs(ext-fzMid);
         double expProg=totalMove>1e-10?MathMin(MathAbs(close-org)/totalMove*60.0,60.0):30.0;
         double retrMove=MathAbs(close-ext);
         double retrProg=toFzMid>1e-10?MathMin(retrMove/MathMax(toFzMid,1e-10)*40.0,40.0):0.0;
         progressFromGeom=expProg+retrProg*MathMin(obs_Abs/40.0,1.0);
        }
      double geomProgress=Nz(progressFromGeom,30.0);
      double simAnchor=(sim_DmdR>=sim_Retr&&sim_DmdR>=sim_Abs&&sim_DmdR>=sim_Creat&&sim_DmdR>=sim_Exp)?95.0:
                       (sim_Retr>=sim_Abs&&sim_Retr>=sim_Creat&&sim_Retr>=sim_Exp)?87.0:
                       (sim_Abs>=sim_Creat&&sim_Abs>=sim_Exp)?75.0:
                       (sim_Creat>=sim_Liqd&&sim_Creat>=sim_Exp)?62.0:
                       (sim_Liqd>=sim_Ind&&sim_Liqd>=sim_Exp)?52.0:
                       (sim_Ind>=sim_PreC&&sim_Ind>=sim_Exp)?43.0:(sim_PreC>=sim_Exp)?33.0:22.0;
      double convWeight=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
      double physProgress=simAnchor+(m_convexityMaturity/100.0)*(simAnchor-33.0)*0.50*convWeight;
      double rawWaveProgress=geomProgress*0.60+physProgress*0.40;
      m_waveProgress+=bSm*(rawWaveProgress-m_waveProgress);
      m_waveProgress=OmegaMath::Clamp(m_waveProgress,0.0,100.0);
      double bestSim=MathMax(sim_Exp,MathMax(sim_PreC,MathMax(sim_Ind,MathMax(sim_Liqd,MathMax(sim_Creat,MathMax(sim_Abs,MathMax(sim_Retr,sim_DmdR)))))));
      double geomConsistency=MathMin((!IsNa(originToExtreme)&&originToExtreme>atr*2.0?30.0:0.0)
                             +(!IsNa(flipzoneWidth)&&flipzoneWidth<atr*4.0?25.0:0.0)
                             +((!IsNa(m_cycleHigh)||!IsNa(m_cycleLow))?20.0:0.0)+(m_direction!=0?25.0:0.0),100.0);
      m_waveModelFit+=bSm*((bestSim*0.55+geomConsistency*0.45)-m_waveModelFit);
      m_waveModelFit=OmegaMath::Clamp(m_waveModelFit,0.0,100.0);

      //=== belief engine
      m_preConvEvidence=bullMomDecay||bearMomDecay;
      m_inductionEvidence=(m_direction==1&&bearImpulse&&structBias==1)||(m_direction==-1&&bullImpulse&&structBias==-1);
      bool liquidityEvidence=obs_Liq>50.0&&obs_Decay>40.0;
      double expPosMult=m_waveProgress<40.0?1.20:m_waveProgress<60.0?0.80:0.50;
      double rawExp=MathMin((obs_Exp*0.45+(bullImpulse||bearImpulse?30.0:0.0)+(efficiency>InpEffThresh*1.1?15.0:0.0)+sim_Exp*0.10)*expPosMult,100.0);
      double convPosMult=(m_waveProgress>=30.0&&m_waveProgress<=65.0)?1.30:0.70;
      double rawConv=MathMin((obs_Decay*0.30+obs_Curv*0.25+(m_preConvEvidence?15.0:0.0)+(m_inductionEvidence?10.0:0.0)+(liquidityEvidence?5.0:0.0)+m_convexityMaturity*0.08)*convPosMult,100.0);
      double creatPosMult=(m_waveProgress>=45.0&&m_waveProgress<=68.0)?1.40:0.60;
      double creatExtra=(!IsNa(m_cycleHigh)&&!IsNa(m_cycleLow)&&((m_direction==1&&high>=Nz(m_cycleHigh,high)*0.998)||(m_direction==-1&&low<=Nz(m_cycleLow,low)*1.002))?20.0:0.0);
      double rawCreat=MathMin(((m_convexityMaturity>50.0?m_convexityMaturity*0.12:0.0)+(obs_Decay>60.0?obs_Decay*0.20:0.0)+(obs_Liq>50.0?obs_Liq*0.20:0.0)+(obs_Abs>20.0?obs_Abs*0.15:0.0)+creatExtra+sim_Creat*0.10+(posDistToCreation<15.0?(15.0-posDistToCreation)*1.0:0.0))*creatPosMult,100.0);
      double rawAbs=MathMin(obs_Abs*0.50+(efficiency<InpEffThresh*0.6?25.0:0.0)+(displacement<InpDispThresh*0.5?15.0:0.0)+sim_Abs*0.10,100.0);
      double rawRetr=MathMin(((m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse)?45.0:0.0)+(rawAbs>50.0?rawAbs*0.30:0.0)+(obs_Curv>40.0?15.0:0.0)+sim_Retr*0.10,100.0);
      double rawDmd=MathMin((!IsNa(m_flipTop)&&!IsNa(m_flipBot)&&close<=m_flipTop&&close>=m_flipBot?35.0:0.0)+(rawRetr>60.0?rawRetr*0.30:0.0)+(liqHeat>50.0?liqHeat*0.15:0.0)+(liqSweepBull||liqSweepBear?20.0:0.0)+sim_DmdR*0.10,100.0);
      m_expBelief+=bSm*(rawExp-m_expBelief); m_convBelief+=bSm*(rawConv-m_convBelief); m_creatBelief+=bSm*(rawCreat-m_creatBelief);
      m_absBelief+=bSm*(rawAbs-m_absBelief); m_retrBelief+=bSm*(rawRetr-m_retrBelief); m_dmdBelief+=bSm*(rawDmd-m_dmdBelief);

      //=== spawn / wave state machine
      double l0_p4High=s.tfP4h[2], l0_p4Low=s.tfP4l[2];
      bool allowSpawn=l0_dir!=0&&l0_dir!=m_direction;
      if(allowSpawn)
        {
         double obTop=Nz(l0_p4High,close), obBot=Nz(l0_p4Low,close);
         m_lastSpawnDir=l0_dir; m_direction=l0_dir; m_flipTop=obTop; m_flipBot=obBot;
         m_obBirthBar=(int)m_barIndex; m_contBar=-1; m_p4High=obTop; m_p4Low=obBot;
         m_cycleHigh=m5Hi; m_cycleLow=m5Lo; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0;
        }
      if(m_direction==1&&m5Hi>Nz(m_cycleHigh,m5Hi)) m_cycleHigh=m5Hi;
      if(m_direction==-1&&m5Lo<Nz(m_cycleLow,m5Lo)) m_cycleLow=m5Lo;
      bool priceInDemand=!IsNa(m_flipBot)&&low<m_flipBot&&(!IsNa(m_p4High)&&low<=m_p4High);
      bool priceInSupply=!IsNa(m_flipTop)&&high>m_flipTop&&(!IsNa(m_p4Low)&&high>=m_p4Low);
      bool trueCHoCH_bull=m_direction==1&&priceInDemand&&bullImpulse&&liqSweepOK;
      bool trueCHoCH_bear=m_direction==-1&&priceInSupply&&bearImpulse&&liqSweepOK;
      bool structFlipBull=m_direction==1&&bullConvShift&&structBias==-1;
      bool structFlipBear=m_direction==-1&&bearConvShift&&structBias==1;
      bool recursiveTrigger=(trueCHoCH_bull||trueCHoCH_bear||structFlipBull||structFlipBear)&&(ie1a=="Demand Return"||ie1a=="Supply Return")&&m_dmdBelief>40.0&&m_direction!=0&&!IsNa(m_flipTop);
      bool recursiveJustFired=false;
      if(recursiveTrigger&&((int)m_barIndex-m_recursiveFiredBar)>InpResetBars){ recursiveJustFired=true; m_recursiveFiredBar=(int)m_barIndex; m_recursiveComplete=true; }
      if(recursiveJustFired)
        {
         m_waveGeneration++; m_entryCycle=MathMin(m_entryCycle+1,4); m_isRecursive=true; m_waveDepth=m_entryCycle;
         int nextDir=l0_dir!=0?l0_dir:((bullImpulse||bullConvShift)?1:-1);
         m_lastSpawnDir=nextDir; m_direction=l0_dir!=0?l0_dir:nextDir;
         m_flipTop=Nz(l0_p4High,close); m_flipBot=Nz(l0_p4Low,close);
         m_obBirthBar=(int)m_barIndex; m_p4High=m_flipTop; m_p4Low=m_flipBot;
         m_cycleHigh=m5Hi; m_cycleLow=m5Lo; m_contBar=(int)m_barIndex;
        }
      int barsSinceCont=(m_contBar>=0)?(int)m_barIndex-m_contBar:(m_obBirthBar>=0?(int)m_barIndex-m_obBirthBar:0);
      bool bullInvalid=m_direction==1&&!IsNa(m_flipBot)&&close<m_flipBot-atr*0.5;
      bool bearInvalid=m_direction==-1&&!IsNa(m_flipTop)&&close>m_flipTop+atr*0.5;
      bool opposingMove=(m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse);
      bool hardInvalid=bullInvalid||bearInvalid;
      bool softReset=barsSinceCont>InpResetBars&&opposingMove&&(ie1a!="Demand Return"&&ie1a!="Supply Return")&&m_dmdBelief<30.0&&m_expBelief<30.0;
      if(m_direction!=l0_dir&&(hardInvalid||softReset))
        { m_direction=0; m_lastSpawnDir=0; m_flipTop=NA_VAL; m_flipBot=NA_VAL; m_contBar=-1; m_obBirthBar=-1; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0; m_recursiveComplete=false; }

      //=== attack sequence
      double waveObj=Nz(m_liqgTarget,s.tfTgt[2]);
      double atkEntry=(!IsNa(m_flipTop)&&!IsNa(m_flipBot))?(m_flipTop+m_flipBot)/2.0:NA_VAL;
      double atkStop=s.tfInv[2];
      double atkT1=waveObj, atkT2=s.tfTgt[3], atkT3=s.tfTgt[4];
      int atkBias=(IsNa(atkEntry)||IsNa(atkT1))?(l0_dir!=0?l0_dir:m_direction):(atkT1>=atkEntry?1:-1);
      double atkRef=Nz(atkEntry,close);
      if(atkBias!=m_atkDirPrev){ m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=atkBias; }
      if(!IsNa(atkEntry)&&(atkBias==1?low<=atkEntry:high>=atkEntry)) m_atkEntered=true;
      if(!IsNa(atkStop)&&(atkStop<atkRef?close<atkStop:close>atkStop)) m_atkStop=true;
      if(!IsNa(atkT1)&&(atkT1>=atkRef?high>=atkT1:low<=atkT1)) m_atkT1=true;
      if(!IsNa(atkT2)&&(atkT2>=atkRef?high>=atkT2:low<=atkT2)) m_atkT2=true;
      if(!IsNa(atkT3)&&(atkT3>=atkRef?high>=atkT3:low<=atkT3)) m_atkT3=true;

      //=== publish into F60State
      s.obs_Exp=obs_Exp; s.obs_Decay=obs_Decay; s.obs_Curv=obs_Curv; s.obs_Abs=obs_Abs; s.obs_Liq=obs_Liq; s.convexityScore=convexityScore;
      s.ede_state=ede_state; s.ede_dissProg=ede_dissProg; s.ede_expEnergy=ede_expEnergy;
      s.resCode=resCode; s.re_residualScore=re_residualScore; s.eae_score=eae_score; s.eae_price=eae_price;
      s.liqg_active=m_liqgActive; s.liqg_target=m_liqgTarget; s.liqg_distPct=Nz(liqgDistPct,100.0);
      s.liqSweepBull=liqSweepBull; s.liqSweepBear=liqSweepBear; s.liqHeat=liqHeat;
      s.expBelief=m_expBelief; s.convBelief=m_convBelief; s.creatBelief=m_creatBelief;
      s.absBelief=m_absBelief; s.retrBelief=m_retrBelief; s.dmdBelief=m_dmdBelief;
      s.convexityMaturity=m_convexityMaturity; s.waveProgress=m_waveProgress; s.waveModelFit=m_waveModelFit;
      s.direction=m_direction; s.entryCycle=m_entryCycle; s.waveDepth=m_waveDepth;
      s.recursiveComplete=m_recursiveComplete; s.isRecursive=m_isRecursive;
      s.flipTop=m_flipTop; s.flipBot=m_flipBot; s.p4High=m_p4High; s.p4Low=m_p4Low; s.cycleHigh=m_cycleHigh; s.cycleLow=m_cycleLow;
      s.atkEntry=atkEntry; s.atkStop=atkStop; s.atkT1=atkT1; s.atkT2=atkT2; s.atkT3=atkT3;
      s.atkEntered=m_atkEntered; s.atkStopHit=m_atkStop; s.atkT1Hit=m_atkT1; s.atkT2Hit=m_atkT2; s.atkT3Hit=m_atkT3;
      s.waveObj=waveObj; s.waveOrigin=s.tfInv[2];
      s.waveDir=l0_dir; s.stackDir=s.fractalStackDir;
     }
   //--- accessors for force enrichment (residual + recursion depth)
   double ResidualEnergy() const { return m_convexityMaturity; }   // placeholder until Compute ran
   int    EntryCycle()     const { return m_entryCycle; }
  };

#endif // __HYPEROMEGA_F60_COGNITION_MQH__

// ====================== Include/F60/Substrate.mqh ======================
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
      int ow=(s.ownerTf>=0)?s.ownerTf:TF_CANON;
      double otgt=s.tfTgt[ow], oinv=s.tfInv[ow];
      if(!IsNa(otgt)&&!IsNa(oinv)&&MathAbs(otgt-oinv)>1e-10){ double tr=OmegaMath::Clamp(MathAbs(close-oinv)/MathAbs(otgt-oinv)*100.0,0.0,100.0); s.fce_travel=tr; s.fce_budget=MathMax(0.0,100.0-tr); }
      else { s.fce_travel=50.0; s.fce_budget=50.0; }
      s.fce_progress=s.fce_maturity;
      m_prevResidual=s.re_residualScore;
     }
   //--- tree snapshot for diagnostics
   string TreeSnapshot() { return m_tree.Snapshot(); }
  };

#endif // __HYPEROMEGA_F60_SUBSTRATE_MQH__

// ====================== Include/Observers/ObserverBus.mqh ======================
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

// ====================== Include/Observers/ObsA.mqh ======================
//+------------------------------------------------------------------+
//|                                            Observers/ObsA.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers A — ERF · FRZ · RIE. Each ENRICHED to consume        |
//|   authentic F60 outputs (L4): FCE residual, chain vitality,      |
//|   compression persistence, curve maturity/budget, Invisible      |
//|   Network nodes, curve-tree ownership transfer, participant      |
//|   interference. NO EMA/ATR proxies.                              |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_A_MQH__
#define __HYPEROMEGA_OBS_A_MQH__


class ObserversA
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      double atr=MathMax(s.atr,1e-10), close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== ERF — unresolved energy (FCE residual + compression
      //    persistence + chain vitality + curve maturity + force) ===
      o.erf_residual = OmegaMath::Clamp(s.fce_residual*0.45 + s.chainVitality*0.20
                       + s.tfCompPersist[own]*0.15 + (100.0-s.fce_maturity)*0.10
                       + (s.forceState==2?10.0:0.0), 0.0, 100.0);   // forceState 2 = PERSISTING
      o.erf_unresolvedDir = od;
      double exh = OmegaMath::Clamp((s.fce_maturity>70.0?40.0:0.0) + ((s.bullDec||s.bearDec)?20.0:0.0)
                   + (s.fce_budget<25.0?25.0:0.0) + (s.tfAtExt[own]?15.0:0.0), 0.0, 100.0);
      o.erf_exhaustScore = exh; o.erf_exhaustDir = od;

      //=== FRZ — supply/demand geometry · attractors (network nodes +
      //    curve ownership + flip zones + participant true induction) =
      double sup=s.nodeAbove, dem=s.nodeBelow;
      double oft=s.tfFt[own], ofb=s.tfFb[own];
      if(!IsNa(oft)&&oft>close&&(IsNa(sup)||oft<sup)) sup=oft;
      if(!IsNa(ofb)&&ofb<close&&(IsNa(dem)||ofb>dem)) dem=ofb;
      double tiPx=s.flipTrueInductionPx;
      if(tiPx>0)
        {
         if(tiPx>close && (IsNa(sup)||tiPx<sup)) sup=tiPx;
         if(tiPx<close && (IsNa(dem)||tiPx>dem)) dem=tiPx;
        }
      o.frz_supplyDistAtr = !IsNa(sup)? (sup-close)/atr : 99.0;
      o.frz_demandDistAtr = !IsNa(dem)? (close-dem)/atr : 99.0;
      double attr = s.tfTgt[own];
      if(IsNa(attr)) attr = (od==1)? sup : dem;
      o.frz_attractor = attr;
      o.frz_attractorScore = OmegaMath::Clamp(s.fce_budget*0.45 + s.chainVitality*0.25
                             + (s.eligibleNodes>0?20.0:0.0) + (s.flipQuality>50.0?10.0:0.0), 0.0, 100.0);
      o.frz_dir = od;
      double approachDist = (od==1)? o.frz_demandDistAtr : (od==-1)? o.frz_supplyDistAtr : 99.0;
      o.frz_approachQ = OmegaMath::Clamp(100.0 - approachDist*30.0, 0.0, 100.0);

      //=== RIE — rotation / control transfer (ownership transfer +
      //    recursion + participant interference + compression + shift) =
      bool ownerVsStruct = (od!=0 && s.structBias!=0 && od!=s.structBias);
      double rot = OmegaMath::Clamp((s.treeTransferDir!=0?25.0:0.0)
                   + MathMin(s.recursiveDepth*12.0, 36.0)
                   + (ownerVsStruct?20.0:0.0)
                   + s.participantInterference*0.20
                   + (s.compressionPersistChart>60.0?10.0:0.0)
                   + ((s.bullCS||s.bearCS)?10.0:0.0), 0.0, 100.0);
      o.rie_rotationProb = rot;
      o.rie_transferDir = (s.treeTransferDir!=0)? s.treeTransferDir
                          : (s.bullCS?1:s.bearCS?-1:(rot>50.0? -od : 0));
     }
  };

#endif // __HYPEROMEGA_OBS_A_MQH__

// ====================== Include/Observers/ObsB.mqh ======================
//+------------------------------------------------------------------+
//|                                            Observers/ObsB.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers B — MCE · NE · TQE. Enriched (L4):                   |
//|     MCE  : fractal stack + curve map + Time Intelligence (NOT a  |
//|            naive per-TF alignment %).                            |
//|     NE   : owner-phase lineage + campaign ownership + chain      |
//|            vitality -> dominant story.                           |
//|     TQE  : ERF + FRZ convergence + chain vitality + network      |
//|            pressure + participant interference (veto gate).      |
//|                                                                  |
//|   MCE runs before TQE (TQE reads mce_conflict). FRZ (ObsA) ran   |
//|   first, so TQE may read frz_*.                                  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_B_MQH__
#define __HYPEROMEGA_OBS_B_MQH__


class ObserversB
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== MCE — MTF consensus (fractal stack + curve map + TIE) ====
      o.mce_dir   = s.fractalStackDir;
      o.mce_score = OmegaMath::Clamp(s.fractalStackScore*0.60 + s.timeAlign*0.40, 0.0, 100.0);
      o.mce_conflict = OmegaMath::Clamp((od!=0 && s.fractalStackDir!=0 && od!=s.fractalStackDir ? 50.0:0.0)
                       + s.timeConflict*0.50, 0.0, 100.0);

      //=== NE — dominant narrative (owner phase lineage + chain) =====
      o.ne_dir = od; o.ne_maturity = s.fce_maturity;
      string ph = s.tfPhaseStr[own];
      string story;
      if(OmegaStr::Has(ph,"Expansion") && !OmegaStr::Has(ph,"Induction") && !OmegaStr::Has(ph,"Liquidity")) story="EXPANSION";
      else if(OmegaStr::Has(ph,"Induction") || OmegaStr::Has(ph,"Liquidity"))                              story="DISTRIBUTION";
      else if(OmegaStr::Has(ph,"Retracement") || OmegaStr::Has(ph,"Flip"))                                 story="ACCUMULATION";
      else if(OmegaStr::Has(ph,"Liquidation") || OmegaStr::Has(ph,"Terminal"))                             story="LIQUIDATION";
      else if(OmegaStr::Has(ph,"Demand Return") || OmegaStr::Has(ph,"Supply Return"))                      story="CAMPAIGN TRANSITION";
      else if(OmegaStr::Has(ph,"New High") || OmegaStr::Has(ph,"New Low"))                                 story="DELIVERY";
      else                                                                                                 story="BALANCE";
      // chain vitality strengthens / weakens the conviction of the story
      if(s.chainVitality<35.0 && story!="LIQUIDATION") story=story+" (weak)";
      o.ne_story = story;

      //=== TQE — trade qualification (veto gate) ===================
      double q = OmegaMath::Clamp(s.chainVitality*0.30 + o.frz_attractorScore*0.20
                 + MathAbs(s.pressure)*0.20 + o.frz_approachQ*0.15
                 + (s.eligibleNodes>0?MathMin(s.eligibleNodes*3.0,15.0):0.0), 0.0, 100.0);
      q -= o.mce_conflict*0.20 + (s.fce_maturity>90.0?15.0:0.0) + s.participantInterference*0.10;
      // a persisting force / fresh residual lifts qualification (L4)
      if(s.forceState==2) q += 8.0;
      if(o.erf_residual>60.0) q += 6.0;
      o.tqe_quality = OmegaMath::Clamp(q, 0.0, 100.0);
     }
  };

#endif // __HYPEROMEGA_OBS_B_MQH__

// ====================== Include/Observers/ObsC.mqh ======================
//+------------------------------------------------------------------+
//|                                            Observers/ObsC.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Observers C — TE · IE2 · WR/DWR. Enriched (L4):                |
//|     TE   : Invisible Network path nodes + FCE trajectory + owner |
//|            objective + attractor convergence.                    |
//|     IE2  : recursive origin / parent curve / owner invalidation  |
//|            / point-4 (where the campaign is broken).             |
//|     WR/DWR : wave registry depth + recursion completion.         |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBS_C_MQH__
#define __HYPEROMEGA_OBS_C_MQH__


class ObserversC
  {
public:
   static void Update(const F60State &s, ObserverBus &o)
     {
      double atr=MathMax(s.atr,1e-10), close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;

      //=== TE — targets (network path nodes + FCE trajectory + owner
      //    objective + attractor convergence) =======================
      double tgt = s.tfTgt[own];
      double pathNode = (od==1)? s.nodeAbove : (od==-1)? s.nodeBelow : NA_VAL;
      if(IsNa(tgt) && !IsNa(pathNode)) tgt = pathNode;
      // a node sitting between price and the objective is the nearer realistic target
      if(!IsNa(tgt) && !IsNa(pathNode))
        {
         if(od==1  && pathNode>close && pathNode<tgt) tgt=pathNode;
         if(od==-1 && pathNode<close && pathNode>tgt) tgt=pathNode;
        }
      o.te_target   = tgt; o.te_dir = od;
      o.te_travelAtr = (!IsNa(tgt))? MathAbs(tgt-close)/atr : 0.0;
      o.te_quality  = OmegaMath::Clamp(s.fce_budget*0.50 + o.frz_attractorScore*0.30 + s.chainVitality*0.20, 0.0, 100.0);

      //=== IE2 — invalidation (recursive origin / parent curve / owner
      //    invalidation / point-4) ===================================
      double inv = s.tfInv[own];
      if(IsNa(inv)) inv = (od==1)? s.tfP4l[own] : s.tfP4h[own];
      // widen to the parent (next higher) curve invalidation if more protective
      if(own<8 && !IsNa(s.tfInv[own+1]))
        {
         double pinv=s.tfInv[own+1];
         if(od==1  && pinv<Nz(inv,pinv)) inv=pinv;
         if(od==-1 && pinv>Nz(inv,pinv)) inv=pinv;
        }
      o.ie2_inv = inv;
      o.ie2_roomAtr = (!IsNa(inv))? MathAbs(close-inv)/atr : InpMinStopAtr;

      //=== WR / DWR — wave registry / depth =========================
      o.wr_depth     = s.recursiveDepth;
      o.wr_recursive = (s.isRecursive || s.recursiveComplete);
     }
  };

#endif // __HYPEROMEGA_OBS_C_MQH__

// ====================== Include/Observers/Observers.mqh ======================
//+------------------------------------------------------------------+
//|                                       Observers/Observers.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The V72 observer stack orchestrator. Runs every observer on    |
//|   the F60State snapshot and fills the ObserverBus. Orthogonal    |
//|   observers (L3), each fed by authentic F60 outputs (L4).        |
//|     A: ERF · FRZ · RIE   (Part 9)                                |
//|     B: MCE · NE  · TQE   (Part 10)                               |
//|     C: TE  · IE2 · WR/DWR (Part 11)                              |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OBSERVERS_MQH__
#define __HYPEROMEGA_OBSERVERS_MQH__


class Observers
  {
public:
   static void UpdateAll(const F60State &s, ObserverBus &o)
     {
      o.Reset();
      ObserversA::Update(s, o);    // ERF · FRZ · RIE
      ObserversB::Update(s, o);    // MCE · NE · TQE
      ObserversC::Update(s, o);    // TE · IE2 · WR/DWR
     }
  };

#endif // __HYPEROMEGA_OBSERVERS_MQH__

// ====================== Include/Hyper/Opportunity.mqh ======================
//+------------------------------------------------------------------+
//|                                          Hyper/Opportunity.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Opportunity record + entry families + management styles, and   |
//|   MetaInputs — the Senseei-style aggregate metrics (master ·     |
//|   alignment · conflict · threat · confidence · timing · intent · |
//|   opportunity · story). Per spec L11/L6 and the F60 extraction   |
//|   list item 17: these are HyperIntelligence INPUTS, not a        |
//|   decision authority.                                            |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_OPPORTUNITY_MQH__
#define __HYPEROMEGA_OPPORTUNITY_MQH__


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

//--- Senseei-input aggregate metrics (cockpit + HyperIntelligence inputs)
struct MetaInputs
  {
   int    master;
   double alignment, conflict, threat, confidence, oppScore;
   string timing, intent, opportunity, story;
   void Reset(){ master=0; alignment=50; conflict=0; threat=0; confidence=0; oppScore=0; timing="EARLY"; intent="BALANCE"; opportunity="NONE"; story="BALANCE"; }
  };

#endif // __HYPEROMEGA_OPPORTUNITY_MQH__

// ====================== Include/Hyper/HyperIntelligence.mqh ======================
//+------------------------------------------------------------------+
//|                                     Hyper/HyperIntelligence.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The commander, not a dictator. Consumes the F60 substrate +    |
//|   the whole observer bus and produces a SET of typed opportunities|
//|   (8 entry families), each carrying conviction / target /        |
//|   invalidation / management style / asymmetry. Dynamic context   |
//|   weighting raises the voice of whichever tool matters now; the  |
//|   Senseei-input meta metrics modulate (not gate); TQE can veto;  |
//|   selection is by asymmetry. (Risk is the master override — Risk |
//|   layer, Part 13.)                                               |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_HYPERINTELLIGENCE_MQH__
#define __HYPEROMEGA_HYPERINTELLIGENCE_MQH__


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
   static Opportunity Make(EntryFamily fam,int tfIdx,int dir,double entry,double target,double inv,double conv,const F60State &s)
     {
      Opportunity op;
      op.family=fam; op.tfIdx=tfIdx; op.tf=OmegaTfEnum(tfIdx); op.direction=dir;
      op.entry=entry; op.target=target; op.invalidation=inv; op.label=FamilyName(fam);
      bool ct=(dir!=0 && s.fractalStackDir!=0 && dir!=s.fractalStackDir);
      if(ct) conv*=0.78;
      op.conviction=OmegaMath::Clamp(conv,0.0,100.0);
      op.mgmt=PickMgmt(fam,ct,s);
      double atr=MathMax(s.atr,1e-10);
      double riskAtr=(!IsNa(inv))?MathAbs(entry-inv)/atr:InpMinStopAtr;
      if(riskAtr<InpMinStopAtr) riskAtr=InpMinStopAtr;
      double rewardAtr=(!IsNa(target))?MathAbs(target-entry)/atr:riskAtr*1.5;
      if(op.mgmt==MGMT_SCALP||op.mgmt==MGMT_COUNTERTREND) rewardAtr=MathMin(rewardAtr,riskAtr*2.0);
      op.stopAtr=riskAtr;
      op.asymmetry=(rewardAtr/riskAtr)*(op.conviction/100.0);
      bool ctOk=(!ct)||InpAllowCountertrend;
      op.valid=dir!=0 && ctOk && op.conviction>=(double)InpMinConviction && op.asymmetry>=InpMinAsymmetry;
      return op;
     }
public:
   //--- Senseei-input meta metrics (extraction item 17): inputs, not authority
   static void ComputeMeta(const F60State &s, const ObserverBus &o, MetaInputs &m)
     {
      m.Reset();
      int vt1=s.waveDir, vt2=s.stackDir, vt3=s.netBias, vt4=s.pdir;
      int sum=vt1+vt2+vt3+vt4;
      m.master=sum>0?1:sum<0?-1:0;
      int cast=(vt1!=0?1:0)+(vt2!=0?1:0)+(vt3!=0?1:0)+(vt4!=0?1:0);
      int forV=(vt1==m.master&&vt1!=0?1:0)+(vt2==m.master&&vt2!=0?1:0)+(vt3==m.master&&vt3!=0?1:0)+(vt4==m.master&&vt4!=0?1:0);
      m.alignment=cast>0?(double)forV/cast*100.0:50.0;
      m.conflict =cast>0?(double)(cast-forV)/cast*100.0:0.0;
      double residual=s.re_residualScore, attractor=s.eae_score, stackPct=s.fractalStackScore;
      m.threat=OmegaMath::Clamp(m.conflict*0.40+residual*0.28+s.timeConflict*0.12
               +(s.pdir!=0&&s.pdir!=m.master?18.0:0.0)+(s.resCode==1?10.0:0.0),0.0,100.0);
      m.confidence=OmegaMath::Clamp(m.alignment*0.40+s.timeAlign*0.12+stackPct*0.18
                   +attractor*0.15+MathMin(15.0,s.eligibleNodes*1.2)-m.threat*0.20,0.0,100.0);
      m.oppScore=OmegaMath::Clamp(m.alignment*0.40+attractor*0.30+stackPct*0.30-m.threat*0.35,0.0,100.0);
      string ie1a=s.tfPhaseStr[TF_CANON];
      m.timing=(OmegaStr::Has(ie1a,"Absorption")||s.resCode==2)?"RESOLVED":
               s.waveProgress<15.0?"VERY EARLY":s.waveProgress<35.0?"EARLY":
               s.waveProgress<55.0?"DEVELOPING":s.waveProgress<80.0?"MID CYCLE":
               s.waveProgress<96.0?"LATE":"TERMINAL";
      m.intent=m.conflict>55.0?"ABSORPTION":s.liqg_active?"DELIVERY":
               (OmegaStr::Has(ie1a,"Expansion")&&!OmegaStr::Has(ie1a,"Pre-Convexity")&&!OmegaStr::Has(ie1a,"Induction")&&!OmegaStr::Has(ie1a,"Liquidity"))?"EXPANSION":
               OmegaStr::Has(ie1a,"Pre-Convexity")?"CONTINUATION":OmegaStr::Has(ie1a,"Induction")?"RESOLUTION":
               OmegaStr::Has(ie1a,"Liquidity")?"DELIVERY":(OmegaStr::Has(ie1a,"New High")||OmegaStr::Has(ie1a,"New Low"))?"DELIVERY":
               m.master==0?"BALANCE":"CONTINUATION";
      m.opportunity=m.master==0?"NONE":m.conflict>60.0?"DEVELOPING":m.oppScore<20.0?"NONE":m.oppScore<40.0?"DEVELOPING":
                    m.oppScore<62.0?"GOOD":m.oppScore<82.0?"STRONG":"EXCEPTIONAL";
      m.story=o.ne_story;
     }

   //--- scan all entry families; return the best opportunity. meta is an out param.
   static bool Scan(const F60State &s, const ObserverBus &o, Opportunity &best, MetaInputs &meta)
     {
      ComputeMeta(s,o,meta);
      Opportunity cand[9]; int n=0;
      double close=s.close;
      int own=s.ownerTf>=0?s.ownerTf:TF_CANON; int od=s.ownerDir;
      double conflictPenalty=o.mce_conflict*0.25;
      double tqeGate=(o.tqe_quality<35.0)?(o.tqe_quality/35.0):1.0;
      bool   tqeVeto=(o.tqe_quality<20.0);
      // meta factor — commander modulation (confidence lifts, threat dampens)
      double metaFactor=OmegaMath::Clamp(0.70+meta.confidence/200.0-meta.threat/300.0,0.55,1.20);
      double g=tqeGate*metaFactor;

      // 1) CONTINUATION
      if(od!=0 && s.tfWp[own]>=18.0 && s.tfWp[own]<=85.0)
        { double conv=s.chainVitality*0.40+s.fractalStackScore*0.25+s.fce_budget*0.20+o.te_quality*0.15-conflictPenalty;
          cand[n++]=Make(FAM_CONTINUATION,own,od,close,o.te_target,o.ie2_inv,conv*g,s); }
      // 2) EXPANSION
      if(s.structBias!=0 && (s.bullImp||s.bearImp))
        { int dir=(s.bullImp?1:-1);
          double conv=s.tfMf[TF_CANON]*0.35+s.fce_residual*0.30+s.fractalStackScore*0.20+(s.eligibleNodes>0?15.0:0.0)-conflictPenalty;
          cand[n++]=Make(FAM_EXPANSION,TF_CANON,dir,close,o.te_target,o.ie2_inv,conv*g,s); }
      // 3) COMPRESSION RELEASE
      { int relIdx=TF_CANON; double bestCp=0; for(int i=1;i<=4;i++){ if(s.tfCompPersist[i]>bestCp){ bestCp=s.tfCompPersist[i]; relIdx=i; } }
        if(bestCp>58.0 && s.tfCompBars[relIdx]>=3 && (s.bullCS||s.bearCS||s.bullImp||s.bearImp))
          { int dir=(s.bullCS||s.bullImp)?1:-1;
            double conv=bestCp*0.40+s.fce_residual*0.30+s.tfMf[relIdx]*0.20+(s.eligibleNodes>0?10.0:0.0)-conflictPenalty;
            cand[n++]=Make(FAM_COMPRESSION,relIdx,dir,close,o.te_target,o.ie2_inv,conv*g,s); } }
      // 4) ROTATION (often counter-trend)
      if(o.rie_rotationProb>55.0 && o.rie_transferDir!=0)
        { int dir=o.rie_transferDir; double tgt=(dir==1)?s.nodeAbove:s.nodeBelow;
          double conv=o.rie_rotationProb*0.55+(s.treeTransferDir!=0?20.0:0.0)+(s.structBias==dir?15.0:0.0)-conflictPenalty*0.5;
          cand[n++]=Make(FAM_ROTATION,TF_CANON,dir,close,tgt,o.ie2_inv,conv*g,s); }
      // 5) NETWORK
      if(s.eligibleNodes>0 && MathAbs(s.pressure)>25.0 && s.pdir!=0)
        { int dir=s.pdir; double tgt=(dir==1)?s.nodeAbove:s.nodeBelow;
          double conv=MathAbs(s.pressure)*0.45+o.frz_attractorScore*0.30+MathMin(s.eligibleNodes*4.0,25.0)-conflictPenalty;
          cand[n++]=Make(FAM_NETWORK,TF_CANON,dir,close,tgt,o.ie2_inv,conv*g,s); }
      // 6) FLIP-ZONE
      if(od!=0 && o.frz_approachQ>55.0)
        { bool inZone=!IsNa(s.tfFt[own])&&!IsNa(s.tfFb[own])&&close<=s.tfFt[own]&&close>=s.tfFb[own];
          double conv=o.frz_approachQ*0.40+o.frz_attractorScore*0.30+s.chainVitality*0.20+(inZone?10.0:0.0)-conflictPenalty;
          cand[n++]=Make(FAM_FLIPZONE,own,od,close,o.te_target,o.ie2_inv,conv*g,s); }
      // 7) LIQUIDATION
      { string ph=s.tfPhaseStr[TF_CANON];
        if((OmegaStr::Has(ph,"Liquidation")||OmegaStr::Has(ph,"Terminal")||OmegaStr::Has(ph,"Demand Return")||OmegaStr::Has(ph,"Supply Return")) && od!=0)
          { double conv=50.0+(o.wr_recursive?20.0:0.0)+s.chainVitality*0.20+s.fce_residual*0.15-conflictPenalty;
            cand[n++]=Make(FAM_LIQUIDATION,TF_CANON,od,close,o.te_target,o.ie2_inv,conv*g,s); } }
      // 8) EXHAUSTION (fade)
      if(o.erf_exhaustScore>60.0 && od!=0)
        { int dir=-od; double tgt=(dir==1)?s.nodeAbove:s.nodeBelow;
          if(IsNa(tgt)) tgt=(dir==1)?close+s.atr*2.0:close-s.atr*2.0;
          double conv=o.erf_exhaustScore*0.55+s.fce_convexity*0.25+(s.tfAtExt[own]?15.0:0.0)-conflictPenalty*0.5;
          cand[n++]=Make(FAM_EXHAUSTION,own,dir,close,tgt,o.ie2_inv,conv*g,s); }

      best.valid=false; double bestA=-1.0;
      if(tqeVeto) return false;
      for(int i=0;i<n;i++) if(cand[i].valid && cand[i].asymmetry>bestA){ bestA=cand[i].asymmetry; best=cand[i]; }
      return best.valid;
     }
  };

#endif // __HYPEROMEGA_HYPERINTELLIGENCE_MQH__

// ====================== Include/Risk/Risk.mqh ======================
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

// ====================== Include/Exec/Execution.mqh ======================
//+------------------------------------------------------------------+
//|                                              Exec/Execution.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Execution Intelligence — CTrade router with multi-style        |
//|   management (scalp / runner / aggressive / countertrend). SL    |
//|   from IE2 invalidation, TP from TE objective shaped by style.   |
//|   Sizing by conviction · capital throttle · portfolio exposure.  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_EXECUTION_MQH__
#define __HYPEROMEGA_EXECUTION_MQH__


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
      double stop;
      if(!IsNa(op.invalidation)&&((op.direction==1&&op.invalidation<entry)||(op.direction==-1&&op.invalidation>entry))) stop=op.invalidation;
      else stop=(op.direction==1)?entry-InpMinStopAtr*atr:entry+InpMinStopAtr*atr;
      double md=MinStopDist();
      if(md>0){ if(op.direction==1&&(entry-stop)<md) stop=entry-md; if(op.direction==-1&&(stop-entry)<md) stop=entry+md; }
      stop=NormPx(stop);
      double stopPts=MathAbs(entry-stop)/m_point; if(stopPts<=0) return false;
      double tp=0.0;
      if(InpUseTargetTP)
        {
         double riskDist=MathAbs(entry-stop);
         double tgt=op.target;
         if(op.mgmt==MGMT_SCALP||op.mgmt==MGMT_COUNTERTREND){ double cap=(op.direction==1)?entry+riskDist*1.8:entry-riskDist*1.8; tgt=IsNa(tgt)?cap:(op.direction==1?MathMin(tgt,cap):MathMax(tgt,cap)); }
         if(op.mgmt==MGMT_RUNNER) tgt=op.target;
         if(!IsNa(tgt)&&((op.direction==1&&tgt>entry)||(op.direction==-1&&tgt<entry)))
           { if(md<=0||MathAbs(tgt-entry)>=md) tp=NormPx(tgt); }
        }
      double riskPct=InpRiskPctBase*OmegaMath::Clamp(convFrac,0.0,1.0);
      if(op.mgmt==MGMT_COUNTERTREND) riskPct*=0.5;
      else if(op.mgmt==MGMT_SCALP)   riskPct*=0.7;
      else if(op.mgmt==MGMT_AGGRESSIVE) riskPct*=1.15;
      double lots=OmegaRisk::LotsFor(m_sym,stopPts,riskPct,1.0,throttle,exposureBudgetPct);
      if(lots<=0){ OmegaLogger::Warn("EXEC",m_sym+" sizing=0 (exposure/throttle) — skip"); return false; }
      string cmt=StringFormat("HO %s/%s %s",FamilyName(op.family),MgmtName(op.mgmt),OmegaTfName(op.tfIdx));
      bool ok=(op.direction==1)?m_trade.Buy(lots,m_sym,0.0,stop,tp,cmt):m_trade.Sell(lots,m_sym,0.0,stop,tp,cmt);
      if(ok){ ticketOut=m_trade.ResultOrder(); volOut=lots;
              OmegaLogger::Decide("HYPER",StringFormat("%s OPEN %s %s/%s lots=%.2f conv=%.0f asym=%.2f SL=%.5f TP=%.5f",
                 m_sym,op.direction==1?"LONG":"SHORT",FamilyName(op.family),MgmtName(op.mgmt),lots,op.conviction,op.asymmetry,stop,tp)); }
      else OmegaLogger::Warn("EXEC",StringFormat("%s OPEN failed ret=%d",m_sym,m_trade.ResultRetcode()));
      return ok;
     }
  };

#endif // __HYPEROMEGA_EXECUTION_MQH__

// ====================== Include/Exec/PositionIntelligence.mqh ======================
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

// ====================== Include/Portfolio.mqh ======================
//+------------------------------------------------------------------+
//|                                                    Portfolio.mqh |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The top of the loop. SymbolEngine runs ONE symbol's full       |
//|   continuous awareness loop (substrate -> observers -> trinity   |
//|   -> opportunities -> risk/exposure -> execution -> position     |
//|   intelligence -> feedback). Portfolio runs many symbols with    |
//|   cross-symbol concurrency + exposure caps (spec L10/L11).       |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_PORTFOLIO_MQH__
#define __HYPEROMEGA_PORTFOLIO_MQH__


//==================================================================
//= SymbolEngine — one symbol's full continuous loop
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
   MetaInputs       m_meta;
   bool             m_haveScan, m_primed;
public:
   void Init(string sym)
     {
      m_sym=sym; m_sub.Init(sym); m_exec.Init(sym,InpMagic);
      m_camp.Reset(); m_meta.Reset(); m_haveScan=false; m_primed=false;
     }
   void Warmup(int bars){ m_sub.Warmup(bars); m_sub.Compute(m_f60); Observers::UpdateAll(m_f60,m_obs); m_trinity.Feed(m_f60,m_obs); m_primed=true; }
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
           { ulong tk; double vol; if(m_exec.Open(op,atr,op.conviction/100.0*0.7,cap.Throttle(),exposureBudget,tk,vol)) m_camp.adds++; }
        }
     }
   void Process(OmegaCapital &cap,int concurrentActive,double exposureBudget)
     {
      bool stepped=m_sub.DriveBars();
      if(stepped)
        {
         m_sub.Compute(m_f60);
         Observers::UpdateAll(m_f60,m_obs);
         m_trinity.Feed(m_f60,m_obs);
         m_haveScan=HyperIntelligence::Scan(m_f60,m_obs,m_best,m_meta);
        }
      if(cap.RequiresFlat()){ if(m_exec.CountActive()>0){ m_exec.CloseAll("Capital SUSPENDED"); m_camp.active=false; } return; }
      ManagePosition();
      if(stepped) ConsiderEntry(cap,concurrentActive,exposureBudget);
     }
   string Diag()
     {
      string fam=(m_haveScan&&m_best.valid)?StringFormat("%s/%s %s conv=%.0f asym=%.2f",
                   FamilyName(m_best.family),MgmtName(m_best.mgmt),m_best.direction==1?"L":m_best.direction==-1?"S":"-",
                   m_best.conviction,m_best.asymmetry):"no qualified opportunity";
      return StringFormat("%-9s own=%s%d stk=%d net=%d prs=%.0f vit=%.0f res=%.0f mat=%.0f | %s%s | M=%d cf=%.0f thr=%.0f | %s | pos=%d",
              m_sym, OmegaTfName(m_f60.ownerTf>=0?m_f60.ownerTf:TF_CANON), m_f60.ownerDir,
              m_f60.fractalStackDir, m_f60.netBias, m_f60.pressure, m_f60.chainVitality,
              m_f60.fce_residual, m_f60.fce_maturity, m_meta.story, "", m_meta.master, m_meta.confidence, m_meta.threat,
              fam, m_exec.CountActive());
     }
   void Trinity3(double &l,double &s,double &c){ l=m_trinity.life; s=m_trinity.stability; c=m_trinity.confidence; }
  };

//==================================================================
//= Portfolio — multi-symbol container + cross-symbol caps
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
      if(list=="") { m_eng[0].Init(_Symbol); m_count=1; }
      else
        {
         string parts[]; int k=StringSplit(list,(ushort)',',parts);
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
         openRisk=OmegaRisk::OpenRiskPct(InpMagic);
         budget=MathMax(0.0,InpMaxPortfolioRisk-openRisk);
        }
     }
   string Diag(){ string s=""; for(int i=0;i<m_count && i<8;i++) s+=m_eng[i].Diag()+"\n"; return s; }
   int Count(){ return m_count; }
  };

#endif // __HYPEROMEGA_PORTFOLIO_MQH__

//==================================================================
//= EA lifecycle  (full continuous loop)
//==================================================================
OmegaCapital g_capital;
Portfolio    g_port;
datetime     g_lastBeat = 0;

int OnInit()
  {
   OmegaLogger::Init(LOG_INFO, InpCsvLogs);
   OmegaLogger::LogInfo("EA", StringFormat("HYPEROMEGA v%s · %s · multi-symbol campaign manager", OMEGA_VERSION, _Symbol));
   g_capital.Init(InpDailyLimitPct, InpWeeklyLimitPct, InpHardLimitPct);
   g_port.Init();
   EventSetTimer(MathMax(5, InpHeartbeatSec));
   OmegaLogger::LogInfo("EA", "Initialized · F60 substrate + full V72 observers + HyperIntelligence opportunity engine.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
   OmegaLogger::LogInfo("EA", StringFormat("Deinit reason=%d", reason));
   OmegaLogger::Shutdown();
  }

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
   datetime now = TimeCurrent();
   if(g_lastBeat==0 || (now-g_lastBeat)>=InpHeartbeatSec)
     {
      g_lastBeat = now;
      OmegaLogger::LogInfo("HEARTBEAT", StringFormat("cap=%s thr=%.2f campaigns=%d openRisk=%.2f%%",
         CapName(g_capital.State()), g_capital.Throttle(), g_port.CountActiveCampaigns(), OmegaRisk::OpenRiskPct(InpMagic)));
     }
  }
//+------------------------------------------------------------------+
