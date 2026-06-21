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

#include "F60/Substrate.mqh"
#include "Observers/Observers.mqh"
#include "Hyper/HyperIntelligence.mqh"
#include "Risk/Risk.mqh"
#include "Exec/Execution.mqh"
#include "Exec/PositionIntelligence.mqh"

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
