//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                            HYPEROMEGA (OMEGA-F72) |
//|                                                                  |
//|   Explainability backbone. Every module logs through this.       |
//|   Sinks: Print() (always) + optional CSV decision/exec/except.   |
//|   Preserved from the F72 Omega lineage.                          |
//+------------------------------------------------------------------+
#ifndef __HYPEROMEGA_LOGGER_MQH__
#define __HYPEROMEGA_LOGGER_MQH__

#include "Common.mqh"

#define OMEGA_LOG_DIR "HyperOmega/logs"

enum ENUM_OMEGA_LOG_LEVEL
  {
   LOG_DEBUG     = 0,
   LOG_INFO      = 1,
   LOG_DECISION  = 2,
   LOG_EXECUTION = 3,
   LOG_WARNING   = 4,
   LOG_EXCEPTION = 5
  };

class OmegaLogger
  {
private:
   static int                  s_decisionFile, s_executionFile, s_exceptionFile;
   static bool                 s_initialized, s_csv;
   static ENUM_OMEGA_LOG_LEVEL s_minLevel;

   static string LevelString(ENUM_OMEGA_LOG_LEVEL l)
     {
      switch(l){ case LOG_DEBUG:return"DEBUG"; case LOG_INFO:return"INFO"; case LOG_DECISION:return"DECIDE";
                 case LOG_EXECUTION:return"EXEC"; case LOG_WARNING:return"WARN"; case LOG_EXCEPTION:return"EXCEPT"; }
      return "?";
     }
   static int OpenCsv(const string filename,const string header)
     {
      int h=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(h==INVALID_HANDLE){ Print("[HO-LOGGER] FileOpen failed ",filename," err=",GetLastError()); return INVALID_HANDLE; }
      FileSeek(h,0,SEEK_END);
      if(FileSize(h)==0) FileWriteString(h,header+"\n");
      return h;
     }
public:
   static bool Init(ENUM_OMEGA_LOG_LEVEL minLevel=LOG_INFO,bool csv=false)
     {
      s_minLevel=minLevel; s_csv=csv;
      if(s_csv)
        {
         s_decisionFile =OpenCsv(OMEGA_LOG_DIR+"/decision_log.csv","timestamp,symbol,decision,reason,life,stability,confidence,detail");
         s_executionFile=OpenCsv(OMEGA_LOG_DIR+"/execution_log.csv","timestamp,symbol,action,ticket,price,lots,reason,detail");
         s_exceptionFile=OpenCsv(OMEGA_LOG_DIR+"/exception_log.csv","timestamp,module,code,message");
        }
      s_initialized=true;
      LogInfo("LOGGER",StringFormat("Initialized · level=%s · csv=%s",LevelString(minLevel),csv?"on":"off"));
      return true;
     }
   static void Shutdown()
     {
      if(s_decisionFile!=INVALID_HANDLE){ FileClose(s_decisionFile); s_decisionFile=INVALID_HANDLE; }
      if(s_executionFile!=INVALID_HANDLE){ FileClose(s_executionFile); s_executionFile=INVALID_HANDLE; }
      if(s_exceptionFile!=INVALID_HANDLE){ FileClose(s_exceptionFile); s_exceptionFile=INVALID_HANDLE; }
      s_initialized=false;
     }
   static void Flush()
     {
      if(s_decisionFile!=INVALID_HANDLE) FileFlush(s_decisionFile);
      if(s_executionFile!=INVALID_HANDLE) FileFlush(s_executionFile);
      if(s_exceptionFile!=INVALID_HANDLE) FileFlush(s_exceptionFile);
     }
   static void SetMinLevel(ENUM_OMEGA_LOG_LEVEL l){ s_minLevel=l; }
   static ENUM_OMEGA_LOG_LEVEL MinLevel(){ return s_minLevel; }

   static void Log(ENUM_OMEGA_LOG_LEVEL level,string module,string msg)
     {
      if((int)level<(int)s_minLevel) return;
      string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      Print(StringFormat("[%s][%s][%s] %s",ts,LevelString(level),module,msg));
     }
   static void LogDebug(string m,string s){ Log(LOG_DEBUG,m,s); }
   static void LogInfo(string m,string s){ Log(LOG_INFO,m,s); }
   static void LogWarning(string m,string s){ Log(LOG_WARNING,m,s); }
   static void LogException(string module,int code,string msg)
     {
      Log(LOG_EXCEPTION,module,StringFormat("[%d] %s",code,msg));
      if(s_exceptionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS); FileWriteString(s_exceptionFile,StringFormat("%s,%s,%d,%s\n",ts,module,code,msg)); }
     }
   static void LogDecision(string symbol,ENUM_OMEGA_DECISION decision,ENUM_OMEGA_REASON reason,
                           double life,double stability,double confidence,string detail)
     {
      Log(LOG_DECISION,"DECIDE",StringFormat("%s · %s · r=%d · L=%.1f S=%.1f C=%.1f · %s",
          symbol,OmegaStr::DecisionToString(decision),(int)reason,life,stability,confidence,detail));
      if(s_decisionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
         FileWriteString(s_decisionFile,StringFormat("%s,%s,%s,%d,%.2f,%.2f,%.2f,%s\n",ts,symbol,OmegaStr::DecisionToString(decision),(int)reason,life,stability,confidence,detail)); }
     }
   static void LogExecution(string symbol,string action,ulong ticket,double price,double lots,ENUM_OMEGA_REASON reason,string detail)
     {
      Log(LOG_EXECUTION,"EXEC",StringFormat("%s · %s · #%I64u · px=%.5f · vol=%.2f · %s",symbol,action,ticket,price,lots,detail));
      if(s_executionFile!=INVALID_HANDLE){ string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
         FileWriteString(s_executionFile,StringFormat("%s,%s,%s,%I64u,%.5f,%.2f,%d,%s\n",ts,symbol,action,ticket,price,lots,(int)reason,detail)); }
     }
  };
int                  OmegaLogger::s_decisionFile  = INVALID_HANDLE;
int                  OmegaLogger::s_executionFile = INVALID_HANDLE;
int                  OmegaLogger::s_exceptionFile = INVALID_HANDLE;
bool                 OmegaLogger::s_initialized   = false;
bool                 OmegaLogger::s_csv           = false;
ENUM_OMEGA_LOG_LEVEL OmegaLogger::s_minLevel      = LOG_INFO;

#endif // __HYPEROMEGA_LOGGER_MQH__
