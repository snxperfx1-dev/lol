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

#include "Opportunity.mqh"

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
