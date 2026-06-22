//+------------------------------------------------------------------+
//|                                              Exec/Execution.mqh  |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Execution Intelligence — CTrade router with multi-style        |
//|   management (scalp / runner / aggressive / countertrend). SL    |
//|   from IE2 invalidation, TP from TE objective shaped by style.   |
//|   Sizing by conviction · capital throttle · portfolio exposure.  |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_EXECUTION_MQH__
#define __HYPEROMEGA_EXECUTION_MQH__

#include <Trade/Trade.mqh>
#include "../Hyper/Opportunity.mqh"
#include "../Risk/Risk.mqh"
#include "../Logger.mqh"

class Execution
  {
private:
   CTrade m_trade; string m_sym; long m_magic; int m_digits; double m_point; long m_stops;
public:
   void Init(string sym,long magic)
     {
      m_sym=sym; m_magic=magic;
      m_digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS); m_point=SymbolInfoDouble(sym,SYMBOL_POINT);
      m_stops=(long)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
      m_trade.SetExpertMagicNumber(magic); m_trade.SetDeviationInPoints(InpSlippagePoints); m_trade.SetTypeFillingBySymbol(sym);
     }
   double NormPx(double p){ return NormalizeDouble(p,m_digits); }
   double MinStopDist(){ return (double)m_stops*m_point; }
   int CountActive(){ int n=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; n++; } return n; }
   int NetDir(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; return PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1; } return 0; }
   double TotalVolume(){ double v=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue; v+=PositionGetDouble(POSITION_VOLUME); } return v; }
   void CloseAll(string why)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         if(m_trade.PositionClose(tk)) OmegaLogger::Exec("EXEC",StringFormat("%s close #%I64u · %s",m_sym,tk,why)); }
     }
   void ClosePartial(double fraction,string why)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         double vol=PositionGetDouble(POSITION_VOLUME); double part=OmegaRisk::NormalizeLots(m_sym,vol*fraction);
         double mn=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN); if(part<mn||vol-part<mn) continue;
         if(m_trade.PositionClosePartial(tk,part)) OmegaLogger::Exec("EXEC",StringFormat("%s partial %.2f #%I64u · %s",m_sym,part,tk,why)); }
     }
   void ModifySL(double newSL)
     {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; if((long)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;
         int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1; double curSL=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
         double px=(dir==1)?SymbolInfoDouble(m_sym,SYMBOL_BID):SymbolInfoDouble(m_sym,SYMBOL_ASK);
         bool improve=(dir==1)?(curSL==0.0||newSL>curSL):(curSL==0.0||newSL<curSL);
         bool side=(dir==1)?(newSL<px):(newSL>px);
         double md=MinStopDist(); if(md>0&&MathAbs(px-newSL)<md) continue;
         if(improve&&side) m_trade.PositionModify(tk,NormPx(newSL),tp); }
     }
   //--- open an opportunity (sizing by conviction · throttle · exposure; SL/TP by mgmt)
   bool Open(const Opportunity &op,double atr,double convFrac,double throttle,double exposureBudgetPct,ulong &ticketOut,double &volOut)
     {
      ticketOut=0; volOut=0; if(op.direction==0||atr<=0) return false;
      double ask=SymbolInfoDouble(m_sym,SYMBOL_ASK), bid=SymbolInfoDouble(m_sym,SYMBOL_BID);
      double entry=(op.direction==1)?ask:bid;
      double stop;
      if(!IsNa(op.invalidation)&&((op.direction==1&&op.invalidation<entry)||(op.direction==-1&&op.invalidation>entry))) stop=op.invalidation;
      else stop=(op.direction==1)?entry-InpMinStopAtr*atr:entry+InpMinStopAtr*atr;
      double md=MinStopDist();
      if(md>0){ if(op.direction==1&&(entry-stop)<md) stop=entry-md; if(op.direction==-1&&(stop-entry)<md) stop=entry+md; }
      stop=NormPx(stop);
      double stopPts=MathAbs(entry-stop)/m_point; if(stopPts<=0) return false;
      double tp=0.0;
      if(InpUseTargetTP)
        {
         double riskDist=MathAbs(entry-stop);
         double tgt=op.target;
         if(op.mgmt==MGMT_SCALP||op.mgmt==MGMT_COUNTERTREND){ double cap=(op.direction==1)?entry+riskDist*1.8:entry-riskDist*1.8; tgt=IsNa(tgt)?cap:(op.direction==1?MathMin(tgt,cap):MathMax(tgt,cap)); }
         if(op.mgmt==MGMT_RUNNER) tgt=op.target;
         if(!IsNa(tgt)&&((op.direction==1&&tgt>entry)||(op.direction==-1&&tgt<entry)))
           { if(md<=0||MathAbs(tgt-entry)>=md) tp=NormPx(tgt); }
        }
      double riskPct=InpRiskPctBase*OmegaMath::Clamp(convFrac,0.0,1.0);
      if(op.mgmt==MGMT_COUNTERTREND) riskPct*=0.5;
      else if(op.mgmt==MGMT_SCALP)   riskPct*=0.7;
      else if(op.mgmt==MGMT_AGGRESSIVE) riskPct*=1.15;
      double lots=OmegaRisk::LotsFor(m_sym,stopPts,riskPct,1.0,throttle,exposureBudgetPct);
      if(lots<=0){ OmegaLogger::Warn("EXEC",m_sym+" sizing=0 (exposure/throttle) — skip"); return false; }
      string cmt=StringFormat("HO %s/%s %s",FamilyName(op.family),MgmtName(op.mgmt),OmegaTfName(op.tfIdx));
      bool ok=(op.direction==1)?m_trade.Buy(lots,m_sym,0.0,stop,tp,cmt):m_trade.Sell(lots,m_sym,0.0,stop,tp,cmt);
      if(ok){ ticketOut=m_trade.ResultOrder(); volOut=lots;
              OmegaLogger::Decide("HYPER",StringFormat("%s OPEN %s %s/%s lots=%.2f conv=%.0f asym=%.2f SL=%.5f TP=%.5f",
                 m_sym,op.direction==1?"LONG":"SHORT",FamilyName(op.family),MgmtName(op.mgmt),lots,op.conviction,op.asymmetry,stop,tp)); }
      else OmegaLogger::Warn("EXEC",StringFormat("%s OPEN failed ret=%d",m_sym,m_trade.ResultRetcode()));
      return ok;
     }
  };

#endif // __HYPEROMEGA_EXECUTION_MQH__
