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

#include "../Observers/ObserverBus.mqh"

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
