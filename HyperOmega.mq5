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
//= MODULE INCLUDES — one stratum per file (built in parts)
//==================================================================
#include "Include/Common.mqh"
#include "Include/Logger.mqh"
//--- F60 substrate (Parts 2-8)
#include "Include/F60/Physics.mqh"
#include "Include/F60/Structure.mqh"
#include "Include/F60/CurveFramework.mqh"     // Part 3
#include "Include/F60/CurveTree.mqh"          // Part 4
#include "Include/F60/Network.mqh"            // Part 5
#include "Include/F60/Participants.mqh"       // Part 6
#include "Include/F60/FractalTime.mqh"        // Part 7
#include "Include/F60/Cognition.mqh"          // Part 8
#include "Include/F60/Substrate.mqh"          // Part 8 (aggregator -> F60State)
//--- Observers (Parts 9-11)
#include "Include/Observers/Observers.mqh"
//--- HyperIntelligence (Part 12)
#include "Include/Hyper/HyperIntelligence.mqh"
//--- Risk + Execution + Position Intelligence (Parts 13-14)
#include "Include/Risk/Risk.mqh"
//#include "Include/Exec/Execution.mqh"
//#include "Include/Exec/PositionIntelligence.mqh"
//--- Portfolio (Part 15)
//#include "Include/Portfolio.mqh"

//==================================================================
//= EA lifecycle  (wiring completed in Part 15)
//==================================================================
datetime g_lastBeat = 0;

int OnInit()
  {
   OmegaLogger::Init(LOG_INFO, InpCsvLogs);
   OmegaLogger::LogInfo("EA", StringFormat("HYPEROMEGA v%s · %s · modular build (parts landing)", OMEGA_VERSION, _Symbol));
   EventSetTimer(MathMax(5, InpHeartbeatSec));
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
   // Full continuous loop wired in Part 15 (Portfolio.Update).
  }

void OnTimer()
  {
   datetime now = TimeCurrent();
   if(g_lastBeat==0 || (now-g_lastBeat)>=InpHeartbeatSec)
     {
      g_lastBeat = now;
      OmegaLogger::LogInfo("HEARTBEAT", "alive · awaiting full wiring (Part 15)");
     }
  }
//+------------------------------------------------------------------+
