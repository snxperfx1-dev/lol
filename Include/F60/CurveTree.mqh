//+------------------------------------------------------------------+
//|                                              F60/CurveTree.mqh   |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Layer 4-8 — the recursive curve tree: lineage, ownership,      |
//|   transfer, merge, chain vitality. Preserved from the F72 Omega  |
//|   Tree/* lineage, re-pointed to drive from the SEEngine canonical|
//|   curve (single structure authority, L2) instead of CurveState.  |
//|                                                                  |
//|   Produces: dominant owner (dir/energy/stability/depth), tree    |
//|   depth, recursion budget, transfer/merge events, chain vitality |
//|   — the spatial-lineage intelligence RIE/MCE/NE/ERF consume.     |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_CURVETREE_MQH__
#define __HYPEROMEGA_F60_CURVETREE_MQH__

#include "Structure.mqh"
#include "../Logger.mqh"

//=== Node death taxonomy ===========================================
enum ENUM_NODE_DEATH
  {
   NODE_ALIVE                    = 0,
   NODE_DEATH_DECAY              = 1,
   NODE_DEATH_TRANSFERRED        = 2,
   NODE_DEATH_MERGED             = 3,
   NODE_DEATH_TERMINAL_INDUCTION = 4,
   NODE_DEATH_REGIME_SHIFT       = 5
  };

//=== The atomic curve =============================================
struct CurveNode
  {
   long            id, parentId; int dir;
   double          origin, extreme, energy; bool alive; int depth;
   string          state; int bar; double comp, mat; int srcTf;
   double          forceAtBirth, forcePeak, forceAtDeath;
   datetime        birthTime, deathTime; ENUM_NODE_DEATH deathCause; long campaignId;
                   CurveNode(){ Reset(); }
   void Reset()
     {
      id=0; parentId=-1; dir=0; origin=0; extreme=0; energy=0; alive=false; depth=0; state="";
      bar=0; comp=0; mat=0; srcTf=0; forceAtBirth=forcePeak=forceAtDeath=0;
      birthTime=0; deathTime=0; deathCause=NODE_ALIVE; campaignId=0;
     }
   string EmergentState() const
     {
      if(depth>0){ if(energy>=70.0) return"Transition · recursive expansion"; if(energy>=40.0) return"Transition · recursive induction"; return"Transition · recursive liquidation"; }
      if(mat<12.0) return"Point 4 Origin";
      if(energy>=78.0&&mat>=70.0) return (dir==1?"New High":(dir==-1?"New Low":"Climax"));
      if(mat<35.0) return"Expansion";
      if(mat<55.0) return"Expansion Pre-Convexity";
      if(energy>=55.0) return"Expansion Induction";
      if(energy>=35.0) return"Expansion Liquidity";
      if(comp>=60.0) return"Retracement Pre-Convexity";
      if(energy>=18.0) return"Retracement Induction";
      return"Retracement";
     }
   bool Progressed(double bh,double bl) const { if(!alive) return false; if(dir==1) return bh>extreme; if(dir==-1) return bl<extreme; return false; }
   string Snapshot() const { return StringFormat("id=%I64d p=%I64d dir=%d depth=%d e=%.0f mat=%.0f comp=%.0f %s alive=%s",id,parentId,dir,depth,energy,mat,comp,state,alive?"Y":"N"); }
  };

//=== Ownership — shallowest curve that still holds energy ==========
struct OwnershipResult
  {
   int index, depth, direction; double energy, stability;
            OwnershipResult(){ index=-1; depth=999; direction=0; energy=0; stability=OMEGA_TRINITY_NEUTRAL; }
  };
class Ownership
  {
public:
   static OwnershipResult Pick(CurveNode &tree[],int count,double ownMinE=12.0)
     {
      OwnershipResult r;
      for(int i=0;i<count;i++)
        {
         if(!tree[i].alive) continue;
         if(tree[i].energy<ownMinE) continue;
         if(tree[i].depth<r.depth || (tree[i].depth==r.depth && tree[i].energy>r.energy))
           { r.index=i; r.depth=tree[i].depth; r.energy=tree[i].energy; r.direction=tree[i].dir; }
        }
      if(r.index<0)
        {
         double best=-1.0;
         for(int i=0;i<count;i++){ if(!tree[i].alive) continue; if(tree[i].energy>best){ best=tree[i].energy; r.index=i; r.depth=tree[i].depth; r.energy=tree[i].energy; r.direction=tree[i].dir; } }
        }
      if(r.index>=0)
        {
         double secondBest=0.0;
         for(int i=0;i<count;i++){ if(i==r.index||!tree[i].alive) continue; if(tree[i].energy>secondBest) secondBest=tree[i].energy; }
         double aboveFloor=OmegaMath::Clamp((r.energy-ownMinE)/(100.0-ownMinE),0.0,1.0);
         double gap=OmegaMath::Clamp((r.energy-secondBest)/100.0,0.0,1.0);
         r.stability=OmegaMath::Clamp(aboveFloor*60.0+gap*40.0,0.0,100.0);
        }
      else r.stability=OMEGA_TRINITY_NEUTRAL;
      return r;
     }
  };

//=== Transfer (counter child breaks parent origin -> new campaign) =
class Transfer
  {
public:
   static bool IsTransferEvent(CurveNode &tree[],int count,int childIdx,int parentIdx,double closeNow)
     {
      if(childIdx<0||childIdx>=count||parentIdx<0||parentIdx>=count) return false;
      if(!tree[childIdx].alive||!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir==0||tree[parentIdx].dir==0) return false;
      if(tree[childIdx].dir==tree[parentIdx].dir) return false;
      if(tree[parentIdx].energy>35.0) return false;
      double po=tree[parentIdx].origin; if(po==0.0) return false;
      if(tree[childIdx].dir==1 && closeNow>po) return true;
      if(tree[childIdx].dir==-1 && closeNow<po) return true;
      return false;
     }
   static bool Apply(CurveNode &tree[],int count,int parentIdx,datetime now)
     {
      if(parentIdx<0||parentIdx>=count||!tree[parentIdx].alive) return false;
      tree[parentIdx].alive=false; tree[parentIdx].deathTime=now; tree[parentIdx].deathCause=NODE_DEATH_TRANSFERRED; tree[parentIdx].forceAtDeath=tree[parentIdx].energy;
      return true;
     }
  };

//=== Merge (counter child dies inside parent range -> reinforce) ===
class Merge
  {
public:
   static bool IsMergeEvent(CurveNode &tree[],int count,int childIdx,int parentIdx,double closeNow)
     {
      if(childIdx<0||childIdx>=count||parentIdx<0||parentIdx>=count) return false;
      if(!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir==tree[parentIdx].dir) return false;
      double po=tree[parentIdx].origin; if(po==0.0) return false;
      if(tree[parentIdx].dir==1 && closeNow>po) return true;
      if(tree[parentIdx].dir==-1 && closeNow<po) return true;
      return false;
     }
   static bool Apply(CurveNode &tree[],int count,int childIdx,int parentIdx,datetime now)
     {
      if(childIdx<0||childIdx>=count||parentIdx<0||parentIdx>=count) return false;
      tree[childIdx].alive=false; tree[childIdx].deathTime=now; tree[childIdx].deathCause=NODE_DEATH_MERGED; tree[childIdx].forceAtDeath=tree[childIdx].energy;
      tree[parentIdx].energy=OmegaMath::Clamp(tree[parentIdx].energy+5.0,0.0,100.0);
      if(tree[parentIdx].energy>tree[parentIdx].forcePeak) tree[parentIdx].forcePeak=tree[parentIdx].energy;
      return true;
     }
  };

//=== Chain vitality ================================================
enum ENUM_CHAIN_SCOPE { CHAIN_HEALTHY=0, CHAIN_CURVE_ONLY=1, CHAIN_WEAKENING=2, CHAIN_WHOLE_DECAYING=3 };
class ChainHealth
  {
private:
   double m_lifeSeq[]; int m_seqHead, m_seqCount, m_seqCapacity; double m_wholeChainLife;
public:
            ChainHealth(){ m_seqCapacity=8; ArrayResize(m_lifeSeq,m_seqCapacity); Reset(); }
   void Reset(){ m_seqHead=0; m_seqCount=0; m_wholeChainLife=OMEGA_TRINITY_NEUTRAL; ArrayInitialize(m_lifeSeq,0.0); }
   void Sample(double life)
     {
      m_lifeSeq[m_seqHead]=life; m_seqHead=(m_seqHead+1)%m_seqCapacity; if(m_seqCount<m_seqCapacity) m_seqCount++;
      m_wholeChainLife=m_wholeChainLife+0.02*(life-m_wholeChainLife);
     }
   double Vitality() const
     {
      if(m_seqCount<2) return m_wholeChainLife;
      int latestIdx=(m_seqHead-1+m_seqCapacity)%m_seqCapacity;
      int earliestIdx=(m_seqHead-m_seqCount+m_seqCapacity)%m_seqCapacity;
      return OmegaMath::Clamp(OMEGA_TRINITY_NEUTRAL+(m_lifeSeq[latestIdx]-m_lifeSeq[earliestIdx]),0.0,100.0);
     }
   double WholeChainLife() const { return m_wholeChainLife; }
   ENUM_CHAIN_SCOPE Scope(double currentLife) const
     {
      if(currentLife>=50.0) return CHAIN_HEALTHY;
      if(Vitality()>=50.0) return CHAIN_CURVE_ONLY;
      if(WholeChainLife()>=45.0) return CHAIN_WEAKENING;
      return CHAIN_WHOLE_DECAYING;
     }
   static string ScopeString(ENUM_CHAIN_SCOPE s){ switch(s){ case CHAIN_HEALTHY:return"HEALTHY"; case CHAIN_CURVE_ONLY:return"CURVE_ONLY"; case CHAIN_WEAKENING:return"CHAIN_WEAKENING"; case CHAIN_WHOLE_DECAYING:return"WHOLE_DECAYING"; } return"UNKNOWN"; }
   double Score(double currentLife) const
     {
      switch(Scope(currentLife))
        {
         case CHAIN_HEALTHY:        return OmegaMath::Clamp(60.0+currentLife*0.4,0.0,100.0);
         case CHAIN_CURVE_ONLY:     return OmegaMath::Clamp(50.0+Vitality()*0.3,0.0,100.0);
         case CHAIN_WEAKENING:      return OmegaMath::Clamp(35.0+WholeChainLife()*0.2,0.0,100.0);
         case CHAIN_WHOLE_DECAYING: return OmegaMath::Clamp(WholeChainLife()*0.6,0.0,100.0);
        }
      return OMEGA_TRINITY_NEUTRAL;
     }
  };

//=== The recursive curve tree (driven by the SEEngine canonical) ===
#define OMEGA_TREE_CAPACITY  32
#define OMEGA_OWN_MIN_ENERGY 12.0

class OmegaCurveTree
  {
public:
   CurveNode tree[OMEGA_TREE_CAPACITY]; int count; long nextNodeId; ChainHealth chain;
   int      ownerIndex, ownerDir, ownerDepth; double ownerEnergy, ownerStability, ownerLife;
   int      treeAlive, treeDepth, recursionBudget;
   long     transfersCount, mergesCount, spawnsCount, decaysCount;
   string   symbol; long barsProcessed;
private:
   int FindFreeSlot()
     {
      for(int i=0;i<count;i++) if(tree[i].id==0) return i;
      if(count<OMEGA_TREE_CAPACITY) return count++;
      int evict=-1; datetime oldest=D'2099.01.01';
      for(int i=0;i<count;i++){ if(tree[i].alive) continue; if(tree[i].deathTime>0&&tree[i].deathTime<oldest){ oldest=tree[i].deathTime; evict=i; } }
      if(evict>=0){ tree[evict].Reset(); return evict; }
      double minE=1e9; for(int i=0;i<count;i++) if(tree[i].alive&&tree[i].energy<minE){ minE=tree[i].energy; evict=i; }
      if(evict>=0){ tree[evict].Reset(); return evict; }
      return -1;
     }
   int IndexOfId(long id) const { if(id<=0) return -1; for(int i=0;i<count;i++) if(tree[i].id==id) return i; return -1; }
public:
            OmegaCurveTree()
     {
      count=0; nextNodeId=1; ownerIndex=-1; ownerDir=0; ownerDepth=999;
      ownerEnergy=0; ownerStability=OMEGA_TRINITY_NEUTRAL; ownerLife=0;
      treeAlive=0; treeDepth=0; recursionBudget=1;
      transfersCount=mergesCount=spawnsCount=decaysCount=0; symbol=""; barsProcessed=0;
     }
   void Init(string sym){ symbol=sym; }
   void Reset()
     {
      for(int i=0;i<count;i++) tree[i].Reset();
      count=0; nextNodeId=1; chain.Reset();
      ownerIndex=-1; ownerDir=0; ownerDepth=999; ownerEnergy=0; ownerStability=OMEGA_TRINITY_NEUTRAL; ownerLife=0;
      treeAlive=0; treeDepth=0; recursionBudget=1; transfersCount=mergesCount=spawnsCount=decaysCount=0;
     }
   static int BudgetFromCompression(double compNow){ return (int)MathMax(1,MathMin(4,1+(int)MathRound(compNow/33.0))); }

   void SpawnRoot(SEEngine &se,double close,double high,double low)
     {
      int slot=FindFreeSlot(); if(slot<0) return;
      int d=se.o_dir; tree[slot].Reset();
      tree[slot].id=nextNodeId++; tree[slot].parentId=-1; tree[slot].dir=d;
      tree[slot].origin=(d==1)?Nz(se.o_p4l,close):Nz(se.o_p4h,close);
      tree[slot].extreme=(d==1)?MathMax(Nz(se.CycH(),high),high):MathMin(Nz(se.CycL(),low),low);
      tree[slot].energy=MathMax(40.0,MathMin(60.0+se.o_mf*0.4,90.0));
      tree[slot].alive=true; tree[slot].depth=0; tree[slot].bar=(int)barsProcessed;
      tree[slot].comp=se.o_compIdx; tree[slot].mat=se.o_wp; tree[slot].srcTf=0;
      tree[slot].forceAtBirth=tree[slot].energy; tree[slot].forcePeak=tree[slot].energy;
      tree[slot].birthTime=TimeCurrent(); tree[slot].state=tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",StringFormat("ROOT spawn · %s · %s",symbol,tree[slot].Snapshot()));
     }
   void SpawnChild(int parentIdx,int newDir,SEEngine &se,double close)
     {
      if(parentIdx<0||parentIdx>=count) return;
      if(tree[parentIdx].depth+1>recursionBudget) return;
      int slot=FindFreeSlot(); if(slot<0) return;
      tree[slot].Reset();
      tree[slot].id=nextNodeId++; tree[slot].parentId=tree[parentIdx].id; tree[slot].dir=newDir;
      tree[slot].origin=close; tree[slot].extreme=close;
      tree[slot].energy=MathMax(25.0,MathMin(50.0+se.o_mf*0.25,70.0));
      tree[slot].alive=true; tree[slot].depth=tree[parentIdx].depth+1; tree[slot].bar=(int)barsProcessed;
      tree[slot].comp=se.o_compIdx; tree[slot].mat=0.0; tree[slot].srcTf=0;
      tree[slot].forceAtBirth=tree[slot].energy; tree[slot].forcePeak=tree[slot].energy;
      tree[slot].birthTime=TimeCurrent(); tree[slot].state=tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",StringFormat("CHILD spawn · %s · parent=%I64d · %s",symbol,tree[parentIdx].id,tree[slot].Snapshot()));
     }

   //--- walk the tree once per canonical closed bar
   void Update(SEEngine &se,double close,double high,double low)
     {
      barsProcessed++;
      recursionBudget=BudgetFromCompression(se.o_compIdx);
      OwnershipResult own=Ownership::Pick(tree,count,OMEGA_OWN_MIN_ENERGY);

      bool noOwner=(own.index<0);
      if(noOwner && se.o_dir!=0){ SpawnRoot(se,close,high,low); own=Ownership::Pick(tree,count,OMEGA_OWN_MIN_ENERGY); }
      else if(own.index>=0)
        {
         int ownDir=tree[own.index].dir;
         if((ownDir==1 && se.o_ch==-1) || (ownDir==-1 && se.o_ch==1)) SpawnChild(own.index,-ownDir,se,close);
        }

      //--- energy / extreme update
      int wdir=F60DirByOrigin(se.o_inv,se.o_dir,close);
      for(int i=0;i<count;i++)
        {
         if(!tree[i].alive) continue;
         if(tree[i].depth==0)
           {
            tree[i].dir=wdir;
            tree[i].origin=IsNa(se.o_inv)?tree[i].origin:se.o_inv;
            double e1=(tree[i].dir==1)?MathMax(Nz(se.CycH(),high),high):MathMin(Nz(se.CycL(),low),low);
            if(tree[i].dir==1)  tree[i].extreme=MathMax(tree[i].extreme,e1);
            if(tree[i].dir==-1) tree[i].extreme=(tree[i].extreme==0.0)?e1:MathMin(tree[i].extreme,e1);
           }
         else
           {
            if(tree[i].dir==1)  tree[i].extreme=MathMax(tree[i].extreme,high);
            if(tree[i].dir==-1) tree[i].extreme=(tree[i].extreme==0.0)?low:MathMin(tree[i].extreme,low);
           }
         bool prog=tree[i].Progressed(high,low);
         tree[i].energy=prog?MathMin(100.0,tree[i].energy+7.0):MathMax(0.0,tree[i].energy-2.0);
         if(tree[i].energy>tree[i].forcePeak) tree[i].forcePeak=tree[i].energy;
         tree[i].mat=(tree[i].depth==0)?se.o_wp:tree[i].mat;
         tree[i].comp=se.o_compIdx; tree[i].state=tree[i].EmergentState();
        }

      //--- death: transfer / merge / decay
      datetime now=TimeCurrent();
      for(int i=0;i<count;i++)
        {
         if(!tree[i].alive) continue;
         if(tree[i].depth>0)
           {
            int pIdx=IndexOfId(tree[i].parentId);
            if(pIdx>=0 && Transfer::IsTransferEvent(tree,count,i,pIdx,close))
              { Transfer::Apply(tree,count,pIdx,now); transfersCount++; chain.Sample(tree[pIdx].forceAtDeath);
                OmegaLogger::LogWarning("TREE",StringFormat("TRANSFER · child #%I64d broke parent #%I64d",tree[i].id,tree[pIdx].id)); }
           }
         if(tree[i].energy<=2.0)
           {
            int pIdx=IndexOfId(tree[i].parentId);
            if(tree[i].depth>0 && pIdx>=0 && Merge::IsMergeEvent(tree,count,i,pIdx,close))
              { Merge::Apply(tree,count,i,pIdx,now); mergesCount++;
                OmegaLogger::LogInfo("TREE",StringFormat("MERGE · child #%I64d -> parent #%I64d",tree[i].id,tree[pIdx].id)); }
            else
              { tree[i].alive=false; tree[i].deathTime=now; tree[i].deathCause=NODE_DEATH_DECAY; tree[i].forceAtDeath=tree[i].energy; decaysCount++; }
            chain.Sample(tree[i].forcePeak*0.6);
           }
        }

      //--- recompute ownership + summary
      own=Ownership::Pick(tree,count,OMEGA_OWN_MIN_ENERGY);
      ownerIndex=own.index; ownerDir=own.direction; ownerDepth=own.depth;
      ownerEnergy=own.energy; ownerStability=own.stability; ownerLife=own.energy;
      treeAlive=0; treeDepth=0;
      for(int i=0;i<count;i++){ if(!tree[i].alive) continue; treeAlive++; if(tree[i].depth>treeDepth) treeDepth=tree[i].depth; }
      if(ownerIndex>=0) chain.Sample(ownerEnergy);
     }

   double ChainVitality() const { return chain.Vitality(); }
   double ChainScore()    const { return chain.Score(ownerLife); }
   string ChainScopeStr() const { return ChainHealth::ScopeString(chain.Scope(ownerLife)); }
   string Snapshot() const
     {
      return StringFormat("owner=%d ownDir=%d ownE=%.0f stab=%.0f depth=%d/%d alive=%d trans=%I64d merge=%I64d decay=%I64d chainV=%.0f",
              ownerIndex,ownerDir,ownerEnergy,ownerStability,treeDepth,recursionBudget,treeAlive,
              transfersCount,mergesCount,decaysCount,chain.Vitality());
     }
  };

#endif // __HYPEROMEGA_F60_CURVETREE_MQH__
