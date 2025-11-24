//+------------------------------------------------------------------+
//|                        Aggressive_Scalper_NonStop_English.mq5    |
//|                        "NON-STOP MODE" - ENGLISH VISUALS         |
//|                        Copyright 2024, Google Deepmind           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Google Deepmind"
#property link      "https://www.mql5.com"
#property version   "3.50" // Version Non-Stop English
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input double   FixedLot          = 0.5;      // Fixed Lot Size
input int      StopLossPoints    = 300;      // Stop Loss (Points)
input int      TakeProfitPoints  = 150;      // Take Profit (Points)
input int      MaxPositions      = 10;       // Max Concurrent Positions
input int      TrailingStart     = 30;       // Trailing Start (Points)
input int      TrailingStep      = 10;       // Trailing Step (Points)
input int      MaxSpreadPoints   = 200;      // Max Allowed Spread (Points)
input int      MagicNumber       = 999999;   // Magic Number

//--- GLOBAL VARIABLES
CTrade         trade;
int            stochHandle;
datetime       lastTradeCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetDeviationInPoints(20); // Max slippage

   // Initialize Stochastic (5,3,3) - Super Fast Settings
   stochHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   if(stochHandle == INVALID_HANDLE)
     {
      Print("Error: Failed to create Stochastic handle");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(stochHandle);
   Comment(""); // Clear Dashboard
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- 1. GET DATA ---
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   double main[], signal[];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);
   
   if(CopyBuffer(stochHandle, 0, 0, 2, main) < 2 || CopyBuffer(stochHandle, 1, 0, 2, signal) < 2) return;

   double main0 = main[0];   // Current
   double signal0 = signal[0];
   double main1 = main[1];   // Previous
   double signal1 = signal[1];

   // --- 2. DRAW DASHBOARD (VISUALS) ---
   string text = "=== 🔥 AGGRESSIVE SCALPER: NON-STOP MODE 🔥 ===\n";
   text += "Account: STANDARD | Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "-----------------------------------------------\n";
   text += "Current Spread: " + IntegerToString(spread) + " pts (Max: " + IntegerToString(MaxSpreadPoints) + ")\n";
   
   if(spread > MaxSpreadPoints) text += "STATUS: [PAUSED] Spread too high!\n";
   else text += "STATUS: [HUNTING FOR CROSSOVERS...]\n";
   
   text += "-----------------------------------------------\n";
   text += "Stoch Main: " + DoubleToString(main0, 2) + "\n";
   text += "Stoch Signal: " + DoubleToString(signal0, 2) + "\n";
   
   // Display Zone Info (Even though we trade everywhere)
   if (main0 < 20) text += "ZONE: OVERSOLD (High probability BUY)\n";
   else if (main0 > 80) text += "ZONE: OVERBOUGHT (High probability SELL)\n";
   else text += "ZONE: MID-RANGE (Aggressive Trading Active)\n";
   
   text += "Active Positions: " + IntegerToString(PositionsTotal()) + " / " + IntegerToString(MaxPositions) + "\n";

   Comment(text); // Print to Chart

   // --- 3. ENTRY LOGIC (NON-STOP) ---
   
   if(spread > MaxSpreadPoints) return;
   
   ManageTrailingStop();

   if(PositionsTotal() >= MaxPositions) return;

   // Anti-Spam: 1 Trade per Candle
   if(iTime(_Symbol, PERIOD_M1, 0) == lastTradeCandleTime) return;

   // CROSSOVER LOGIC (Anywhere on the chart)
   bool buySignal = (main1 < signal1) && (main0 > signal0); // Cross UP -> BUY
   bool sellSignal = (main1 > signal1) && (main0 < signal0); // Cross DOWN -> SELL
   
   // --- 4. EXECUTION ---
   if(buySignal)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - StopLossPoints * _Point;
      double tp = ask + TakeProfitPoints * _Point;
      
      if(trade.Buy(FixedLot, _Symbol, ask, sl, tp, "NON-STOP BUY"))
        {
         lastTradeCandleTime = iTime(_Symbol, PERIOD_M1, 0);
         Print("NON-STOP BUY ORDER OPENED! Ticket: ", trade.ResultOrder());
         PlaySound("ok.wav"); 
        }
     }
   else if(sellSignal)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + StopLossPoints * _Point;
      double tp = bid - TakeProfitPoints * _Point;

      if(trade.Sell(FixedLot, _Symbol, bid, sl, tp, "NON-STOP SELL"))
        {
         lastTradeCandleTime = iTime(_Symbol, PERIOD_M1, 0);
         Print("NON-STOP SELL ORDER OPENED! Ticket: ", trade.ResultOrder());
         PlaySound("ok.wav");
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
      double currentTP = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(type == POSITION_TYPE_BUY)
        {
         double profitPoints = (currentPrice - openPrice) / point;
         
         if(profitPoints >= TrailingStart)
           {
            if(currentSL < openPrice)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            else if(currentSL >= openPrice)
              {
               double proposedSL = currentPrice - TrailingStart * point;
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
         
         if(profitPoints >= TrailingStart)
           {
            if(currentSL > openPrice && currentSL != 0)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            else if(currentSL <= openPrice && currentSL != 0)
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