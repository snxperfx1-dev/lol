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
