//+------------------------------------------------------------------+
//|                                             AggressiveScalper.mq5 |
//|                                  Copyright 2024, Google Deepmind |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Google Deepmind"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input double   FixedLot          = 0.5;      // Fixed Lot Size
input int      StopLossPoints    = 300;      // Stop Loss in Points
input int      TakeProfitPoints  = 150;      // Take Profit in Points
input int      MaxPositions      = 3;        // Max Concurrent Positions
input int      TrailingStart     = 50;       // Trailing Start (Points)
input int      TrailingStep      = 20;       // Trailing Step (Points)
input int      MaxSpreadPoints   = 40;       // Max Allowed Spread (Points)
input int      MagicNumber       = 123456;   // Magic Number

//--- Global variables
CTrade         trade;
int            stochHandle;
datetime       lastTradeCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize Trade Class
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_IOC); // Or ORDER_FILLING_FOK depending on broker
   trade.SetDeviationInPoints(10); // Slippage

//--- Initialize Stochastic Indicator
   stochHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   if(stochHandle == INVALID_HANDLE)
     {
      Print("Failed to create Stochastic handle");
      return(INIT_FAILED);
     }

//--- Print Contract Details
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   Print("=== EA Initialized ===");
   Print("Symbol: ", _Symbol);
   Print("Contract Size: ", contractSize);
   Print("Min Volume: ", minVolume);
   Print("Max Spread Allowed: ", MaxSpreadPoints);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(stochHandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- 1. Check Spread
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
      return;

//--- 2. Manage Trailing Stop
   ManageTrailingStop();

//--- 3. Check Max Positions
   if(PositionsTotal() >= MaxPositions)
      return;

//--- 4. Check One Trade Per Candle
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentCandleTime == lastTradeCandleTime)
      return;

//--- 5. Get Indicator Values
   double main[], signal[];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);

   if(CopyBuffer(stochHandle, 0, 0, 2, main) < 2 || CopyBuffer(stochHandle, 1, 0, 2, signal) < 2)
      return;

   // Index 0 is current tick, Index 1 is previous closed candle (approx, actually just previous bar in array)
   // Wait, CopyBuffer with start 0 gets current forming bar at index 0.
   // We want to detect crossover on the current tick compared to "previous state".
   // "Previous state" could be the previous tick, but MQL5 doesn't store previous tick indicator values easily without custom arrays.
   // However, the user asked for "On Tick" execution.
   // Standard approach: Compare Index 0 (Current) vs Index 1 (Previous Bar).
   // If Cross happened *within* the current bar, Index 0 will show the new state, but Index 1 will show the old state (from closed bar).
   // This confirms a cross occurred sometime between Close[1] and Current Tick.
   // This is robust enough for "On Tick" trading without tick-by-tick array management.

   double main0 = main[0];
   double signal0 = signal[0];
   double main1 = main[1];
   double signal1 = signal[1];

//--- 6. Signal Logic
   bool buySignal = (main1 < signal1) && (main0 > signal0) && (main0 < 20);
   bool sellSignal = (main1 > signal1) && (main0 < signal0) && (main0 > 80);

//--- 7. Execute Trade
   if(buySignal)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - StopLossPoints * _Point;
      double tp = ask + TakeProfitPoints * _Point;
      
      if(trade.Buy(FixedLot, _Symbol, ask, sl, tp, "Aggressive Buy"))
        {
         lastTradeCandleTime = currentCandleTime;
         Print("Buy Order Opened. Ticket: ", trade.ResultOrder());
        }
     }
   else if(sellSignal)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + StopLossPoints * _Point;
      double tp = bid - TakeProfitPoints * _Point;

      if(trade.Sell(FixedLot, _Symbol, bid, sl, tp, "Aggressive Sell"))
        {
         lastTradeCandleTime = currentCandleTime;
         Print("Sell Order Opened. Ticket: ", trade.ResultOrder());
        }
     }
  }
//+------------------------------------------------------------------+
//| Helper: Manage Trailing Stop                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP); // Not used for trailing but good to know
      long type = PositionGetInteger(POSITION_TYPE);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(type == POSITION_TYPE_BUY)
        {
         double profitPoints = (currentPrice - openPrice) / point;
         
         // Move to BE
         if(profitPoints >= TrailingStart)
           {
            double newSL = openPrice + TrailingStep * point; // Actually, user said "Move SL to Break Even" first.
            // Let's interpret: If profit > 50, SL = OpenPrice.
            // Then if profit increases, trail.
            
            // Standard Trailing Logic:
            // If Price > Open + TrailingStart, NewSL = Price - TrailingStart?
            // User said: "If profit > 50 points, move SL to Break Even."
            // "Trailing Step: 20 points."
            
            // Implementation:
            // 1. Break Even Trigger:
            if(currentSL < openPrice && profitPoints >= TrailingStart)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
               continue;
              }
            
            // 2. Trailing Step (Once at BE or better)
            if(currentSL >= openPrice)
              {
               double proposedSL = currentPrice - TrailingStart * point; // Keep distance
               // But user said "Trailing Step: 20 points". Usually means update only if change > 20 points.
               // Or does it mean "Trail by keeping 20 points distance"?
               // "Trailing Step" usually means "Update frequency/granularity".
               // Let's assume: Keep SL at (CurrentPrice - TrailingStart). Update if (ProposedSL - CurrentSL) > TrailingStep.
               
               if(proposedSL > currentSL + TrailingStep * point)
                 {
                  trade.PositionModify(ticket, proposedSL, currentTP);
                 }
              }
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double profitPoints = (openPrice - currentPrice) / point;
         
         // Move to BE
         if(profitPoints >= TrailingStart)
           {
            if(currentSL > openPrice && currentSL != 0) // SL is above Open (loss side) or not set
              {
               trade.PositionModify(ticket, openPrice, currentTP);
               continue;
              }
              
            // Trailing
            if(currentSL <= openPrice && currentSL != 0)
              {
               double proposedSL = currentPrice + TrailingStart * point;
               
               if(currentSL == 0 || proposedSL < currentSL - TrailingStep * point)
                 {
                  trade.PositionModify(ticket, proposedSL, currentTP);
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
