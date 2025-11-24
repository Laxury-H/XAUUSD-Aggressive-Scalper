//+------------------------------------------------------------------+
//|                                     QuantumMathAI_V5_Final.mq5   |
//|                   INSTITUTIONAL GRADE - LINEAR REGRESSION SYSTEM |
//|                         Copyright 2024, Google Deepmind          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Google Deepmind"
#property version   "5.01" // Final Optimized Version
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group "--- 1. Quantum Math Settings ---"
input int      LRC_Period        = 50;       // Linear Regression Lookback Period
input double   Slope_Threshold   = 0.2;      // Min Slope to confirm Trend
input double   R_Squared_Min     = 0.7;      // Min R-Squared (Trend Quality) [0.0 - 1.0]

input group "--- 2. Risk Management (ATR Based) ---"
input double   RiskPercent       = 1.0;      // Risk % per Trade (0 = Use Fixed Lot)
input double   FixedLot          = 0.1;      // Fallback Fixed Lot
input int      ATR_Period        = 14;       // ATR Period for Volatility
input double   ATR_Multiplier_SL = 2.0;      // SL Distance = ATR * Multiplier

input group "--- 3. Filters & Time ---"
input int      MaxSpreadPoints   = 100;      // Max Spread Allowed
input int      StartHour         = 8;        // Trading Start Hour (Server Time)
input int      EndHour           = 20;       // Trading End Hour (Server Time)

input group "--- 4. System ---"
input int      MagicNumber       = 55555;    // Magic Number

//--- GLOBAL OBJECTS & VARIABLES
CTrade         trade;
int            atrHandle;
datetime       lastBarTime = 0;

// Struct to hold Regression Results
struct RegressionResult {
   double slope;
   double intercept;
   double rSquared;
   double stdDev;
   double centerLine;
   double upperChannel;
   double lowerChannel;
};

//--- VISUAL OBJECT NAMES
string ObjPrefix = "QMAI_V5_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetDeviationInPoints(20);

   // Initialize ATR Indicator
   atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error: Failed to create ATR handle");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(atrHandle);
   ObjectsDeleteAll(0, ObjPrefix); // Clean up visuals
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. INITIAL CHECKS
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPoints) return;
   
   // Math Calculations (Need this for management too)
   RegressionResult math = CalculateRegression(LRC_Period);
   double currentATR = GetCurrentATR();
   
   // 3. VISUALIZATION & DASHBOARD
   DrawChannel(math);
   UpdateDashboard(math, currentATR);
   
   // Manage Open Trades (Partial Close & Trailing)
   // Move BEFORE entry logic to secure profits first
   ManagePositions(math);

   // 4. ENTRY LOGIC (ON NEW BAR ONLY & TIME FILTER)
   if(!CheckTimeFilter()) return; 
   if(!isNewBar()) return;
   if(PositionsTotal() >= 1) return; // One trade at a time focus

   double close = iClose(_Symbol, _Period, 1); // Closed candle
   double low   = iLow(_Symbol, _Period, 1);
   double high  = iHigh(_Symbol, _Period, 1);

   // --- BUY SIGNAL ---
   if(math.slope > Slope_Threshold && math.rSquared >= R_Squared_Min)
     {
      // Re-calc channel at index 1 for accurate signal
      double lowerCh1 = (math.slope * (-1) + math.intercept) - (2.0 * math.stdDev);
      
      if(low <= lowerCh1 && close > lowerCh1) 
        {
         OpenTrade(ORDER_TYPE_BUY, currentATR, math);
        }
     }

   // --- SELL SIGNAL ---
   else if(math.slope < -Slope_Threshold && math.rSquared >= R_Squared_Min)
     {
      double upperCh1 = (math.slope * (-1) + math.intercept) + (2.0 * math.stdDev);
      
      if(high >= upperCh1 && close < upperCh1)
        {
         OpenTrade(ORDER_TYPE_SELL, currentATR, math);
        }
     }
  }

//+------------------------------------------------------------------+
//| MATH CORE: Linear Regression & R-Squared                         |
//+------------------------------------------------------------------+
RegressionResult CalculateRegression(int n)
  {
   RegressionResult res;
   ZeroMemory(res); // Init with 0
   
   double sumX=0, sumY=0, sumXY=0, sumX2=0, sumY2=0;
   double prices[];
   
   // Use CopyClose instead of iClose loop for speed
   if(CopyClose(_Symbol, _Period, 0, n, prices) < n) return res;
   
   // Note: CopyClose returns prices[0] as Oldest, prices[n-1] as Newest (Default)
   // We need to map index 0 to Newest for our logic.
   // Let's reverse loop: i=0 is newest (prices[n-1]), i=n-1 is oldest (prices[0])
   
   for(int i=0; i<n; i++)
     {
      double price = prices[n-1-i]; // 0 is newest
      double x = -i; // Time index (0, -1, -2...)
      
      sumX  += x;
      sumY  += price;
      sumXY += (x * price);
      sumX2 += (x * x);
      sumY2 += (price * price);
     }
   
   double denominator = (n * sumX2 - sumX * sumX);
   if(denominator == 0) return res;
   
   res.slope = (n * sumXY - sumX * sumY) / denominator;
   res.intercept = (sumY - res.slope * sumX) / n;
   
   // R-Squared
   double num_r = (n * sumXY - sumX * sumY);
   double den_r = ((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
   if (den_r > 0) res.rSquared = (num_r * num_r) / den_r;
   
   // StdDev
   double sumSqDiff = 0;
   for(int i=0; i<n; i++)
     {
      double price = prices[n-1-i];
      double regVal = res.slope * (-i) + res.intercept;
      sumSqDiff += MathPow(price - regVal, 2);
     }
   res.stdDev = MathSqrt(sumSqDiff / n);
   
   // Current Values (x=0)
   res.centerLine   = res.intercept; 
   res.upperChannel = res.centerLine + (2.0 * res.stdDev);
   res.lowerChannel = res.centerLine - (2.0 * res.stdDev);
   
   return res;
  }

//+------------------------------------------------------------------+
//| TRADE EXECUTION: Dynamic Lots & ATR Exits                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atr, RegressionResult &math)
  {
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = atr * ATR_Multiplier_SL;
   if (slDist < 100 * _Point) slDist = 100 * _Point; // Min SL Safety
   
   double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   double tp = (type == ORDER_TYPE_BUY) ? math.upperChannel : math.lowerChannel; // Aim for opposite band
   
   // Dynamic Lot
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = (RiskPercent > 0) ? balance * RiskPercent / 100.0 : 0;
   double lot = FixedLot;
   
   if(RiskPercent > 0 && slDist > 0)
     {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickValue > 0) lot = riskMoney / ((slDist / _Point) * tickValue);
     }
     
   // Normalize
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   if(type == ORDER_TYPE_BUY) trade.Buy(lot, _Symbol, price, sl, tp, "QMAI-V5 Buy");
   else trade.Sell(lot, _Symbol, price, sl, tp, "QMAI-V5 Sell");
  }

//+------------------------------------------------------------------+
//| TRADE MANAGER: Partial Close & Trailing                          |
//+------------------------------------------------------------------+
void ManagePositions(RegressionResult &math)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Use Bid/Ask for accurate trigger
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // 1. PARTIAL CLOSE LOGIC (At Mean Reversion Line)
      if(StringFind(comment, "Partial") < 0 && vol > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
         bool hitTarget = false;
         if(type == POSITION_TYPE_BUY && currentPrice >= math.centerLine) hitTarget = true;
         if(type == POSITION_TYPE_SELL && currentPrice <= math.centerLine) hitTarget = true;
         
         if(hitTarget)
           {
            // Close 50%
            double closeVol = NormalizeDouble(vol * 0.5, 2);
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            closeVol = MathFloor(closeVol/step) * step;
            
            if(closeVol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
              {
               trade.PositionClosePartial(ticket, closeVol);
               Print(">>> V5: Partial Close 50% at Mean Reversion");
              }
              
            // Move SL to Break Even
            trade.PositionModify(ticket, openPrice, tp);
           }
        }
        
      // 2. TRAILING STOP (Simple Pips Trailing after BE)
      bool is_be = (type == POSITION_TYPE_BUY) ? (sl >= openPrice) : (sl <= openPrice && sl > 0);
      
      if(is_be)
        {
         double point = _Point;
         if(type == POSITION_TYPE_BUY)
           {
            if(currentPrice - openPrice > 500 * point) // If profit > 50 pips
              {
               double newSL = currentPrice - 200 * point; // Keep 20 pips distance
               if(newSL > sl) trade.PositionModify(ticket, newSL, tp);
              }
           }
         else if(type == POSITION_TYPE_SELL)
           {
            if(openPrice - currentPrice > 500 * point)
              {
               double newSL = currentPrice + 200 * point;
               if(sl == 0 || newSL < sl) trade.PositionModify(ticket, newSL, tp);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| UTILS: Dashboard & Visuals                                       |
//+------------------------------------------------------------------+
void UpdateDashboard(RegressionResult &m, double atr)
  {
   string text = "=== ⚛️ QUANTUM MATH V5.0 (FINAL) ⚛️ ===\n";
   text += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "----------------------------------------\n";
   
   string r2Text = DoubleToString(m.rSquared, 4);
   if(m.rSquared >= R_Squared_Min) r2Text += " ✅ (Strong)";
   else r2Text += " ⚠️ (Weak)";
   
   text += "R-Squared: " + r2Text + "\n";
   text += "Slope: " + DoubleToString(m.slope, 5) + "\n";
   text += "Volatility (ATR): " + DoubleToString(atr / _Point, 0) + " pts\n";
   
   if(CheckTimeFilter()) text += "Session: OPEN 🟢\n";
   else text += "Session: CLOSED 🔴\n";
   
   Comment(text);
  }

void DrawChannel(RegressionResult &m)
  {
   DrawLine(ObjPrefix+"Center", m.centerLine, clrGold, 2);
   DrawLine(ObjPrefix+"Upper", m.upperChannel, clrRed, 1, STYLE_DOT);
   DrawLine(ObjPrefix+"Lower", m.lowerChannel, clrLime, 1, STYLE_DOT);
   ChartRedraw();
  }

void DrawLine(string name, double price, color col, int width, ENUM_LINE_STYLE style=STYLE_SOLID)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectMove(0, name, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
  }

double GetCurrentATR()
  {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return 0;
   return atr[0];
  }

bool CheckTimeFilter()
  {
   datetime time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(time, dt);
   if(dt.hour >= StartHour && dt.hour < EndHour) return true;
   return false;
  }

bool isNewBar()
  {
   if(lastBarTime != iTime(_Symbol, _Period, 0)) {
      lastBarTime = iTime(_Symbol, _Period, 0);
      return true;
   }
   return false;
  }