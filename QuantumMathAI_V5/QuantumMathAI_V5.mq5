//+------------------------------------------------------------------+
//|                                   QuantumMathAI_V6_Guardian.mq5  |
//|               INSTITUTIONAL GRADE - LINEAR REGRESSION SYSTEM     |
//|                   UPDATED FOR GOLD $4000+ (NOV 2025)             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Project Quantum"
#property version   "6.01" // Auto-News Integrated
#property strict
#property description "Quantum Math AI with Auto-News Filter (ForexFactory)"

#include <Trade\Trade.mqh>

//==================================================================
// 1. INPUT PARAMETERS
//==================================================================
input group "--- 1. Quantum Math Settings ---"
input int      LRC_Period        = 50;     // Linear Regression Lookback Period
input double   Slope_Threshold   = 0.2;    // Min Slope to confirm Trend
input double   R_Squared_Min     = 0.7;    // Min R-Squared (Trend Quality) [0.0-1.0]

input group "--- 2. Risk Management ($4k Adapted) ---"
input double   RiskPercent       = 1.0;    // Risk % per Trade (0 = Use Fixed Lot)
input double   FixedLot          = 0.1;    // Fallback Fixed Lot
input int      ATR_Period        = 14;     // ATR Period
input double   ATR_Multiplier_SL = 3.0;    // [IMPORTANT] SL Distance = ATR * 3.0 (Widened for $4k)
input double   ATR_Multiplier_TP = 4.0;    // Target Profit = ATR * 4.0

input group "--- 3. Auto News Filter (ForexFactory) ---"
input bool     UseAutoNews       = true;   // Enable Auto-Calendar Fetching
input bool     IncludeMedium     = false;  // If true, pause on 'Medium' impact too. False = 'High' only.
input int      PauseMinsBefore   = 30;     // Minutes to pause BEFORE news
input int      PauseMinsAfter    = 30;     // Minutes to pause AFTER news
input int      ServerTimeOffset  = 2;      // Your Broker Timezone Offset from UTC (e.g., UTC+2)

input group "--- 4. Filters & Time ---"
input int      MaxSpreadPoints   = 150;    // Max Spread Allowed (150 pts = $1.5)
input int      StartHour         = 8;      // Trading Start Hour (Server Time)
input int      EndHour           = 22;     // Trading End Hour (Server Time)

input group "--- 5. System ---"
input int      MagicNumber       = 66666;  // Unique Magic Number

//==================================================================
// 2. GLOBAL STRUCTURES & VARIABLES
//==================================================================
CTrade trade;
int atrHandle;
datetime lastBarTime = 0;
datetime lastNewsFetchTime = 0;

// Struct for Linear Regression Results
struct RegressionResult {
   double slope;
   double intercept;
   double rSquared;
   double stdDev;
   double centerLine;
   double upperChannel;
   double lowerChannel;
};

// Struct for News Events
struct NewsEvent {
   datetime time;
   string   title;
   string   impact;
   string   currency;
};

NewsEvent WeeklyNews[]; // Array to store fetched news

// Visual Objects Prefix
string ObjPrefix = "QMAI_V6_";

//==================================================================
// 3. INITIALIZATION
//==================================================================
int OnInit() {
   // Setup Trade Object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetDeviationInPoints(30); // Slippage tolerance

   // Initialize ATR Indicator
   atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error: Failed to create ATR handle");
      return(INIT_FAILED);
   }
   
   // Check WebRequest permission (Informational only)
   if(UseAutoNews && !TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
      Print("NOTE: Ensure 'Allow WebRequest' is enabled for Auto-News to work.");
   }

   Print(">>> QuantumMathAI V6.0 INITIALIZED (Target: XAUUSD $4000+)");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(atrHandle);
   ObjectsDeleteAll(0, ObjPrefix);
   Comment("");
}

//==================================================================
// 4. MAIN TICK LOOP
//==================================================================
void OnTick() {
   // --- A. DASHBOARD & DATA UPDATE ---
   // 1. Get Math Data
   RegressionResult math = CalculateRegression(LRC_Period);
   double currentATR = GetCurrentATR();
   
   // 2. Update Visuals
   DrawChannel(math);
   
   // 3. News Status Check
   bool isNews = CheckNewsFilter();
   
   // 4. Update Dashboard
   UpdateDashboard(math, currentATR, isNews);
   
   // --- B. TRADING LOGIC ---
   
   // 1. Spread Filter
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPoints) return;
   
   // 2. News Filter Block
   if(isNews) return; // STOP here if news is active

   // 3. Trade Management (Trailing & Partial Close)
   ManagePositions(math);

   // 4. Entry Filters (New Bar & Time)
   if(!CheckTimeFilter()) return;
   if(!isNewBar()) return;
   if(PositionsTotal() >= 1) return; // Focus on 1 quality trade

   // --- C. ENTRY SIGNALS ---
   double close = iClose(_Symbol, _Period, 1);
   double low   = iLow(_Symbol, _Period, 1);
   double high  = iHigh(_Symbol, _Period, 1);

   // BUY LOGIC
   if(math.slope > Slope_Threshold && math.rSquared >= R_Squared_Min) {
      double lowerCh1 = (math.slope * (-1) + math.intercept) - (2.0 * math.stdDev);
      // Price touches lower channel and closes back inside
      if(low <= lowerCh1 && close > lowerCh1) {
         OpenTrade(ORDER_TYPE_BUY, currentATR, math);
      }
   }

   // SELL LOGIC
   else if(math.slope < -Slope_Threshold && math.rSquared >= R_Squared_Min) {
      double upperCh1 = (math.slope * (-1) + math.intercept) + (2.0 * math.stdDev);
      // Price touches upper channel and closes back inside
      if(high >= upperCh1 && close < upperCh1) {
         OpenTrade(ORDER_TYPE_SELL, currentATR, math);
      }
   }
}

//==================================================================
// 5. MATH CORE FUNCTIONS
//==================================================================
RegressionResult CalculateRegression(int n) {
   RegressionResult res;
   ZeroMemory(res);
   
   double sumX=0, sumY=0, sumXY=0, sumX2=0, sumY2=0;
   double prices[];
   
   if(CopyClose(_Symbol, _Period, 0, n, prices) < n) return res;
   
   for(int i=0; i<n; i++) {
      double price = prices[n-1-i]; // 0 is newest
      double x = -i;
      
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
   for(int i=0; i<n; i++) {
      double price = prices[n-1-i];
      double regVal = res.slope * (-i) + res.intercept;
      sumSqDiff += MathPow(price - regVal, 2);
   }
   res.stdDev = MathSqrt(sumSqDiff / n);
   
   // Current Channel Values
   res.centerLine   = res.intercept;
   res.upperChannel = res.centerLine + (2.0 * res.stdDev);
   res.lowerChannel = res.centerLine - (2.0 * res.stdDev);
   
   return res;
}

//==================================================================
// 6. AUTO NEWS FILTER LOGIC (WEB REQUEST)
//==================================================================
bool CheckNewsFilter() {
   if(!UseAutoNews) return false;
   
   // Update news data every 4 hours or if empty
   if(TimeCurrent() - lastNewsFetchTime > 14400 || ArraySize(WeeklyNews) == 0) {
      FetchNewsData();
   }
   
   datetime now = TimeCurrent();
   
   for(int i=0; i<ArraySize(WeeklyNews); i++) {
      // Filter logic: Only USD and High Impact (or Medium if enabled)
      if(WeeklyNews[i].currency != "USD") continue;
      
      bool isHigh   = (StringFind(WeeklyNews[i].impact, "High") >= 0);
      bool isMedium = (StringFind(WeeklyNews[i].impact, "Medium") >= 0);
      
      if(!isHigh && (!IncludeMedium || !isMedium)) continue;
      
      // Time Check
      long diff = (long)now - (long)WeeklyNews[i].time;
      
      // If within [Before, After] window
      if(diff >= -PauseMinsBefore * 60 && diff <= PauseMinsAfter * 60) {
         // Optional: Display alert on dashboard
         return true; // PAUSE TRADING
      }
   }
   return false;
}

void FetchNewsData() {
   string cookie=NULL, headers;
   char post[], result[];
   string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";
   
   int res = WebRequest("GET", url, cookie, NULL, 500, post, 0, result, headers);
   
   if(res == 200) {
      string json = CharArrayToString(result);
      ParseNewsJson(json);
      lastNewsFetchTime = TimeCurrent();
      Print(">>> News Data Fetched Successfully. Total Events: ", ArraySize(WeeklyNews));
   } else {
      Print(">>> Error fetching news. Code: ", res, ". Check 'Allow WebRequest' in Options.");
   }
}

// Simple JSON Parser adapted for ForexFactory structure
void ParseNewsJson(string json) {
   ArrayResize(WeeklyNews, 0);
   
   // Split JSON by objects "},{"
   string objects[];
   StringSplit(json, '}', objects); // Crude split
   
   for(int i=0; i<ArraySize(objects); i++) {
      string obj = objects[i];
      
      // We look for "country":"USD" inside this object string
      if(StringFind(obj, "\"country\":\"USD\"") < 0) continue;
      
      // Extract Impact
      string impact = "";
      if(StringFind(obj, "\"impact\":\"High\"") >= 0) impact = "High";
      else if(StringFind(obj, "\"impact\":\"Medium\"") >= 0) impact = "Medium";
      
      if(impact == "") continue; // Skip Low impact
      
      // Extract Date string like "2025-11-24T09:00:00-05:00"
      int dateStart = StringFind(obj, "\"date\":\"");
      if(dateStart < 0) continue;
      
      string dateStr = StringSubstr(obj, dateStart + 8, 19); // Get "2025-11-24T09:00:00"
      StringReplace(dateStr, "T", " "); // Convert to "2025-11-24 09:00:00"
      
      datetime newsTime = StringToTime(dateStr);
      
      // Adjust Timezone (Simple Offset)
      // ForexFactory usually provides time with offset in the string, but StringToTime ignores it often.
      // We assume the time in JSON is roughly UTC-5 (NY) or UTC. 
      // It is safer to manually align via input 'ServerTimeOffset' if needed.
      // For simplicity here, we add ServerTimeOffset hours to the parsed time.
      newsTime = newsTime + (ServerTimeOffset * 3600); 
      
      // Extract Title
      int titleStart = StringFind(obj, "\"title\":\"");
      string title = "News";
      if(titleStart >= 0) {
         int titleEnd = StringFind(obj, "\"", titleStart + 9);
         title = StringSubstr(obj, titleStart + 9, titleEnd - (titleStart + 9));
      }
      
      // Add to Array
      int newIdx = ArrayResize(WeeklyNews, ArraySize(WeeklyNews) + 1);
      WeeklyNews[newIdx-1].time = newsTime;
      WeeklyNews[newIdx-1].impact = impact;
      WeeklyNews[newIdx-1].currency = "USD";
      WeeklyNews[newIdx-1].title = title;
   }
}

//==================================================================
// 7. EXECUTION & MANAGEMENT
//==================================================================
void OpenTrade(ENUM_ORDER_TYPE type, double atr, RegressionResult &math) {
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Dynamic SL Calculation ($4k Adapted)
   double slDist = atr * ATR_Multiplier_SL;
   if (slDist < 200 * _Point) slDist = 200 * _Point; // Min safety SL (20 pips)
   
   double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   
   // Target: Opposite Channel
   double tp = (type == ORDER_TYPE_BUY) ? math.upperChannel : math.lowerChannel;
   
   // Lot Size Calculation
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = FixedLot;
   
   if(RiskPercent > 0 && slDist > 0) {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickValue > 0) lot = (balance * RiskPercent / 100.0) / ((slDist / _Point) * tickValue);
   }
   
   // Normalize Lot
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot/step) * step;
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   
   if(type == ORDER_TYPE_BUY) trade.Buy(lot, _Symbol, price, sl, tp, "QMAI-V6 Buy");
   else trade.Sell(lot, _Symbol, price, sl, tp, "QMAI-V6 Sell");
}

void ManagePositions(RegressionResult &math) {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // 1. Partial Close at Mean Reversion (Center Line)
      if(StringFind(comment, "Partial") < 0 && vol > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
         bool hitTarget = false;
         if(type == POSITION_TYPE_BUY && currentPrice >= math.centerLine) hitTarget = true;
         if(type == POSITION_TYPE_SELL && currentPrice <= math.centerLine) hitTarget = true;
         
         if(hitTarget) {
            double closeVol = NormalizeDouble(vol * 0.5, 2);
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            closeVol = MathFloor(closeVol/step) * step;
            
            if(closeVol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
               trade.PositionClosePartial(ticket, closeVol);
               Print(">>> V6: Partial Close 50% at Mean Reversion");
            }
            // Move SL to Break Even
            trade.PositionModify(ticket, openPrice, tp);
         }
      }
      
      // 2. ATR Trailing Stop (For the remaining position)
      // Logic: Lock profit if price moves significantly
      if(type == POSITION_TYPE_BUY) {
         if(currentPrice > openPrice + (200 * _Point)) { // If profit > 20 pips
             double newSL = currentPrice - (100 * _Point); // Trail 10 pips behind
             if(newSL > sl) trade.PositionModify(ticket, newSL, tp);
         }
      }
      else if(type == POSITION_TYPE_SELL) {
         if(currentPrice < openPrice - (200 * _Point)) {
             double newSL = currentPrice + (100 * _Point);
             if(sl == 0 || newSL < sl) trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//==================================================================
// 8. UTILITIES & VISUALS
//==================================================================
void UpdateDashboard(RegressionResult &m, double atr, bool newsPause) {
   string text = "=== ⚛️ QUANTUM MATH V6.0 (THE GUARDIAN) ⚛️ ===\n";
   text += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "----------------------------------------\n";
   
   // R-Squared Status
   string r2Text = DoubleToString(m.rSquared, 4);
   if(m.rSquared >= R_Squared_Min) r2Text += " ✅ (Tradable)";
   else r2Text += " ⚠️ (Weak Trend)";
   text += "R-Squared: " + r2Text + "\n";
   
   // Volatility
   text += "Volatility (ATR): " + DoubleToString(atr / _Point, 0) + " pts\n";
   
   // Filter Status
   if(newsPause) text += "STATUS: 🛑 PAUSED (NEWS DETECTED)\n";
   else if(!CheckTimeFilter()) text += "STATUS: 💤 SLEEPING (TIME FILTER)\n";
   else text += "STATUS: 🟢 HUNTING...\n";
   
   // News Info
   text += "----------------------------------------\n";
   text += "Auto-News: " + (UseAutoNews ? "ON" : "OFF") + "\n";
   
   Comment(text);
}

void DrawChannel(RegressionResult &m) {
   DrawLine(ObjPrefix+"Center", m.centerLine, clrGold, 2);
   DrawLine(ObjPrefix+"Upper", m.upperChannel, clrRed, 1, STYLE_DOT);
   DrawLine(ObjPrefix+"Lower", m.lowerChannel, clrLime, 1, STYLE_DOT);
   ChartRedraw();
}

void DrawLine(string name, double price, color col, int width, ENUM_LINE_STYLE style=STYLE_SOLID) {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectMove(0, name, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

double GetCurrentATR() {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return 0;
   return atr[0];
}

bool CheckTimeFilter() {
   datetime time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(time, dt);
   if(dt.hour >= StartHour && dt.hour < EndHour) return true;
   return false;
}

bool isNewBar() {
   if(lastBarTime != iTime(_Symbol, _Period, 0)) {
      lastBarTime = iTime(_Symbol, _Period, 0);
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+