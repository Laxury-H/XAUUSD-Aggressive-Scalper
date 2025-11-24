//+------------------------------------------------------------------+
//|                                           QuantumMathAI_V5.mq5   |
//|                        Copyright 2024, Quantum Math AI Team      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Quantum Math AI Team"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "--- Quantum Math Core ---"
input int      InpLRPeriod       = 50;       // Linear Regression Period
input double   InpSlopeThreshold = 0.2;      // Trend Slope Threshold (+/-)
input double   InpRSquaredMin    = 0.7;      // Min R-Squared Quality (0.0 - 1.0)
input double   InpChannelDev     = 2.0;      // Channel Deviation (StdDev)

input group "--- Risk Management ---"
input double   InpRiskPercent    = 1.0;      // Risk Percent per Trade
input double   InpFixedLot       = 0.01;     // Fallback Fixed Lot
input int      InpATRPeriod      = 14;       // ATR Period for SL
input double   InpATRMulti       = 2.0;      // ATR Multiplier for SL

input group "--- Trade Management ---"
input bool     InpUsePartial     = true;     // Use Partial Close at TP1
input double   InpPartialPct     = 50.0;     // Partial Close Percent %
input bool     InpUseTrailing    = true;     // Use Trailing Stop after TP1

input group "--- Time & Filters ---"
input int      InpStartHour      = 8;        // Start Trading Hour
input int      InpEndHour        = 20;       // End Trading Hour
input int      InpMaxSpread      = 100;      // Max Spread (Points)
input int      InpMagic          = 88888;    // Magic Number

//--- Global Objects
CTrade         trade;
int            handleATR;
double         atrBuffer[];

//+------------------------------------------------------------------+
//| Class: CLinearRegression                                         |
//| Purpose: Handles all Math calculations                           |
//+------------------------------------------------------------------+
class CLinearRegression
  {
private:
   int            m_period;
   double         m_slope;
   double         m_intercept;
   double         m_r_squared;
   double         m_std_dev;
   double         m_prices[];

public:
   void Init(int period) { m_period = period; ArrayResize(m_prices, period); }

   void Calculate(const double &close_prices[])
     {
      int n = m_period;
      if(ArraySize(close_prices) < n) return;

      // Copy latest prices
      for(int i=0; i<n; i++) m_prices[i] = close_prices[i]; // 0 is newest

      double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;

      // X is index (0 to n-1), Y is Price
      // We reverse index for calculation so 0 is oldest in the window for standard regression formula
      // But for channel drawing usually 0 is current. Let's stick to: x=0 is current candle, x=1 is previous.
      // Actually standard formula usually treats time as increasing X.
      // Let's use x = 0, 1, 2... n-1 where n-1 is the most recent candle (index 0 in array reversed)
      // To simplify: Array index 0 is Current Price. Let's map x=0 to Array[n-1] (Oldest), x=n-1 to Array[0] (Newest)
      
      for(int i=0; i<n; i++)
        {
         double y = m_prices[n-1-i]; // Reverse: Oldest first
         double x = i;
         
         sum_x += x;
         sum_y += y;
         sum_xy += (x * y);
         sum_x2 += (x * x);
         sum_y2 += (y * y);
        }

      double denominator = (n * sum_x2 - sum_x * sum_x);
      if(denominator == 0) return;

      m_slope = (n * sum_xy - sum_x * sum_y) / denominator;
      m_intercept = (sum_y - m_slope * sum_x) / n;

      // R-Squared Calculation
      // R2 = (n*sum_xy - sum_x*sum_y)^2 / ((n*sum_x2 - sum_x^2) * (n*sum_y2 - sum_y^2))
      double term1 = (n * sum_xy - sum_x * sum_y);
      double term2 = (n * sum_x2 - sum_x * sum_x);
      double term3 = (n * sum_y2 - sum_y * sum_y);
      
      if(term2 * term3 != 0)
         m_r_squared = (term1 * term1) / (term2 * term3);
      else
         m_r_squared = 0;

      // Standard Deviation of Residuals
      double sum_residuals_sq = 0;
      for(int i=0; i<n; i++)
        {
         double y = m_prices[n-1-i];
         double x = i;
         double predicted = m_slope * x + m_intercept;
         double residual = y - predicted;
         sum_residuals_sq += (residual * residual);
        }
      
      m_std_dev = MathSqrt(sum_residuals_sq / (n - 1)); // Sample StdDev
     }

   double GetSlope() { return m_slope; }
   double GetRSquared() { return m_r_squared; }
   double GetStdDev() { return m_std_dev; }
   
   // Get Predicted Price for a specific bar index (0 = current)
   // In our calc, x=n-1 corresponds to index 0. x=n-1-k corresponds to index k.
   double GetRegressionPrice(int index)
     {
      double x = m_period - 1 - index;
      return m_slope * x + m_intercept;
     }
     
   double GetUpperChannel(int index, double dev_mult)
     {
      return GetRegressionPrice(index) + (m_std_dev * dev_mult);
     }
     
   double GetLowerChannel(int index, double dev_mult)
     {
      return GetRegressionPrice(index) - (m_std_dev * dev_mult);
     }
  };

//+------------------------------------------------------------------+
//| Class: CRiskManager                                              |
//+------------------------------------------------------------------+
class CRiskManager
  {
public:
   double CalculateLotSize(double sl_points)
     {
      if(sl_points <= 0) return InpFixedLot;
      
      double risk_amount = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent / 100.0);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tick_value == 0 || tick_size == 0) return InpFixedLot;
      
      double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double lot = risk_amount / (sl_points / tick_size * tick_value);
      
      // Normalize
      lot = MathFloor(lot / lot_step) * lot_step;
      
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(lot < min_lot) lot = min_lot; // Or 0 to skip
      if(lot > max_lot) lot = max_lot;
      
      return lot;
     }
  };

//+------------------------------------------------------------------+
//| Class: CDashboard                                                |
//+------------------------------------------------------------------+
class CDashboard
  {
public:
   void Update(double r2, double slope, double atr, double pnl)
     {
      string text = "=== Quantum Math AI V5.0 ===\n";
      text += "R-Squared: " + DoubleToString(r2, 4) + (r2 > InpRSquaredMin ? " [OK]" : " [WEAK]") + "\n";
      text += "Slope: " + DoubleToString(slope, 5) + "\n";
      text += "ATR: " + DoubleToString(atr, 5) + "\n";
      text += "Daily PnL: " + DoubleToString(pnl, 2) + "\n";
      text += "Session: " + (IsSessionOpen() ? "OPEN" : "CLOSED");
      
      Comment(text);
     }
     
   bool IsSessionOpen()
     {
      MqlDateTime dt;
      TimeCurrent(dt);
      return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
     }
  };

//--- Global Instances
CLinearRegression LR;
CRiskManager      Risk;
CDashboard       Dash;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   
   LR.Init(InpLRPeriod);
   
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(handleATR == INVALID_HANDLE) return INIT_FAILED;
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   IndicatorRelease(handleATR);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Data Gathering
   double close_prices[];
   ArraySetAsSeries(close_prices, true);
   if(CopyClose(_Symbol, _Period, 0, InpLRPeriod, close_prices) < InpLRPeriod) return;
   
   double atr_val[];
   ArraySetAsSeries(atr_val, true);
   if(CopyBuffer(handleATR, 0, 0, 1, atr_val) < 1) return;
   double current_atr = atr_val[0];

   // 2. Math Calculation
   LR.Calculate(close_prices);
   double r2 = LR.GetRSquared();
   double slope = LR.GetSlope();
   
   // 3. Dashboard Update
   Dash.Update(r2, slope, current_atr, GetDailyProfit());
   
   // 4. Trade Management (Partial Close / Trailing)
   ManageOpenTrades();

   // 5. Entry Logic
   if(!Dash.IsSessionOpen()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;
   if(PositionsTotal() > 0) return; // One trade at a time per magic

   // Check R-Squared Filter
   if(r2 < InpRSquaredMin) return;

   // Prices
   double close0 = iClose(_Symbol, _Period, 0); // Current Candle (forming)
   double close1 = iClose(_Symbol, _Period, 1); // Previous Candle (closed)
   double low1   = iLow(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol, _Period, 1);
   
   // Channel Levels for Previous Candle (1)
   double upper1 = LR.GetUpperChannel(1, InpChannelDev);
   double lower1 = LR.GetLowerChannel(1, InpChannelDev);
   double mid1   = LR.GetRegressionPrice(1);

   // BUY SIGNAL
   // 1. Slope > Threshold
   // 2. Price dipped below Lower Channel
   // 3. Price closed back inside (Rejection)
   if(slope > InpSlopeThreshold)
     {
      if(low1 <= lower1 && close1 > lower1)
        {
         double sl_dist = current_atr * InpATRMulti;
         double sl = close1 - sl_dist; // SL below entry
         double tp1 = mid1; // Mean Reversion
         double tp2 = upper1; // Target
         
         // Since we can only set one TP, we set TP2 and manage TP1 virtually
         double lot = Risk.CalculateLotSize(close1 - sl);
         
         trade.Buy(lot, _Symbol, 0, sl, tp2, "Quantum Buy");
        }
     }
     
   // SELL SIGNAL
   if(slope < -InpSlopeThreshold)
     {
      if(high1 >= upper1 && close1 < upper1)
        {
         double sl_dist = current_atr * InpATRMulti;
         double sl = close1 + sl_dist;
         double tp1 = mid1;
         double tp2 = lower1;
         
         double lot = Risk.CalculateLotSize(sl - close1);
         
         trade.Sell(lot, _Symbol, 0, sl, tp2, "Quantum Sell");
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Manage Open Trades                                       |
//+------------------------------------------------------------------+
void ManageOpenTrades()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      
      // Calculate Dynamic TP1 (Mean Reversion Line)
      // We use current regression line
      double mid_line = LR.GetRegressionPrice(0);
      
      // Partial Close Logic
      // Check if we already partially closed? (Hard to track without comments/magic modification)
      // Simple check: if volume is original? No, let's use price proximity.
      
      // Note: For robust partial close, we usually check if price >= TP1.
      // To avoid multiple partial closes, we can check if SL is already at BE.
      
      bool is_be = false;
      if(type == POSITION_TYPE_BUY)
         is_be = (sl >= open_price);
      else
         is_be = (sl <= open_price);
         
      if(InpUsePartial && !is_be)
        {
         if(type == POSITION_TYPE_BUY && current_price >= mid_line)
           {
            // Close 50%
            double close_vol = NormalizeVolume(vol * (InpPartialPct / 100.0));
            if(close_vol > 0)
              {
               trade.PositionClosePartial(ticket, close_vol);
               // Move SL to BE
               trade.PositionModify(ticket, open_price, tp);
              }
           }
         else if(type == POSITION_TYPE_SELL && current_price <= mid_line)
           {
            double close_vol = NormalizeVolume(vol * (InpPartialPct / 100.0));
            if(close_vol > 0)
              {
               trade.PositionClosePartial(ticket, close_vol);
               trade.PositionModify(ticket, open_price, tp);
              }
           }
        }
        
      // Trailing Stop (Only if BE is triggered or simple trailing)
      // Let's implement simple trailing for the runner
      if(InpUseTrailing && is_be)
        {
         // Trail by ATR
         double atr_val[];
         CopyBuffer(handleATR, 0, 0, 1, atr_val);
         double trail_dist = atr_val[0] * 1.5; // Tighter trail for runner
         
         if(type == POSITION_TYPE_BUY)
           {
            double new_sl = current_price - trail_dist;
            if(new_sl > sl && new_sl > open_price)
               trade.PositionModify(ticket, new_sl, tp);
           }
         else if(type == POSITION_TYPE_SELL)
           {
            double new_sl = current_price + trail_dist;
            if(new_sl < sl && new_sl < open_price)
               trade.PositionModify(ticket, new_sl, tp);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Normalize Volume                                         |
//+------------------------------------------------------------------+
double NormalizeVolume(double vol)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double norm = MathFloor(vol / step) * step;
   if(norm < min) return 0;
   return norm;
  }

//+------------------------------------------------------------------+
//| Helper: Get Daily Profit                                         |
//+------------------------------------------------------------------+
double GetDailyProfit()
  {
   double profit = 0;
   HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   for(int i=0; i<HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagic)
         profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }
   return profit;
  }
//+------------------------------------------------------------------+
