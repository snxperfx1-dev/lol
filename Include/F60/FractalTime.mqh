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

#include "../Common.mqh"

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
