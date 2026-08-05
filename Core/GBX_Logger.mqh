#ifndef GBX_LOGGER_MQH
#define GBX_LOGGER_MQH

#include "GBX_Enums.mqh"
#include "GBX_Constants.mqh"

class CGBXLogger
  {
private:
   bool m_debug_enabled;

   string LevelToString(const ENUM_GBX_LOG_LEVEL level) const
     {
      switch(level)
        {
         case GBX_LOG_DEBUG:   return "DEBUG";
         case GBX_LOG_INFO:    return "INFO";
         case GBX_LOG_WARNING: return "WARN";
         case GBX_LOG_ERROR:   return "ERROR";
        }
      return "UNKNOWN";
     }

public:
   CGBXLogger(void)
     {
      m_debug_enabled = false;
     }

   void Configure(const bool debug_enabled)
     {
      m_debug_enabled = debug_enabled;
     }

   void Write(const ENUM_GBX_LOG_LEVEL level,const string message) const
     {
      if(level == GBX_LOG_DEBUG && !m_debug_enabled)
         return;

      Print(StringFormat("[%s][%s][%s] %s",
                         GBX_NAME,
                         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                         LevelToString(level),
                         message));
     }

   void Debug(const string message) const
     {
      Write(GBX_LOG_DEBUG,message);
     }

   void Info(const string message) const
     {
      Write(GBX_LOG_INFO,message);
     }

   void Warning(const string message) const
     {
      Write(GBX_LOG_WARNING,message);
     }

   void Error(const string message) const
     {
      Write(GBX_LOG_ERROR,message);
     }
  };

#endif
