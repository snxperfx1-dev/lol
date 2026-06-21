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

#include "ObserverBus.mqh"
#include "ObsA.mqh"
#include "ObsB.mqh"      // Part 10
#include "ObsC.mqh"      // Part 11

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
