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

#include "Common.mqh"

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
