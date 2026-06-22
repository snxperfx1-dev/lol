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

#include "../Common.mqh"
#include "../Logger.mqh"

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
