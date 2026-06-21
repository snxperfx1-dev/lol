//+------------------------------------------------------------------+
//|                                             F60/Cognition.mqh    |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   The deep F60 cognition — the authentic V60 derived stack:      |
//|     physics observation -> EDE/RE/EAE energy framework ->        |
//|     liquidity sweep + liqg liquidation engine -> geometry /      |
//|     similarity / convexity-maturity / wave-progress -> belief    |
//|     engine (6 beliefs) -> spawn / wave state machine -> attack   |
//|     sequence.                                                    |
//|                                                                  |
//|   CognitionEngine holds the persistent wave/belief/liqg state    |
//|   and Compute() fills the F60State energy/belief/spawn/attack    |
//|   fields. Preserved faithfully from the V60 source. Forward-var  |
//|   ordering (EAE/RE/liqg read prev spawn state, then spawn        |
//|   updates) is honoured.                                          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_F60_COGNITION_MQH__
#define __HYPEROMEGA_F60_COGNITION_MQH__

#include "../F60State.mqh"

//--- ideal-state similarity kernel (curve phase fingerprinting)
double IdealSim(double e,double d,double v,double c,double eI,double dI,double vI,double cI)
  {
   double diff=(e-eI)*(e-eI)+(d-dI)*(d-dI)+(v-vI)*(v-vI)+(c-cI)*(c-cI);
   return MathMax(0.0,100.0*(1.0-diff/4.0));
  }

class CognitionEngine
  {
private:
   string m_sym; long m_barIndex;
   //--- spawn / wave state
   int    m_direction, m_lastSpawnDir;
   double m_flipTop, m_flipBot, m_p4High, m_p4Low, m_cycleHigh, m_cycleLow;
   int    m_obBirthBar, m_contBar, m_entryCycle, m_waveDepth, m_waveGeneration;
   bool   m_isRecursive, m_recursiveComplete; int m_recursiveFiredBar;
   //--- belief
   double m_expBelief, m_convBelief, m_creatBelief, m_absBelief, m_retrBelief, m_dmdBelief;
   double m_convexityMaturity, m_waveProgress, m_waveModelFit;
   bool   m_preConvEvidence, m_inductionEvidence;
   //--- liqg
   bool   m_liqgActive, m_liqgIsRetr; int m_liqgDir; double m_liqgTarget, m_liqgInitDist;
   //--- attack latches
   bool   m_atkEntered, m_atkStop, m_atkT1, m_atkT2, m_atkT3; int m_atkDirPrev;
public:
   void Init(string sym)
     {
      m_sym=sym; m_barIndex=0;
      m_direction=m_lastSpawnDir=0;
      m_flipTop=m_flipBot=m_p4High=m_p4Low=m_cycleHigh=m_cycleLow=NA_VAL;
      m_obBirthBar=m_contBar=-1; m_entryCycle=m_waveDepth=m_waveGeneration=0;
      m_isRecursive=false; m_recursiveComplete=false; m_recursiveFiredBar=-100000;
      m_expBelief=m_convBelief=m_creatBelief=m_absBelief=m_retrBelief=m_dmdBelief=0;
      m_convexityMaturity=0; m_waveProgress=30.0; m_waveModelFit=50.0;
      m_preConvEvidence=m_inductionEvidence=false;
      m_liqgActive=false; m_liqgIsRetr=false; m_liqgDir=0; m_liqgTarget=NA_VAL; m_liqgInitDist=NA_VAL;
      m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=0;
     }

   //--- fill the cognition fields of F60State. Substrate must already
   //    have filled per-TF, canonical physics, network, structBias.
   void Compute(F60State &s)
     {
      m_barIndex++;
      double close=s.close, high=s.high, low=s.low;
      double atr=(s.atr>0?s.atr:MathMax(close*0.001,1e-10));
      double m5Hi=high, m5Lo=low;
      int l0_dir=s.tfDir[2];
      int structBias=s.structBias;
      double velocity=s.vel, acceleration=s.acc, convSmooth=s.convSmooth, efficiency=s.eff, displacement=s.disp;
      bool bullImpulse=s.bullImp, bearImpulse=s.bearImp, bullMomDecay=s.bullDec, bearMomDecay=s.bearDec;
      bool bullConvShift=s.bullCS, bearConvShift=s.bearCS, phys_vd70=s.vd70, phys_vd50=s.vd50;
      string ie1a=s.tfPhaseStr[2];

      //--- physics observation layer
      double convexityScore=MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);
      double obs_Exp=MathMin((efficiency>InpEffThresh? efficiency*60.0: efficiency*30.0)
                     +(displacement>InpDispThresh? (displacement/MathMax(InpDispThresh,1e-10)-1.0)*20.0:0.0)
                     +(velocity>0&&acceleration>0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2
                        : velocity<0&&acceleration<0? MathMin(MathAbs(velocity)/MathMax(atr*0.1,1e-10)*50.0,100.0)*0.2:0.0),100.0);
      double obs_Decay=MathMin((bullMomDecay||bearMomDecay?40.0:0.0)+(convexityScore>30.0?convexityScore*0.5:0.0)+(phys_vd70?30.0:0.0),100.0);
      double obs_Curv=convexityScore;
      double obs_Abs=MathMin((efficiency<InpEffThresh*0.7? (1.0-efficiency/MathMax(InpEffThresh,1e-10))*50.0:0.0)+(phys_vd50?30.0:0.0)+(displacement<InpDispThresh*0.5?20.0:0.0),100.0);
      double obs_Liq=MathMin(obs_Decay*0.4+obs_Curv*0.4+(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?20.0:0.0),100.0);

      //--- EDE
      int ede_state=(ie1a=="Point 4 Origin")?1:(ie1a=="Expansion")?1:(ie1a=="Expansion Pre-Convexity")?2:
                    (ie1a=="Expansion Induction")?3:(ie1a=="Expansion Liquidity")?4:
                    (ie1a=="New High")?5:(ie1a=="New Low")?5:6;
      double ede_expEnergy=MathMin(obs_Exp*0.50+(bullImpulse||bearImpulse?30.0:0.0)+efficiency*20.0,100.0);
      double ede_diss=MathMin((ede_state>=2?obs_Decay*0.40:0.0)+(ede_state>=3?obs_Curv*0.30:0.0)+(ede_state>=4?obs_Liq*0.30:0.0),100.0);
      double ede_dissProg=MathMin((ede_state>=2?25.0:0.0)+(ede_state>=3?25.0:0.0)+(ede_state>=4?25.0:0.0)+(ede_state>=5?25.0:0.0),100.0);

      //--- RE (uses PREVIOUS spawn state)
      int re_expected=MathMax(1,MathMin(m_waveDepth+2,4));
      int re_completed=MathMax(0,MathMin(m_entryCycle,re_expected));
      double re_recCompl=re_expected>0?MathMin((double)re_completed/(double)re_expected*100.0,100.0):0.0;
      double re_residual=MathMax(0.0,ede_expEnergy-ede_diss);
      bool re_objReached=ede_state>=5;
      bool re_fullDiss=ede_dissProg>=75.0;
      bool re_absRet=(ie1a=="Demand Return"||ie1a=="Supply Return")&&m_recursiveComplete;
      string re_state=(re_absRet&&re_fullDiss&&re_recCompl>=75.0)?"RESOLVED":(re_objReached&&ede_dissProg>=50.0)?"PARTIALLY RESOLVED":"UNRESOLVED";
      double re_residualScore=MathMin(re_residual,100.0);
      int resCode=re_state=="RESOLVED"?2:re_state=="PARTIALLY RESOLVED"?1:0;

      //--- EAE
      double eae_price=m_direction==0?NA_VAL:
                       re_state=="UNRESOLVED"? (m_direction==1? Nz(m_flipBot,close-atr*2.0): Nz(m_flipTop,close+atr*2.0)):
                       re_state=="PARTIALLY RESOLVED"? (m_direction==1? Nz(m_p4Low,close-atr): Nz(m_p4High,close+atr)) : NA_VAL;
      double eae_score=MathMin(re_residualScore*0.40+(re_state=="UNRESOLVED"?30.0:re_state=="PARTIALLY RESOLVED"?20.0:5.0)
                       +(!IsNa(eae_price)?MathMax(0.0,30.0-MathAbs(close-eae_price)/MathMax(atr,1e-10)*5.0):0.0),100.0);

      //--- liquidity sweep + heat
      double swH=-DBL_MAX,swL=DBL_MAX;
      for(int sx=1;sx<=InpLiqSweepLookback;sx++){ swH=MathMax(swH,iHigh(m_sym,PERIOD_M5,sx)); swL=MathMin(swL,iLow(m_sym,PERIOD_M5,sx)); }
      bool liqSweepBull=!IsNa(m_flipTop)&&swH>m_flipTop;
      bool liqSweepBear=!IsNa(m_flipBot)&&swL<m_flipBot;
      double liqHeat=OmegaMath::Clamp(obs_Liq*0.5+(liqSweepBull||liqSweepBear?30.0:0.0),0.0,100.0);
      bool liqVacuum=liqHeat<10.0;
      bool liqSweepOK=!InpRequireLiqSweep||(m_direction==1&&(liqSweepBull||liqVacuum))||(m_direction==-1&&(liqSweepBear||liqVacuum));

      //--- liqg (uses PREVIOUS convexityMaturity)
      bool bullBOS=s.tfBos[2]==1, bearBOS=s.tfBos[2]==-1;
      double se5_tgt=s.tfTgt[2];
      bool liqgRetr=(ie1a=="Retracement Induction");
      bool liqgArm=(ie1a=="Expansion Induction")||liqgRetr;
      double liqgObj=se5_tgt;
      if(liqgArm&&!m_liqgActive&&!IsNa(liqgObj))
        { m_liqgActive=true; m_liqgIsRetr=liqgRetr; m_liqgTarget=liqgObj; m_liqgDir=liqgObj>close?1:-1; m_liqgInitDist=MathMax(MathAbs(liqgObj-close),atr*0.5); }
      if(m_liqgActive&&!IsNa(liqgObj)) m_liqgTarget=liqgObj;
      double liqgRemain=(m_liqgActive&&!IsNa(m_liqgTarget))?MathAbs(m_liqgTarget-close):NA_VAL;
      double liqgDistPct=(m_liqgActive&&!IsNa(liqgRemain))?MathMin(100.0,liqgRemain/MathMax(m_liqgInitDist,1e-10)*100.0):NA_VAL;
      bool liqgCapExh=ede_dissProg>60.0||m_convexityMaturity>60.0;
      bool liqgResolved=re_state=="RESOLVED";
      bool liqgEnergyLo=efficiency<InpEffThresh*0.7;
      bool liqgMagnet=m_liqgActive&&!IsNa(liqgDistPct)&&liqgDistPct<20.0;
      bool liqgArrStruct=m_liqgActive&&!IsNa(m_liqgTarget)&&(m_liqgDir==1?close>=m_liqgTarget:close<=m_liqgTarget);
      bool liqgArrPhys=liqgCapExh&&(liqgResolved||liqgMagnet);
      bool liqgObjArrival=liqgArrStruct&&liqgEnergyLo&&liqgArrPhys;
      bool liqgCounterBOS=m_liqgDir==1?bearBOS:bullBOS;
      bool liqgTrueCHoCH=liqgObjArrival&&liqgCounterBOS&&liqgEnergyLo&&liqgResolved;
      bool liqgInWindow=ie1a=="Expansion Induction"||ie1a=="Expansion Liquidity"||ie1a=="Retracement Induction"||ie1a=="Retracement Liquidity";
      if(m_liqgActive&&(!liqgInWindow||(liqgObjArrival&&liqgTrueCHoCH))) m_liqgActive=false;

      //=== geometry · similarity · convexity maturity · progress
      double originToExtreme=NA_VAL;
      if(!IsNa(m_p4High)&&!IsNa(m_p4Low))
        { double org=m_direction==1?m_p4Low:m_p4High; double ext=m_direction==1?Nz(m_cycleHigh,org):Nz(m_cycleLow,org); originToExtreme=MathAbs(ext-org); }
      double flipzoneWidth=(!IsNa(m_flipTop)&&!IsNa(m_flipBot))?m_flipTop-m_flipBot:NA_VAL;
      double ref_eff=MathMin(efficiency,1.0);
      double ref_disp=MathMin(displacement/MathMax(InpDispThresh*2.0,1e-10),1.0);
      double ref_vel=MathMin(MathAbs(velocity)/MathMax(atr*0.15,1e-10),1.0);
      double ref_curv=MathMin(MathAbs(convSmooth)/MathMax(atr*InpConvMult*2.0,1e-10),1.0);
      double sim_Exp =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.85,0.80,0.80,0.10);
      double sim_PreC=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.60,0.55,0.40,0.50);
      double sim_Ind =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.65,0.60,0.30,0.60);
      double sim_Liqd=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.45,0.85,0.15,0.80);
      double sim_Creat=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.30,0.70,0.05,0.90);
      double sim_Abs =IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.20,0.25,0.10,0.40);
      double sim_Retr=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.70,0.65,0.65,0.25);
      double sim_DmdR=IdealSim(ref_eff,ref_disp,ref_vel,ref_curv,0.50,0.40,0.35,0.20);
      double waveTotalRange=!IsNa(originToExtreme)?originToExtreme:atr*5.0;
      double currentToExtreme=m_direction==1?MathAbs(Nz(m_cycleHigh,close+atr)-close):MathAbs(close-Nz(m_cycleLow,close-atr));
      double posNormDen=MathMax(waveTotalRange,atr*0.5);
      double posDistToCreation=MathMin(currentToExtreme/posNormDen*100.0,100.0);
      double expWeakness=MathMin(((efficiency<InpEffThresh?(1.0-efficiency/MathMax(InpEffThresh,1e-10))*40.0:0.0)
                         +obs_Decay*0.30+(MathAbs(velocity)<MathAbs(s.velPrev2)*0.6?20.0:0.0))*(100.0/90.0),100.0);
      double inductionMat=MathMin((m_inductionEvidence?35.0:0.0)+obs_Curv*0.35+(m_preConvEvidence?20.0:0.0)
                          +(displacement>InpDispThresh*1.2&&(bullMomDecay||bearMomDecay)?10.0:0.0),100.0);
      double liqMat=MathMin(obs_Liq*0.50+(liqSweepBull||liqSweepBear?30.0:0.0)+(liqHeat>60.0?20.0:liqHeat>30.0?10.0:0.0),100.0);
      double rawConvexityMaturity=MathMin(expWeakness*0.35+inductionMat*0.35+liqMat*0.30,100.0);
      double bSm=2.0/(InpBeliefSmooth+1.0);
      m_convexityMaturity+=bSm*(rawConvexityMaturity-m_convexityMaturity);
      double progressFromGeom=NA_VAL;
      if(!IsNa(m_p4High)&&!IsNa(m_flipTop)&&!IsNa(m_flipBot))
        {
         double org=m_direction==1?m_p4Low:m_p4High;
         double ext=m_direction==1?Nz(m_cycleHigh,close+atr):Nz(m_cycleLow,close-atr);
         double fzMid=(m_flipTop+m_flipBot)/2.0;
         double totalMove=MathAbs(ext-org), toFzMid=MathAbs(ext-fzMid);
         double expProg=totalMove>1e-10?MathMin(MathAbs(close-org)/totalMove*60.0,60.0):30.0;
         double retrMove=MathAbs(close-ext);
         double retrProg=toFzMid>1e-10?MathMin(retrMove/MathMax(toFzMid,1e-10)*40.0,40.0):0.0;
         progressFromGeom=expProg+retrProg*MathMin(obs_Abs/40.0,1.0);
        }
      double geomProgress=Nz(progressFromGeom,30.0);
      double simAnchor=(sim_DmdR>=sim_Retr&&sim_DmdR>=sim_Abs&&sim_DmdR>=sim_Creat&&sim_DmdR>=sim_Exp)?95.0:
                       (sim_Retr>=sim_Abs&&sim_Retr>=sim_Creat&&sim_Retr>=sim_Exp)?87.0:
                       (sim_Abs>=sim_Creat&&sim_Abs>=sim_Exp)?75.0:
                       (sim_Creat>=sim_Liqd&&sim_Creat>=sim_Exp)?62.0:
                       (sim_Liqd>=sim_Ind&&sim_Liqd>=sim_Exp)?52.0:
                       (sim_Ind>=sim_PreC&&sim_Ind>=sim_Exp)?43.0:(sim_PreC>=sim_Exp)?33.0:22.0;
      double convWeight=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
      double physProgress=simAnchor+(m_convexityMaturity/100.0)*(simAnchor-33.0)*0.50*convWeight;
      double rawWaveProgress=geomProgress*0.60+physProgress*0.40;
      m_waveProgress+=bSm*(rawWaveProgress-m_waveProgress);
      m_waveProgress=OmegaMath::Clamp(m_waveProgress,0.0,100.0);
      double bestSim=MathMax(sim_Exp,MathMax(sim_PreC,MathMax(sim_Ind,MathMax(sim_Liqd,MathMax(sim_Creat,MathMax(sim_Abs,MathMax(sim_Retr,sim_DmdR)))))));
      double geomConsistency=MathMin((!IsNa(originToExtreme)&&originToExtreme>atr*2.0?30.0:0.0)
                             +(!IsNa(flipzoneWidth)&&flipzoneWidth<atr*4.0?25.0:0.0)
                             +((!IsNa(m_cycleHigh)||!IsNa(m_cycleLow))?20.0:0.0)+(m_direction!=0?25.0:0.0),100.0);
      m_waveModelFit+=bSm*((bestSim*0.55+geomConsistency*0.45)-m_waveModelFit);
      m_waveModelFit=OmegaMath::Clamp(m_waveModelFit,0.0,100.0);

      //=== belief engine
      m_preConvEvidence=bullMomDecay||bearMomDecay;
      m_inductionEvidence=(m_direction==1&&bearImpulse&&structBias==1)||(m_direction==-1&&bullImpulse&&structBias==-1);
      bool liquidityEvidence=obs_Liq>50.0&&obs_Decay>40.0;
      double expPosMult=m_waveProgress<40.0?1.20:m_waveProgress<60.0?0.80:0.50;
      double rawExp=MathMin((obs_Exp*0.45+(bullImpulse||bearImpulse?30.0:0.0)+(efficiency>InpEffThresh*1.1?15.0:0.0)+sim_Exp*0.10)*expPosMult,100.0);
      double convPosMult=(m_waveProgress>=30.0&&m_waveProgress<=65.0)?1.30:0.70;
      double rawConv=MathMin((obs_Decay*0.30+obs_Curv*0.25+(m_preConvEvidence?15.0:0.0)+(m_inductionEvidence?10.0:0.0)+(liquidityEvidence?5.0:0.0)+m_convexityMaturity*0.08)*convPosMult,100.0);
      double creatPosMult=(m_waveProgress>=45.0&&m_waveProgress<=68.0)?1.40:0.60;
      double creatExtra=(!IsNa(m_cycleHigh)&&!IsNa(m_cycleLow)&&((m_direction==1&&high>=Nz(m_cycleHigh,high)*0.998)||(m_direction==-1&&low<=Nz(m_cycleLow,low)*1.002))?20.0:0.0);
      double rawCreat=MathMin(((m_convexityMaturity>50.0?m_convexityMaturity*0.12:0.0)+(obs_Decay>60.0?obs_Decay*0.20:0.0)+(obs_Liq>50.0?obs_Liq*0.20:0.0)+(obs_Abs>20.0?obs_Abs*0.15:0.0)+creatExtra+sim_Creat*0.10+(posDistToCreation<15.0?(15.0-posDistToCreation)*1.0:0.0))*creatPosMult,100.0);
      double rawAbs=MathMin(obs_Abs*0.50+(efficiency<InpEffThresh*0.6?25.0:0.0)+(displacement<InpDispThresh*0.5?15.0:0.0)+sim_Abs*0.10,100.0);
      double rawRetr=MathMin(((m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse)?45.0:0.0)+(rawAbs>50.0?rawAbs*0.30:0.0)+(obs_Curv>40.0?15.0:0.0)+sim_Retr*0.10,100.0);
      double rawDmd=MathMin((!IsNa(m_flipTop)&&!IsNa(m_flipBot)&&close<=m_flipTop&&close>=m_flipBot?35.0:0.0)+(rawRetr>60.0?rawRetr*0.30:0.0)+(liqHeat>50.0?liqHeat*0.15:0.0)+(liqSweepBull||liqSweepBear?20.0:0.0)+sim_DmdR*0.10,100.0);
      m_expBelief+=bSm*(rawExp-m_expBelief); m_convBelief+=bSm*(rawConv-m_convBelief); m_creatBelief+=bSm*(rawCreat-m_creatBelief);
      m_absBelief+=bSm*(rawAbs-m_absBelief); m_retrBelief+=bSm*(rawRetr-m_retrBelief); m_dmdBelief+=bSm*(rawDmd-m_dmdBelief);

      //=== spawn / wave state machine
      double l0_p4High=s.tfP4h[2], l0_p4Low=s.tfP4l[2];
      bool allowSpawn=l0_dir!=0&&l0_dir!=m_direction;
      if(allowSpawn)
        {
         double obTop=Nz(l0_p4High,close), obBot=Nz(l0_p4Low,close);
         m_lastSpawnDir=l0_dir; m_direction=l0_dir; m_flipTop=obTop; m_flipBot=obBot;
         m_obBirthBar=(int)m_barIndex; m_contBar=-1; m_p4High=obTop; m_p4Low=obBot;
         m_cycleHigh=m5Hi; m_cycleLow=m5Lo; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0;
        }
      if(m_direction==1&&m5Hi>Nz(m_cycleHigh,m5Hi)) m_cycleHigh=m5Hi;
      if(m_direction==-1&&m5Lo<Nz(m_cycleLow,m5Lo)) m_cycleLow=m5Lo;
      bool priceInDemand=!IsNa(m_flipBot)&&low<m_flipBot&&(!IsNa(m_p4High)&&low<=m_p4High);
      bool priceInSupply=!IsNa(m_flipTop)&&high>m_flipTop&&(!IsNa(m_p4Low)&&high>=m_p4Low);
      bool trueCHoCH_bull=m_direction==1&&priceInDemand&&bullImpulse&&liqSweepOK;
      bool trueCHoCH_bear=m_direction==-1&&priceInSupply&&bearImpulse&&liqSweepOK;
      bool structFlipBull=m_direction==1&&bullConvShift&&structBias==-1;
      bool structFlipBear=m_direction==-1&&bearConvShift&&structBias==1;
      bool recursiveTrigger=(trueCHoCH_bull||trueCHoCH_bear||structFlipBull||structFlipBear)&&(ie1a=="Demand Return"||ie1a=="Supply Return")&&m_dmdBelief>40.0&&m_direction!=0&&!IsNa(m_flipTop);
      bool recursiveJustFired=false;
      if(recursiveTrigger&&((int)m_barIndex-m_recursiveFiredBar)>InpResetBars){ recursiveJustFired=true; m_recursiveFiredBar=(int)m_barIndex; m_recursiveComplete=true; }
      if(recursiveJustFired)
        {
         m_waveGeneration++; m_entryCycle=MathMin(m_entryCycle+1,4); m_isRecursive=true; m_waveDepth=m_entryCycle;
         int nextDir=l0_dir!=0?l0_dir:((bullImpulse||bullConvShift)?1:-1);
         m_lastSpawnDir=nextDir; m_direction=l0_dir!=0?l0_dir:nextDir;
         m_flipTop=Nz(l0_p4High,close); m_flipBot=Nz(l0_p4Low,close);
         m_obBirthBar=(int)m_barIndex; m_p4High=m_flipTop; m_p4Low=m_flipBot;
         m_cycleHigh=m5Hi; m_cycleLow=m5Lo; m_contBar=(int)m_barIndex;
        }
      int barsSinceCont=(m_contBar>=0)?(int)m_barIndex-m_contBar:(m_obBirthBar>=0?(int)m_barIndex-m_obBirthBar:0);
      bool bullInvalid=m_direction==1&&!IsNa(m_flipBot)&&close<m_flipBot-atr*0.5;
      bool bearInvalid=m_direction==-1&&!IsNa(m_flipTop)&&close>m_flipTop+atr*0.5;
      bool opposingMove=(m_direction==1&&bearImpulse)||(m_direction==-1&&bullImpulse);
      bool hardInvalid=bullInvalid||bearInvalid;
      bool softReset=barsSinceCont>InpResetBars&&opposingMove&&(ie1a!="Demand Return"&&ie1a!="Supply Return")&&m_dmdBelief<30.0&&m_expBelief<30.0;
      if(m_direction!=l0_dir&&(hardInvalid||softReset))
        { m_direction=0; m_lastSpawnDir=0; m_flipTop=NA_VAL; m_flipBot=NA_VAL; m_contBar=-1; m_obBirthBar=-1; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0; m_recursiveComplete=false; }

      //=== attack sequence
      double waveObj=Nz(m_liqgTarget,s.tfTgt[2]);
      double atkEntry=(!IsNa(m_flipTop)&&!IsNa(m_flipBot))?(m_flipTop+m_flipBot)/2.0:NA_VAL;
      double atkStop=s.tfInv[2];
      double atkT1=waveObj, atkT2=s.tfTgt[3], atkT3=s.tfTgt[4];
      int atkBias=(IsNa(atkEntry)||IsNa(atkT1))?(l0_dir!=0?l0_dir:m_direction):(atkT1>=atkEntry?1:-1);
      double atkRef=Nz(atkEntry,close);
      if(atkBias!=m_atkDirPrev){ m_atkEntered=m_atkStop=m_atkT1=m_atkT2=m_atkT3=false; m_atkDirPrev=atkBias; }
      if(!IsNa(atkEntry)&&(atkBias==1?low<=atkEntry:high>=atkEntry)) m_atkEntered=true;
      if(!IsNa(atkStop)&&(atkStop<atkRef?close<atkStop:close>atkStop)) m_atkStop=true;
      if(!IsNa(atkT1)&&(atkT1>=atkRef?high>=atkT1:low<=atkT1)) m_atkT1=true;
      if(!IsNa(atkT2)&&(atkT2>=atkRef?high>=atkT2:low<=atkT2)) m_atkT2=true;
      if(!IsNa(atkT3)&&(atkT3>=atkRef?high>=atkT3:low<=atkT3)) m_atkT3=true;

      //=== publish into F60State
      s.obs_Exp=obs_Exp; s.obs_Decay=obs_Decay; s.obs_Curv=obs_Curv; s.obs_Abs=obs_Abs; s.obs_Liq=obs_Liq; s.convexityScore=convexityScore;
      s.ede_state=ede_state; s.ede_dissProg=ede_dissProg; s.ede_expEnergy=ede_expEnergy;
      s.resCode=resCode; s.re_residualScore=re_residualScore; s.eae_score=eae_score; s.eae_price=eae_price;
      s.liqg_active=m_liqgActive; s.liqg_target=m_liqgTarget; s.liqg_distPct=Nz(liqgDistPct,100.0);
      s.liqSweepBull=liqSweepBull; s.liqSweepBear=liqSweepBear; s.liqHeat=liqHeat;
      s.expBelief=m_expBelief; s.convBelief=m_convBelief; s.creatBelief=m_creatBelief;
      s.absBelief=m_absBelief; s.retrBelief=m_retrBelief; s.dmdBelief=m_dmdBelief;
      s.convexityMaturity=m_convexityMaturity; s.waveProgress=m_waveProgress; s.waveModelFit=m_waveModelFit;
      s.direction=m_direction; s.entryCycle=m_entryCycle; s.waveDepth=m_waveDepth;
      s.recursiveComplete=m_recursiveComplete; s.isRecursive=m_isRecursive;
      s.flipTop=m_flipTop; s.flipBot=m_flipBot; s.p4High=m_p4High; s.p4Low=m_p4Low; s.cycleHigh=m_cycleHigh; s.cycleLow=m_cycleLow;
      s.atkEntry=atkEntry; s.atkStop=atkStop; s.atkT1=atkT1; s.atkT2=atkT2; s.atkT3=atkT3;
      s.atkEntered=m_atkEntered; s.atkStopHit=m_atkStop; s.atkT1Hit=m_atkT1; s.atkT2Hit=m_atkT2; s.atkT3Hit=m_atkT3;
      s.waveObj=waveObj; s.waveOrigin=s.tfInv[2];
      s.waveDir=l0_dir; s.stackDir=s.fractalStackDir;
     }
   //--- accessors for force enrichment (residual + recursion depth)
   double ResidualEnergy() const { return m_convexityMaturity; }   // placeholder until Compute ran
   int    EntryCycle()     const { return m_entryCycle; }
  };

#endif // __HYPEROMEGA_F60_COGNITION_MQH__
