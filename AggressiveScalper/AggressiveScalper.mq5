//+------------------------------------------------------------------+
//|                                     Aggressive_Scalper_English.mq5|
//|                                  Copyright 2024, Google Deepmind |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Google Deepmind"
#property link      "https://www.mql5.com"
#property version   "2.10" // Updated to English Version
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input double   FixedLot          = 0.5;      // Fixed Lot Size per Trade
input int      StopLossPoints    = 300;      // Stop Loss (in Points)
input int      TakeProfitPoints  = 150;      // Take Profit (in Points)
input int      MaxPositions      = 3;        // Max Concurrent Positions
input int      TrailingStart     = 50;       // Trailing Start (Points) - Distance to start moving SL
input int      TrailingStep      = 20;       // Trailing Step (Points) - Update frequency
input int      MaxSpreadPoints   = 100;      // Max Allowed Spread (Points)
input int      MagicNumber       = 123456;   // Expert Advisor ID (Magic Number)

//--- Global variables
CTrade         trade;
int            stochHandle;
datetime       lastTradeCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Configure Trade Object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetDeviationInPoints(10); // Max slippage allowed

   // Initialize Stochastic Oscillator (5,3,3) - Settings for Fast Scalping
   stochHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   if(stochHandle == INVALID_HANDLE)
     {
      Print("Error: Failed to create Stochastic indicator handle");
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
   Comment(""); // Clear the dashboard when removing the EA
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- 1. DASHBOARD & DATA UPDATE ---
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Retrieve Stochastic Data
   double main[], signal[];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);
   
   if(CopyBuffer(stochHandle, 0, 0, 2, main) < 2 || CopyBuffer(stochHandle, 1, 0, 2, signal) < 2) return;

   double main0 = main[0];   // Current Stoch Main
   double signal0 = signal[0];
   double main1 = main[1];   // Previous Stoch Main
   double signal1 = signal[1];

   // DRAW DASHBOARD (Top-Left Corner)
   string text = "=== AGGRESSIVE SCALPER DASHBOARD ===\n";
   text += "Account: STANDARD | Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "--------------------------------------\n";
   text += "Current Spread: " + IntegerToString(spread) + " (Max: " + IntegerToString(MaxSpreadPoints) + ")\n";
   
   if(spread > MaxSpreadPoints) text += "STATUS: [PAUSED] Spread too high!\n";
   else text += "STATUS: [READY TO TRADE]\n";
   
   text += "--------------------------------------\n";
   text += "Stoch Main: " + DoubleToString(main0, 2) + "\n";
   text += "Stoch Signal: " + DoubleToString(signal0, 2) + "\n";
   
   // Display Potential Signals zones
   if (main0 < 20) text += "ZONE: OVERSOLD (Waiting for BUY...)\n";
   else if (main0 > 80) text += "ZONE: OVERBOUGHT (Waiting for SELL...)\n";
   else text += "ZONE: Neutral (Waiting)\n";

   Comment(text); // Print dashboard to chart

   // --- 2. ENTRY CONDITIONS ---
   
   // Spread Filter
   if(spread > MaxSpreadPoints) return;

   // Manage Trailing Stop
   ManageTrailingStop();

   // Max Positions Check
   if(PositionsTotal() >= MaxPositions) return;

   // One Trade Per Candle Rule (Anti-Spam)
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentCandleTime == lastTradeCandleTime) return;

   // --- 3. TRADING LOGIC ---
   // BUY SIGNAL: Cross UP in Oversold zone (< 20)
   bool buySignal = (main1 < signal1) && (main0 > signal0) && (main0 < 20);
   
   // SELL SIGNAL: Cross DOWN in Overbought zone (> 80)
   bool sellSignal = (main1 > signal1) && (main0 < signal0) && (main0 > 80);

   // --- 4. EXECUTION ---
   if(buySignal)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - StopLossPoints * _Point;
      double tp = ask + TakeProfitPoints * _Point;
      
      if(trade.Buy(FixedLot, _Symbol, ask, sl, tp, "Aggressive Buy"))
        {
         lastTradeCandleTime = currentCandleTime; // Mark this candle as traded
         Print("BUY ORDER OPENED! Ticket: ", trade.ResultOrder());
        }
     }
   else if(sellSignal)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + StopLossPoints * _Point;
      double tp = bid - TakeProfitPoints * _Point;

      if(trade.Sell(FixedLot, _Symbol, bid, sl, tp, "Aggressive Sell"))
        {
         lastTradeCandleTime = currentCandleTime; // Mark this candle as traded
         Print("SELL ORDER OPENED! Ticket: ", trade.ResultOrder());
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

      // Filter: Only modify positions opened by this specific EA
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
         
         // Logic: Move SL to Break Even if profit > TrailingStart
         if(profitPoints >= TrailingStart)
           {
            // First step: Move SL to Open Price (Break Even)
            if(currentSL < openPrice)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            // Second step: Trail the price
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
            // Move SL to Break Even
            if(currentSL > openPrice && currentSL != 0)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            // Trail the price
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