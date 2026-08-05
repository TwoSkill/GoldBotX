#property copyright "GoldBot X"
#property version   "0.1.0"
#property strict

int OnInit()
{
   Print("[GoldBot X] Initialization successful.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("[GoldBot X] Shutdown.");
}

void OnTick()
{
   // Framework bootstrap. Trading logic will be added incrementally.
}
