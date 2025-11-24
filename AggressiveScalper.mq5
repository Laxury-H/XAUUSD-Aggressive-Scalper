//+------------------------------------------------------------------+
//|                                         Aggressive_Scalper_V2.mq5 |
//|                                  Copyright 2024, Google Deepmind |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Google Deepmind"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input double   FixedLot          = 0.5;      // Khoi luong lenh (Lot)
input int      StopLossPoints    = 300;      // Cat lo (Points)
input int      TakeProfitPoints  = 150;      // Chot loi (Points)
input int      MaxPositions      = 3;        // So lenh toi da cung luc
input int      TrailingStart     = 50;       // Bat dau doi SL khi lai (Points)
input int      TrailingStep      = 20;       // Buoc nhay doi SL (Points)
input int      MaxSpreadPoints   = 100;      // GIOI HAN SPREAD (Da tang len 100)
input int      MagicNumber       = 123456;   // Ma dinh danh Bot

//--- Global variables
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
   trade.SetDeviationInPoints(10);

   // Cai dat Stochastic (5,3,3) - Fast Scalping
   stochHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   if(stochHandle == INVALID_HANDLE)
     {
      Print("Loi: Khong tao duoc chi bao Stochastic");
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
   Comment(""); // Xoa man hinh hien thi khi tat bot
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- 1. CAP NHAT DASHBOARD & DATA ---
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Lay du lieu Stochastic de hien thi
   double main[], signal[];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);
   
   if(CopyBuffer(stochHandle, 0, 0, 2, main) < 2 || CopyBuffer(stochHandle, 1, 0, 2, signal) < 2) return;

   double main0 = main[0];   // Stoch Hien tai
   double signal0 = signal[0];
   double main1 = main[1];   // Stoch Nen truoc
   double signal1 = signal[1];

   // VE MAN HINH THEO DOI (Goc trai tren)
   string text = "=== AGGRESSIVE SCALPER DASHBOARD ===\n";
   text += "Tai khoan: STANDARD | Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "--------------------------------------\n";
   text += "Spread hien tai: " + IntegerToString(spread) + " (Max: " + IntegerToString(MaxSpreadPoints) + ")\n";
   
   if(spread > MaxSpreadPoints) text += "TRANG THAI: [TAM DUNG] Spread qua cao!\n";
   else text += "TRANG THAI: [SAN SANG BAN]\n";
   
   text += "--------------------------------------\n";
   text += "Stoch Main: " + DoubleToString(main0, 2) + "\n";
   text += "Stoch Signal: " + DoubleToString(signal0, 2) + "\n";
   
   // Hien thi tin hieu Mua/Ban tiem nang
   if (main0 < 20) text += "VUNG: Qua Ban (Cho MUA...)\n";
   else if (main0 > 80) text += "VUNG: Qua Mua (Cho BAN...)\n";
   else text += "VUNG: Giua (Cho doi)\n";

   Comment(text); // In ra man hinh

   // --- 2. KIEM TRA DIEU KIEN VAO LENH ---
   
   // Neu Spread cao qua thi khong vao lenh
   if(spread > MaxSpreadPoints) return;

   // Quan ly Trailing Stop (Doi SL)
   ManageTrailingStop();

   // Neu da du so lenh toi da thi thoi
   if(PositionsTotal() >= MaxPositions) return;

   // Moi nen M1 chi vao 1 lenh (Chong spam)
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentCandleTime == lastTradeCandleTime) return;

   // --- 3. LOGIC GIAO DICH ---
   // MUA: Cat len o vung duoi 20
   bool buySignal = (main1 < signal1) && (main0 > signal0) && (main0 < 20);
   
   // BAN: Cat xuong o vung tren 80
   bool sellSignal = (main1 > signal1) && (main0 < signal0) && (main0 > 80);

   // --- 4. THUC THI LENH ---
   if(buySignal)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - StopLossPoints * _Point;
      double tp = ask + TakeProfitPoints * _Point;
      
      if(trade.Buy(FixedLot, _Symbol, ask, sl, tp, "Aggressive Buy"))
        {
         lastTradeCandleTime = currentCandleTime; // Danh dau nen nay da trade
         Print("DA MUA! Ticket: ", trade.ResultOrder());
        }
     }
   else if(sellSignal)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + StopLossPoints * _Point;
      double tp = bid - TakeProfitPoints * _Point;

      if(trade.Sell(FixedLot, _Symbol, bid, sl, tp, "Aggressive Sell"))
        {
         lastTradeCandleTime = currentCandleTime; // Danh dau nen nay da trade
         Print("DA BAN! Ticket: ", trade.ResultOrder());
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Quan ly Trailing Stop (Doi SL)                           |
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
         
         // Neu lai > 50 point -> Doi SL ve Hoa Von (Open Price)
         if(profitPoints >= TrailingStart)
           {
            // Neu SL chua dời hoặc thấp hơn giá vào lệnh
            if(currentSL < openPrice)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            // Neu da Hoa Von, tiep tuc dời SL duoi chan gia (Trailing)
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
            // Doi SL ve Hoa Von
            if(currentSL > openPrice && currentSL != 0)
              {
               trade.PositionModify(ticket, openPrice, currentTP);
              }
            // Trailing
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