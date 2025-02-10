//+------------------------------------------------------------------+
//|                                                 Rhythm Ultra.mq5 |
//|                                                  Algo Industries |
//|                                     https://algoindustries.tech/ |
//+------------------------------------------------------------------+
#property copyright "Algo Industries"
#property link      "https://algoindustries.tech/"
#property version   "1.00"
#property description "\t\t\t\tWelcome to Rhythm Ultra!"
                      "\n\n\tFirst completely automated tool for Price Action trading by Smart Money and ICT concepts!"
                      "\n\n\t\tWe are glad to see you in the family of algorithmic traders."
#property icon "icon.ico"

#include <Defines_Ultra.mqh>

void OnInit()
   {
   if(demoVersion)
      {
      MessageBox("Rhythm Pro cannot be used in Demo mode.", "Demo");
      Print("Rhythm Pro cannot be used in Demo mode.");
      ExpertRemove();
      }
   if(initialized) return;
   if(entry1 == none && entry2 == none && entry3 == none)
      {
      Print("Please, specify at least one entry timeframe.");
      initialized = true; 
      return;
      }
   defineTradeIntervals();
   defineTimeframes();
   calculateDelta();
   //checkNewsHistory();
   if(visual) 
      {
      setChartColors(0);
      if(!live) addWatermark();
      Aggregator();
      trendWindowCreate();
      trendWindowVisualize();
      if(!live) analyticsWindowCreate();
      else
         {
         visualizeTradeHours();
         FVGButtonCreate();
         OBButtonCreate();
         SweepButtonCreate();
         PremDiscButtonCreate();
         }
      showHideButtonCreate();
      ChartRedraw();
      }
   initialized = true;   
   }

void OnTick()
   {
   if(entry1 == none && entry2 == none && entry3 == none) return;
   if(visual && !live) checkButtonState();
   static TRADE_SESSIONS TradeSession(_Symbol);
   static int i;
   if(PositionsTotal() > 0) 
      {
      if(partial) CheckForPartial();
      if(breakeven) checkForBE();
      }
   if(timeframeBars[1] < Bars(_Symbol,1))
      {
      Aggregator();
      if(!TradeSession.isSessionTrade(TimeCurrent())) return; 
      if(maxDailyLoss != 0 && timeframeBars[1440] < Bars(_Symbol,PERIOD_D1)) dayInitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(CancelAtRRR != 0) CheckForClose();
      if(OrdersTotal() > 0) CheckCounterContext();
      if(pdlpdh) CheckPDLPDH();
      if(visual)
         {
         if(timeframeBars[trendTfs[0]] < Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(trendTfs[0]))) trendWindowVisualize();
         if(live && timeframeBars[PeriodSeconds() / 60] < Bars(_Symbol,_Period)) visualizeContext();
         posUpdateOpened();
         visualizeTradeHours();
         //if(skipNews) DrawNews();
         }
      //if(!skipNews || CheckNews())
      if(CheckActiveHours(0))
         {
         for(i = 0; i < ArraySize(entryTfs); i++)
            {
            if(timeframeBars[entryTfs[i]] < Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(entryTfs[i])) || (entrySetup == sweepBos && timeframeBars[additionalTimeframe] < Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(additionalTimeframe))))
               {
               timeframeBars[entryTfs[i]] = Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(entryTfs[i]));
               if(entrySetup == sweepBos && checkForSweepBos(entryTfs[i], additionalTimeframe)) break;
               else if(entrySetup == breaker && checkForBreaker(entryTfs[i])) break;
               else if(entrySetup == absorption && checkForAbsorption(entryTfs[i])) break;
               else if(entrySetup == btsstb && checkForBtsstb(entryTfs[i])) break;
               else if(entrySetup == orderblock && checkForOB(entryTfs[i])) break;
               else if(entrySetup == fvg && checkForFVG(entryTfs[i])) break;
               else if(entrySetup == premdisc && checkForPremdisc(entryTfs[i])) break;
               }
            }
         }   
         
      timeframeBars[1] = Bars(_Symbol,1);
      timeframeBars[additionalTimeframe] = Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(additionalTimeframe));
      timeframeBars[1440] = Bars(_Symbol,PERIOD_D1);
      if(visual) 
         {
         timeframeBars[trendTfs[0]] = Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(trendTfs[0]));
         timeframeBars[PeriodSeconds() / 60] = Bars(_Symbol,_Period);
         }
      }
   if(trail && PositionsTotal() > 0) checkForTrailing();
   return;
   }  

void OnTrade()
   {
   if(visual) updateOrders();
   }
   
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
   if(entry1 == none && entry2 == none && entry3 == none) return;
   static ENUM_TIMEFRAMES currentTF = NULL;
   static string currentSymbol = NULL;
   if(id==CHARTEVENT_CHART_CHANGE && (currentTF != _Period || currentSymbol != _Symbol))
      {
      if(currentSymbol != NULL && currentSymbol != _Symbol) 
         {
         initialized = false;
         OnInit();
         }
      currentTF = _Period;
      currentSymbol = _Symbol;
      visualizeContext(true);
      ChartRedraw();
      }
   else if(id==CHARTEVENT_OBJECT_CLICK)
      {
      if(sparam == FVGButtonText) ShowHideFVG((bool) ObjectGetInteger(0,FVGButtonText,OBJPROP_STATE));
      else if(sparam == OBButtonText) ShowHideOB((bool) ObjectGetInteger(0,OBButtonText,OBJPROP_STATE));
      else if(sparam == SweepButtonText) ShowHideSweep((bool) ObjectGetInteger(0,SweepButtonText,OBJPROP_STATE));
      else if(sparam == PremDiscButtonText) ShowHidePremDisc((bool) ObjectGetInteger(0,PremDiscButtonText,OBJPROP_STATE));
      else if(sparam == "showHide") ShowHidePositions((bool) ObjectGetInteger(0,"showHide",OBJPROP_STATE));
      }
   }
   
void OnDeinit(const int reason)
   {
   if(entry1 == none && entry2 == none && entry3 == none) return;
   if(reason == REASON_PARAMETERS || reason == REASON_RECOMPILE || reason == REASON_CHARTCHANGE || !live) return;
   ObjectsDeleteAll(0,-1,OBJ_BITMAP_LABEL);
   ObjectsDeleteAll(0,-1,OBJ_RECTANGLE_LABEL);
   ObjectsDeleteAll(0,-1,OBJ_BUTTON);
   }

   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Breaker LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForBreaker(int timeframe)
   {
   bool entry = false;
   double FVG[40][4], OBs[40][5];
   int structure[40][3];
   int i, h, g, n, q; 
   double limit, stopLoss, lot, takeProfit, cancelLevel = 0, lowestLow, highestHigh, highestHighAfterBos, lowestLowAfterBos, lowestSwingLow, highestSwingHigh;
   bool breakerValid = false, FVGValid = false;
   int firstHighMSBCandleIndex = 0, firstLowMSBCandleIndex = 0, breakerIndex = 0, OverlapCandleIndex = 0;
   
   clearStructure(structure);
   clearOB(OBs);
   clearFVG(FVG);
   
   fillStructure(structure, timeframe);
   fillOB(structure, OBs, timeframe, true);
   fillFVG(FVG, timeframe);
   
   for(i = 0; i < maxPOICount && OBs[i][0] != 0; i++)
      {
      if(OBs[i][2] != 1) continue;
      firstHighMSBCandleIndex = (int) OBs[i][4];
      breakerIndex = (int) OBs[i][3];
      breakerValid = false;
      lowestSwingLow = 0;
      for(g = breakerIndex; g > 0; g--)
         {
         if(lowestSwingLow != 0 && TF[timeframe][g][3] < lowestSwingLow) break;
         if(isSwingLow(g, timeframe) && TF[timeframe][g][2] <= TF[timeframe][breakerIndex][2])
            {
            if(lowestSwingLow == 0 || TF[timeframe][g][2] < lowestSwingLow) lowestSwingLow = TF[timeframe][g][2];
            }
         }
      if(lowestSwingLow == 0) 
         {
         for(g = breakerIndex + 1; g < breakerIndex + maxCandlesToFindSwingForBreakerBos && lowestSwingLow == 0; g++)
            {
            if(isSwingLow(g, timeframe) && TF[timeframe][g][2] <= TF[timeframe][breakerIndex][2]) lowestSwingLow = TF[timeframe][g][2];
            }
         if(lowestSwingLow != 0)
            {
            for(g = breakerIndex - 2; g > 0; g--)
               {
               if(TF[timeframe][g][3] < lowestSwingLow) break;
               }
            }
         }
      if(lowestSwingLow == 0) continue;
      else if(g != 0 && TF[timeframe][g][3] < lowestSwingLow) firstLowMSBCandleIndex = g;
      else continue;
      OverlapCandleIndex = firstHighMSBCandleIndex - 1;
      for(q = 0; q < maxPOICount && FVG[q][0] != 0; q++)
         {
         if(FVG[q][2] == 1) continue;
         if(TF[timeframe][breakerIndex][0] <= FVG[q][1] && TF[timeframe][breakerIndex][3] >= FVG[q][0])
            {
            FVGValid = true;
            lowestLow = 0;
            if(OverlapCandleIndex > (int) FVG[q][3])
               {
               for(n = firstHighMSBCandleIndex - 1; n > (int) FVG[q][3] && FVGValid; n--)
                  {
                  if(TF[timeframe][n][2] < lowestLow || lowestLow == 0) lowestLow = TF[timeframe][n][2];
                  if(TF[timeframe][n][3] < TF[timeframe][breakerIndex][3]) FVGValid = false;
                  }
               if(!FVGValid) break;
               }   
            else if(OverlapCandleIndex == (int) FVG[q][3]) lowestLow = TF[timeframe][breakerIndex][0];
            else break;
            if(TF[timeframe][breakerIndex][3] < lowestLow)
               {
               if(limitModeBreaker == 1) limit = TF[timeframe][breakerIndex][3];
               else if(limitModeBreaker == 2) limit = FVG[q][0];
               else limit = FVG[q][1];
               breakerValid = true;
               break;
               }
            }
         }
      if(!breakerValid) continue;
      if(breakerIndex > breakerMaxCandlesRange) continue;
      for(h = 0, lowestLow = 0, highestHigh = 0, lowestLowAfterBos = 0, highestHighAfterBos = 0; h != breakerIndex; h++)
         {
         if(h >= firstLowMSBCandleIndex)
            {
            if(TF[timeframe][h][2] < lowestLow || lowestLow == 0) lowestLow = TF[timeframe][h][2];
            if(TF[timeframe][h][1] > highestHigh) highestHigh = TF[timeframe][h][1];
            }   
         else 
            {
            if(TF[timeframe][h][1] > highestHighAfterBos || highestHighAfterBos == 0) highestHighAfterBos = TF[timeframe][h][1];
            if(TF[timeframe][h][2] < lowestLowAfterBos || lowestLowAfterBos == 0) lowestLowAfterBos = TF[timeframe][h][2];
            }  
         }
      if(highestHighAfterBos > highestHigh) continue;
      
      /*for(h = firstLowMSBCandleIndex, highestHigh = TF[timeframe][firstLowMSBCandleIndex][1]; h < breakerIndex; h++)
         {
         if(TF[timeframe][h][1] > highestHigh) highestHigh = TF[timeframe][h][1];
         if(isSwingHigh(h,timeframe) && TF[timeframe][h][1] >= highestHigh) break;
         }*/ // for nearest swing stopLoss
         
      stopLoss = highestHigh + addPippets / pipsDelta;
      takeProfit = limit - ((stopLoss - limit) * RRR);
      if(pdlpdh && pdl != 0) takeProfit = pdl;
      lot = checkPositionForValidity(stopLoss, limit, takeProfit, lowestLowAfterBos, IndexToTime(firstLowMSBCandleIndex, timeframe));
      if(lot == 0) continue;
      
      if(visual) 
         {
         newOrder(limit, stopLoss, takeProfit, (int) FVG[q][3], timeframe, limitModeBreaker == 1 ? breakerIndex : (int) FVG[q][3], timeframe);
         posBreaker(breakerIndex, (int) FVG[q][3], limit, stopLoss, takeProfit, timeframe);
         }
      CheckForOpen(lot, limit, stopLoss, takeProfit, ORDER_TYPE_SELL_LIMIT);
      entry = true;
      break;
      }
   if(entry) return entry;
   
   for(i = 0; i < maxPOICount && OBs[i][0] != 0; i++)
      {
      if(OBs[i][2] != -1) continue;
      firstLowMSBCandleIndex = (int) OBs[i][4];
      breakerIndex = (int) OBs[i][3];
      breakerValid = false;
      highestSwingHigh = 0;
      for(g = breakerIndex; g > 0; g--)
         {
         if(highestSwingHigh != 0 && TF[timeframe][g][3] > highestSwingHigh) break;
         if(isSwingHigh(g, timeframe) && TF[timeframe][g][1] >= TF[timeframe][breakerIndex][1])
            {
            if(highestSwingHigh == 0 || TF[timeframe][g][1] > highestSwingHigh) highestSwingHigh = TF[timeframe][g][1];
            }
         }
      if(highestSwingHigh == 0) 
         {
         for(g = breakerIndex + 1; g < breakerIndex + maxCandlesToFindSwingForBreakerBos && highestSwingHigh == 0; g++)
            {
            if(isSwingHigh(g, timeframe) && TF[timeframe][g][1] >= TF[timeframe][breakerIndex][1]) highestSwingHigh = TF[timeframe][g][1];
            }
         if(highestSwingHigh != 0)
            {
            for(g = breakerIndex - 2; g > 0; g--)
               {
               if(TF[timeframe][g][3] > highestSwingHigh) break;
               }
            }
         }
      if(highestSwingHigh == 0) continue;
      else if(g != 0 && TF[timeframe][g][3] > highestSwingHigh) firstHighMSBCandleIndex = g;
      else continue;
      OverlapCandleIndex = firstLowMSBCandleIndex - 1;
      for(q = 0; q < maxPOICount && FVG[q][0] != 0; q++)
         {
         if(FVG[q][2] == -1) continue;
         if(TF[timeframe][breakerIndex][0] >= FVG[q][0] && TF[timeframe][breakerIndex][3] <= FVG[q][1])
            {
            FVGValid = true;
            highestHigh = 0;
            if(OverlapCandleIndex > (int) FVG[q][3])
               {
               for(n = firstLowMSBCandleIndex - 1; n > (int) FVG[q][3] && FVGValid; n--)
                  {
                  if(TF[timeframe][n][1] > highestHigh || highestHigh == 0) highestHigh = TF[timeframe][n][1];
                  if(TF[timeframe][n][3] > TF[timeframe][breakerIndex][3]) FVGValid = false;
                  }
               if(!FVGValid) break;
               }   
            else if(OverlapCandleIndex == (int) FVG[q][3]) highestHigh = TF[timeframe][breakerIndex][0];
            else break;
            if(TF[timeframe][breakerIndex][3] > highestHigh)
               {
               if(limitModeBreaker == 1) limit = TF[timeframe][breakerIndex][3];
               else if(limitModeBreaker == 2) limit = FVG[q][1];
               else limit = FVG[q][0];
               breakerValid = true;
               break;
               }
            }
         }
      if(!breakerValid) continue;
      if(breakerIndex > breakerMaxCandlesRange) continue;
      for(h = 0, lowestLow = 0, highestHigh = 0, lowestLowAfterBos = 0, highestHighAfterBos = 0; h != breakerIndex; h++)
         {
         if(h >= firstHighMSBCandleIndex)
            {
            if(TF[timeframe][h][2] < lowestLow || lowestLow == 0) lowestLow = TF[timeframe][h][2];
            if(TF[timeframe][h][1] > highestHigh) highestHigh = TF[timeframe][h][1];
            }   
         else 
            {
            if(TF[timeframe][h][1] > highestHighAfterBos || highestHighAfterBos == 0) highestHighAfterBos = TF[timeframe][h][1];
            if(TF[timeframe][h][2] < lowestLowAfterBos || lowestLowAfterBos == 0) lowestLowAfterBos = TF[timeframe][h][2];
            }  
         }
      if(lowestLowAfterBos < lowestLow) continue;
      
      /*for(h = firstHighMSBCandleIndex, lowestLow = TF[timeframe][firstHighMSBCandleIndex][2]; h < breakerIndex; h++)
         {
         if(TF[timeframe][h][2] < lowestLow) lowestLow = TF[timeframe][h][2];
         if(isSwingLow(h,timeframe) && TF[timeframe][h][2] <= lowestLow) break;
         }*/ // for nearest swing stopLoss
         
      stopLoss = lowestLow - addPippets / pipsDelta;
      takeProfit = limit + ((limit - stopLoss) * RRR);
      if(pdlpdh && pdh != 0) takeProfit = pdh;
      lot = checkPositionForValidity(stopLoss, limit, takeProfit, highestHighAfterBos, IndexToTime(firstHighMSBCandleIndex, timeframe));
      if(lot == 0) continue;
      
      if(visual) 
         {
         newOrder(limit, stopLoss, takeProfit, (int) FVG[q][3], timeframe, limitModeBreaker == 1 ? breakerIndex : (int) FVG[q][3], timeframe);
         posBreaker(breakerIndex, (int) FVG[q][3], limit, stopLoss, takeProfit, timeframe);
         }
      CheckForOpen(lot, limit, stopLoss, takeProfit, ORDER_TYPE_BUY_LIMIT);
      entry = true;
      break;
      }
   return entry;
   }
   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Absorption LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForAbsorption(int tf)
   {
   double bodyHigh = TF[tf][2][3] > TF[tf][2][0] ? TF[tf][2][3] : TF[tf][2][0], bodyLow = TF[tf][2][3] < TF[tf][2][0] ? TF[tf][2][3] : TF[tf][2][0];
   bool entry = false;
   
   if(TF[tf][1][2] < TF[tf][2][2] && TF[tf][1][3] > bodyHigh && TF[tf][2][3] < TF[tf][2][0] && TF[tf][1][1] > TF[tf][2][1]) entry = entryLongAbsorption(1, 2, tf);
   if(entry) return entry;
   if(TF[tf][1][1] > TF[tf][2][1] && TF[tf][1][3] < bodyLow && TF[tf][2][3] > TF[tf][2][0] && TF[tf][1][2] < TF[tf][2][2]) entry = entryShortAbsorption(1, 2, tf);
   
   /*
   int swingHighIndex = isSwingHigh(1,tf)? 1 : (isSwingHigh(2,tf)? 2 : 0), swingLowIndex = isSwingLow(1,tf)? 1 : (isSwingLow(2,tf)? 2 : 0);
   int entryIndex = 0;
   if(swingLowIndex != 0)
      {
      if(TF[tf][swingLowIndex][3] > TF[tf][swingLowIndex + 1][1]) entryIndex = swingLowIndex + 1;
      else if(swingLowIndex > 1 && TF[tf][swingLowIndex - 1][3] > TF[tf][swingLowIndex][1]) entryIndex = swingLowIndex;
      if(entryIndex != 0) entry = entryLongAbsorption(swingLowIndex, entryIndex, tf);
      }
   if(entry) return entry;
   entryIndex = 0;
   if(swingHighIndex != 0)
      {
      if(TF[tf][swingHighIndex][3] < TF[tf][swingHighIndex + 1][2]) entryIndex = swingHighIndex + 1;
      else if(swingHighIndex > 1 && TF[tf][swingHighIndex - 1][3] < TF[tf][swingHighIndex][2]) entryIndex = swingHighIndex;
      if(entryIndex != 0) entry = entryShortAbsorption(swingHighIndex, entryIndex, tf);
      }*/
   return entry;
   }

bool entryLongAbsorption(int swingLowIndex, int entryIndex, int tf)
   {
   const double stopLoss = TF[tf][swingLowIndex][2] - addPippets / pipsDelta;
   const double limit = limitModeAbsorption == absorptionBody ? (TF[tf][entryIndex][3] > TF[tf][entryIndex][0] ? TF[tf][entryIndex][3] : TF[tf][entryIndex][0]) : TF[tf][0][0];
   double takeProfit = limit + (limit - stopLoss) * RRR;
   if(pdlpdh && pdh != 0) takeProfit = pdh;
   double lot = checkPositionForValidity(stopLoss, limit, takeProfit, TF[tf][entryIndex - 1][1], IndexToTime(entryIndex - 1, tf));
   if(lot == 0) return false;
   if(visual) 
      {
      newOrder(limit, stopLoss, takeProfit, entryIndex - 1, tf, entryIndex - 1, tf);
      posAbsorption(entryIndex, limit, stopLoss, takeProfit, tf);
      }
   CheckForOpen(lot,limit,stopLoss,takeProfit, limitModeAbsorption == absorptionMarket ? ORDER_TYPE_BUY : ORDER_TYPE_BUY_LIMIT);
   return true;
   }
   
bool entryShortAbsorption(int swingHighIndex, int entryIndex, int tf)
   {
   const double stopLoss = TF[tf][swingHighIndex][1] + addPippets / pipsDelta;
   const double limit = limitModeAbsorption == absorptionBody ? (TF[tf][entryIndex][3] < TF[tf][entryIndex][0] ? TF[tf][entryIndex][3] : TF[tf][entryIndex][0]) : TF[tf][0][0];
   double takeProfit = limit - (stopLoss - limit) * RRR;
   if(pdlpdh && pdl != 0) takeProfit = pdl;
   double lot = checkPositionForValidity(stopLoss, limit, takeProfit, TF[tf][entryIndex - 1][2], IndexToTime(entryIndex - 1, tf));
   if(lot == 0) return false;
   if(visual) 
      {
      newOrder(limit, stopLoss, takeProfit, entryIndex - 1, tf, entryIndex - 1, tf);
      posAbsorption(entryIndex, limit, stopLoss, takeProfit, tf);
      }
   CheckForOpen(lot,limit,stopLoss,takeProfit, limitModeAbsorption == absorptionMarket ? ORDER_TYPE_SELL : ORDER_TYPE_SELL_LIMIT);
   return true; 
   }
   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------BTS/STB LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForBtsstb(int timeframe)
   {
   bool entry = false;
   double swingHigh, swingLow;
   int i, p, h, q, g; 
   double limit, stopLoss, lot, takeProfit, lowestLow, highestHigh, highestHighAfterBos, lowestLowAfterBos, lowestClose, highestClose;
   int firstHighMSBCandleIndex, firstLowMSBCandleIndex, swingHighIndex = 0, swingLowIndex = 0;
   
   for(i = 3, firstLowMSBCandleIndex = 0; i != maxCandlesToFindStructure; i++)
      {
      if(firstLowMSBCandleIndex == 0 && isSwingLow(i, timeframe)) 
         {
         for(p = i - 2, swingLowIndex = i; p != 0 && firstLowMSBCandleIndex == 0; p--)
            {
            if(TF[timeframe][p][2] < TF[timeframe][swingLowIndex][2] && TF[timeframe][p-1][3] > TF[timeframe][swingLowIndex][2] && TF[timeframe][p][3] > TF[timeframe][swingLowIndex][2] && TF[timeframe][p-1][2] > TF[timeframe][p][2]) swingLowIndex = p;
            if(TF[timeframe][swingLowIndex][2] > TF[timeframe][p][3]) firstLowMSBCandleIndex = p;
            }
         }
      if(firstLowMSBCandleIndex == 0) continue;
      
      for(q = firstLowMSBCandleIndex, highestClose = TF[timeframe][firstLowMSBCandleIndex][3], swingHigh = 0; q < firstLowMSBCandleIndex + maxCandlesToFindStructure && swingHigh == 0; q++)
         {
         if(isSwingHigh(q, timeframe) && TF[timeframe][q][1] > highestClose) swingHigh = TF[timeframe][q][1];
         if(TF[timeframe][q][3] > highestClose) highestClose = TF[timeframe][q][3];
         }
      if(swingHigh == 0) break;  
         
      for(g = firstLowMSBCandleIndex - 1, firstHighMSBCandleIndex = 0; g > 0 && firstHighMSBCandleIndex == 0; g--)
         {
         if(swingHigh < TF[timeframe][g][3]) firstHighMSBCandleIndex = g;
         }
      if(firstHighMSBCandleIndex == 0) break;
      
      for(h = 0, lowestLow = 0, highestHigh = 0, lowestLowAfterBos = 0, highestHighAfterBos = 0; h < i; h++)
         {
         if(h >= firstHighMSBCandleIndex)
            {
            if(TF[timeframe][h][2] < lowestLow || lowestLow == 0) lowestLow = TF[timeframe][h][2];
            if(TF[timeframe][h][1] > highestHigh) highestHigh = TF[timeframe][h][1];
            }   
         else 
            {
            if(TF[timeframe][h][1] > highestHighAfterBos || highestHighAfterBos == 0) highestHighAfterBos = TF[timeframe][h][1];
            if(TF[timeframe][h][2] < lowestLowAfterBos || lowestLowAfterBos == 0) lowestLowAfterBos = TF[timeframe][h][2];
            }  
         }
      if(lowestLowAfterBos < lowestLow) break;
      
      stopLoss = lowestLow - addPippets / pipsDelta;
      if(limitModeBtsstb == btsstbFull) limit = swingHigh;
      else if(limitModeBtsstb == btsstb50) limit = lowestLow + (swingHigh - lowestLow) / 2;
      else limit = TF[timeframe][0][0];
      takeProfit = limit + ((limit - stopLoss) * RRR);
      if(pdlpdh && pdh != 0) takeProfit = pdh;
      lot = checkPositionForValidity(stopLoss, limit, takeProfit, highestHighAfterBos, IndexToTime(firstHighMSBCandleIndex, timeframe));
      if(lot == 0) break;
      
      if(visual) 
         {
         newOrder(limit, stopLoss, takeProfit, firstHighMSBCandleIndex, timeframe, q - 1, timeframe);
         posBtsstb(swingLowIndex, firstLowMSBCandleIndex, q - 1, firstHighMSBCandleIndex, limit, stopLoss, takeProfit, timeframe);
         }
      CheckForOpen(lot, limit, stopLoss, takeProfit, (limitModeBtsstb == btsstbMarket ? ORDER_TYPE_BUY : ORDER_TYPE_BUY_LIMIT));
      entry = true;
      break;
      }
   if(entry) return entry;
      
   for(i = 3, firstHighMSBCandleIndex = 0; i != maxCandlesToFindStructure; i++)
      {
      if(firstHighMSBCandleIndex == 0 && isSwingHigh(i, timeframe)) 
         {
         for(p = i - 2, swingHighIndex = i; p != 0 && firstHighMSBCandleIndex == 0; p--)
            {
            if(TF[timeframe][p][1] > TF[timeframe][swingHighIndex][1] && TF[timeframe][p-1][3] < TF[timeframe][swingHighIndex][1] && TF[timeframe][p][3] < TF[timeframe][swingHighIndex][1] && TF[timeframe][p-1][1] < TF[timeframe][p][1]) swingHighIndex = p;
            if(TF[timeframe][swingHighIndex][1] < TF[timeframe][p][3]) firstHighMSBCandleIndex = p;
            }
         }
      if(firstHighMSBCandleIndex == 0) continue;
      
      for(q = firstHighMSBCandleIndex, lowestClose = TF[timeframe][firstHighMSBCandleIndex][3], swingLow = 0; q < firstHighMSBCandleIndex + maxCandlesToFindStructure && swingLow == 0; q++)
         {
         if(isSwingLow(q, timeframe) && TF[timeframe][q][2] < lowestClose) swingLow = TF[timeframe][q][2];
         if(TF[timeframe][q][3] < lowestClose) lowestClose = TF[timeframe][q][3];
         }
      if(swingLow == 0) break;  
         
      for(g = firstHighMSBCandleIndex - 1, firstLowMSBCandleIndex = 0; g > 0 && firstLowMSBCandleIndex == 0; g--)
         {
         if(swingLow > TF[timeframe][g][3]) firstLowMSBCandleIndex = g;
         }
      if(firstLowMSBCandleIndex == 0) break;
      
      for(h = 0, lowestLow = 0, highestHigh = 0, lowestLowAfterBos = 0, highestHighAfterBos = 0; h < i; h++)
         {
         if(h >= firstLowMSBCandleIndex)
            {
            if(TF[timeframe][h][2] < lowestLow || lowestLow == 0) lowestLow = TF[timeframe][h][2];
            if(TF[timeframe][h][1] > highestHigh) highestHigh = TF[timeframe][h][1];
            }   
         else 
            {
            if(TF[timeframe][h][1] > highestHighAfterBos || highestHighAfterBos == 0) highestHighAfterBos = TF[timeframe][h][1];
            if(TF[timeframe][h][2] < lowestLowAfterBos || lowestLowAfterBos == 0) lowestLowAfterBos = TF[timeframe][h][2];
            }  
         }
      if(highestHighAfterBos > highestHigh) break;
      
      stopLoss = highestHigh + addPippets / pipsDelta;
      if(limitModeBtsstb == btsstbFull) limit = swingLow;
      else if(limitModeBtsstb == btsstb50) limit = swingLow + (highestHigh - swingLow) / 2;
      else limit = TF[timeframe][0][0];
      takeProfit = limit - ((stopLoss - limit) * RRR);
      if(pdlpdh && pdl != 0) takeProfit = pdl;
      if(!context(false, stopLoss, lowestLowAfterBos)) break;
      lot = checkPositionForValidity(stopLoss, limit, takeProfit, lowestLowAfterBos, IndexToTime(firstLowMSBCandleIndex, timeframe));
      if(lot == 0) break;
      
      if(visual) 
         {
         newOrder(limit, stopLoss, takeProfit, firstLowMSBCandleIndex, timeframe, q - 1, timeframe);
         posBtsstb(swingHighIndex, firstHighMSBCandleIndex, q - 1, firstLowMSBCandleIndex, limit, stopLoss, takeProfit, timeframe);
         }
      CheckForOpen(lot, limit, stopLoss, takeProfit, (limitModeBtsstb == btsstbMarket ? ORDER_TYPE_SELL : ORDER_TYPE_SELL_LIMIT));
      entry = true;
      break;
      }
   return entry;   
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Orderblock LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForOB(int tf)
   {
   bool entry = false;
   double OBs[40][5];
   int structure[40][3];
   double limit, stopLoss, takeProfit, lot, highestHigh = 0, lowestLow = 0;
   int i, j;
   
   clearStructure(structure);
   clearOB(OBs);
   
   fillStructure(structure, tf);
   fillOB(structure, OBs, tf, false);
   int lastStrLocal = lastStructure;
   
   for(i = 0; i < maxPOICount; i++)
      {
      if(OBs[i][2] == lastStrLocal) break;
      }
   if(i == maxPOICount) return entry;
   if((int) OBs[i][4] != 1) return entry;
   int lastStrBosLocal = (int) OBs[i][4];
   for(j = 0; j < (int) OBs[i][3]; j++)
      {
      if(lastStrLocal == -1 && (lowestLow == 0 || TF[tf][j][2] < lowestLow)) lowestLow = TF[tf][j][2];
      else if(lastStrLocal == 1 && (highestHigh == 0 || TF[tf][j][1] > highestHigh)) highestHigh = TF[tf][j][1];
      }
      
   stopLoss = lastStrLocal == 1 ? OBs[i][0] - addPippets / pipsDelta : OBs[i][1] + addPippets / pipsDelta;
   if(limitModeOrderblock == orderblockFull) limit = lastStrLocal == 1 ? OBs[i][1] : OBs[i][0];
   else limit = OBs[i][1] - (OBs[i][1] - OBs[i][0]) / 2;
   takeProfit = lastStrLocal == 1 ? limit + ((limit - stopLoss) * RRR) : limit - ((stopLoss - limit) * RRR);
   if(pdlpdh && ((lastStrLocal == 1 && pdh != 0) || (lastStrLocal == -1 && pdl != 0))) takeProfit = lastStrLocal == 1 ? pdh : pdl;
   lot = checkPositionForValidity(stopLoss, limit, takeProfit, lastStrLocal == 1 ? highestHigh : lowestLow, IndexToTime(lastStrBosLocal, tf));
   if(lot == 0) return entry;
   
   if(visual) 
      {
      newOrder(limit, stopLoss, takeProfit, lastStrBosLocal, tf, (int) OBs[i][3], tf);
      posOrderblock((int) OBs[i][3], lastStrBosLocal, limit, stopLoss, takeProfit, tf);
      }
   CheckForOpen(lot, limit, stopLoss, takeProfit, (lastStrLocal == 1 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT));
   return true;
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------FVG LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForFVG(int tf)
   {
   bool entry = false;
   double limit, stopLoss, takeProfit, lot;
   int FVGFormed = 0;
   
   if(TF[tf][1][2] > TF[tf][3][1]) FVGFormed = 1;
   else if(TF[tf][1][1] < TF[tf][3][2]) FVGFormed = -1;
   if(FVGFormed == 0) return false;
   
   double highestHigh = TF[tf][1][1], lowestLow = TF[tf][1][2];
   stopLoss = FVGFormed == 1 ? TF[tf][2][2] - addPippets / pipsDelta : TF[tf][2][1] + addPippets / pipsDelta;
   
   if(limitModeFVG == FVG) limit = FVGFormed == 1 ? TF[tf][1][2] : TF[tf][1][1];
   else if(limitModeFVG == FVG50) limit = FVGFormed == 1 ? TF[tf][3][1] + (TF[tf][1][2] - TF[tf][3][1]) / 2 : TF[tf][1][1] + (TF[tf][3][2] - TF[tf][1][1]) / 2;
   else limit = FVGFormed == 1 ? TF[tf][3][1] : TF[tf][3][2];
   
   takeProfit = FVGFormed == 1 ? limit + ((limit - stopLoss) * RRR) : limit - ((stopLoss - limit) * RRR);
   if(pdlpdh && ((FVGFormed == 1 && pdh != 0) || (FVGFormed == -1 && pdl != 0))) takeProfit = FVGFormed == 1 ? pdh : pdl;
   lot = checkPositionForValidity(stopLoss, limit, takeProfit, FVGFormed == 1 ? highestHigh : lowestLow, IndexToTime(1, tf));
   if(lot == 0) return entry;
   
   if(visual) 
      {
      newOrder(limit, stopLoss, takeProfit, 1, tf, 2, tf);
      posFVG(3, 1, limit, stopLoss, takeProfit, tf);
      }
   CheckForOpen(lot, limit, stopLoss, takeProfit, (FVGFormed == 1 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT));
   return true;
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Prem/Disc LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkForPremdisc(int tf)
   {
   bool entry = false;
   double range[4];
   double limit, stopLoss, takeProfit, lot;
   /*
   int structure[40][3];
   clearStructure(structure);
   fillStructure(structure, tf);
   fillRangesForPremDisc(range, tf, true);
   const bool isLong = lastStructure == 1 ? true : false;
   */
   fillRanges(tf);
   if(TFTrend[tf] == 0) return entry;
   const bool isLong = TFTrend[tf] == 1 ? true : false;
   range[0] = lastRangeSwingLow;
   range[1] = lastRangeSwingHigh;
   range[2] = isLong ? lastRangeSwingHighIndex : lastRangeSwingLowIndex;
   range[3] = isLong ? lastRangeSwingLowIndex : lastRangeSwingHighIndex;
   
   stopLoss = isLong ? range[0] - addPippets / pipsDelta : range[1] + addPippets / pipsDelta;
   
   if(limitModePremdisc == premdisc50) limit = range[0] + (range[1] - range[0]) / 2;
   else if(limitModePremdisc == premdisc33) limit = isLong ? range[0] + (range[1] - range[0]) / 3 : range[1] - (range[1] - range[0]) / 3;
   else limit = isLong ? range[0] + (range[1] - range[0]) / 4 : range[1] - (range[1] - range[0]) / 4;
   
   takeProfit = isLong ? limit + ((limit - stopLoss) * RRR) : limit - ((stopLoss - limit) * RRR);
   if(pdlpdh && ((isLong && pdh != 0) || (!isLong && pdl != 0))) takeProfit = isLong ? pdh : pdl;
   
   lot = checkPositionForValidity(stopLoss, limit, takeProfit, isLong ? range[1] : range[0], IndexToTime(lastRangeBosIndex, tf));
   if(lot == 0) return entry;
   
   if(visual) 
      {
      newOrder(limit, stopLoss, takeProfit, lastRangeBosIndex, tf, 1, tf);
      posPremdisc((int) range[2], (int) range[3], lastRangeBosIndex, limit, stopLoss, takeProfit, tf);
      }
   CheckForOpen(lot, limit, stopLoss, takeProfit, (isLong ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT));
   
   return entry;
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Sweep+BOS LTF--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
input bool newBosMode = true;
bool checkForSweepBos(int sweepTimeframe, int bosTimeframe)
   {
   double high = 0, low = 0, highI, highP;
   double lot = 0, limit, cancelLevel, stopLoss, sellTakeProfit = 0;
   double sweptHigh = 0, sweptLow = 0, highestHigh = TF[sweepTimeframe][0][1], highestClose = TF[sweepTimeframe][1][3];
   bool entry = false, MSB = false;
   int i, j = 0, k = 0, p, q, swingLowIndex, bosIndex, limitIndex, BZIndex, RCIndex;
   
   if(TF[sweepTimeframe][1][1] > highestHigh) highestHigh = TF[sweepTimeframe][1][1];
   if(TF[sweepTimeframe][2][1] > highestHigh) highestHigh = TF[sweepTimeframe][2][1];
   if(TF[sweepTimeframe][2][3] > highestClose) highestClose = TF[sweepTimeframe][2][3];
   
   for(i = 3; i != maxCandlesForSweepRange; i++)
      {
      sweptHigh = 0;
      highI = TF[sweepTimeframe][i][1];
      if(highI > highestHigh) highestHigh = highI;
      if(TF[sweepTimeframe][i][3] > highestClose) highestClose = TF[sweepTimeframe][i][3];
      if(TF[sweepTimeframe][i][0] > highestClose) highestClose = TF[sweepTimeframe][i][0];
      for(p = 1; p < maxCandlesForSweepToBeValid && p < i - 1; p++)
         {
         highP = TF[sweepTimeframe][p][1];
         if(highP >= highestHigh && highI < highP && TF[sweepTimeframe][p+1][1] < highP && highI > highestClose)
            {
            if((highI > TF[sweepTimeframe][i-1][1] && highI > TF[sweepTimeframe][i+1][1]) || (highI > TF[sweepTimeframe][i-1][1] && highI >= TF[sweepTimeframe][i+1][1] && TF[sweepTimeframe][i+1][1] > TF[sweepTimeframe][i+2][1]))
               {
               if(sweepTimeframe <= 60 && !CheckActiveHours(IndexToTime(p, sweepTimeframe))) break;
               if(sweptHigh > 0) break;
               else sweptHigh = highI;
               for(j = 1, low = TF[bosTimeframe][j][2], high = TF[bosTimeframe][j][1]; j <= (p + 1) * (double(sweepTimeframe) / double(bosTimeframe)); j++)
                  {
                  if(TF[bosTimeframe][j][2] < low) low = TF[bosTimeframe][j][2];
                  if(TF[bosTimeframe][j][1] > high) high = TF[bosTimeframe][j][1];
                  if(TF[bosTimeframe][j][1] == highP && high == TF[bosTimeframe][j][1] && bosIndex != p)
                     {
                     stopLoss = highP + addPippets / pipsDelta;
                     if(posDuplicated(0, stopLoss)) break;
                     for(k = 0, swingLowIndex = 0; k != maxCandlesForSwingToBreak && swingLowIndex == 0; k++)
                        {
                        if(isSwingLow(j+k,bosTimeframe) && (!newBosMode || TF[bosTimeframe][j+k][2] < TF[bosTimeframe][j][2])) swingLowIndex = j+k;
                        }
                     k--; 
                     if(swingLowIndex == 0) break;
                     for(q = j-1, bosIndex = 0; q > 0 && bosIndex == 0; q--)
                        {
                        if(TF[bosTimeframe][q][3] < TF[bosTimeframe][swingLowIndex][2]) bosIndex = q;
                        }
                     if(bosIndex == 0) break;
                     
                     if(!CheckActiveHours(IndexToTime(bosIndex, bosTimeframe))) break;
                     if(!context(false, stopLoss, low)) break;
                     
                     lot = 0;
                     RCIndex = j;
                     if(LimitMode == limitBZ || LimitMode == limitFlexible)
                        {
                        for(k = 1; k != maxCandlesToFindLimit; k++)
                           {
                           if(TF[bosTimeframe][j+k][3] < TF[bosTimeframe][j+k][0]) break;
                           }
                        BZIndex = TF[bosTimeframe][j+k][2] < TF[bosTimeframe][swingLowIndex][2] ? swingLowIndex : j+k;
                        if(LimitMode == limitFlexible)
                           {
                           limitIndex = BZIndex;
                           limit = TF[bosTimeframe][limitIndex][2];
                           lot = positionCalculator(limit, stopLoss, false, false);
                           if(lot == 0)
                              {
                              limitIndex = RCIndex;
                              limit = TF[bosTimeframe][limitIndex][2];
                              lot = positionCalculator(limit, stopLoss, false, false);
                              if(lot == 0) limitIndex = swingLowIndex;
                              }
                           }  
                        else if(LimitMode == limitBZ) limitIndex = BZIndex;
                        }
                     else if(LimitMode == limitBTSSTB) limitIndex = swingLowIndex;
                     else if(LimitMode == limitRC) limitIndex = RCIndex;
                     
                     if(lot == 0)
                        {
                        limit = TF[bosTimeframe][limitIndex][2];
                        lot = positionCalculator(limit, stopLoss, false, true);
                        }
                     if(lot != 0)
                        {
                        sellTakeProfit = limit - ((stopLoss - limit) * RRR);
                        if(pdlpdh && pdl != 0) sellTakeProfit = pdl;
                        cancelLevel = limit - ((stopLoss - limit) * CancelAtRRR);
                        if(CancelAtRRR != 0 && low < cancelLevel) break;
                        saveStopLoss(0, stopLoss); 
                        //if(skipNews && !CheckNews(IndexToTime(RCIndex,bosTimeframe))) break;
                        if(visual) 
                           {
                           newOrder(limit, stopLoss, sellTakeProfit, bosIndex, bosTimeframe, limitIndex, sweepTimeframe);
                           posNewSweepBos(i, p, swingLowIndex, bosIndex, limit, stopLoss, sellTakeProfit, sweepTimeframe);
                           }
                        CheckForOpen(lot, limit, stopLoss, sellTakeProfit, ORDER_TYPE_SELL_LIMIT);
                        entry = true;
                        break;
                        }
                     else break;
                     }
                  }
               }
            }
         }
      }
   if(entry) return entry;
   double lowI, lowP;
   double buyTakeProfit = 0;
   int swingHighIndex = 0;
   double lowestLow = TF[sweepTimeframe][0][2], lowestClose = TF[sweepTimeframe][1][3];
   
   if(TF[sweepTimeframe][1][2] < lowestLow) lowestLow = TF[sweepTimeframe][1][2];
   if(TF[sweepTimeframe][2][2] < lowestLow) lowestLow = TF[sweepTimeframe][2][2];
   if(TF[sweepTimeframe][2][3] < lowestClose) lowestClose = TF[sweepTimeframe][2][3];
   
   for(i = 3; i != maxCandlesForSweepRange; i++)
      {
      sweptLow = 0;
      lowI = TF[sweepTimeframe][i][2];
      if(lowI < lowestLow) lowestLow = lowI;
      if(TF[sweepTimeframe][i][3] < lowestClose) lowestClose = TF[sweepTimeframe][i][3];
      if(TF[sweepTimeframe][i][0] < lowestClose) lowestClose = TF[sweepTimeframe][i][0];
      for(p = 1; p < maxCandlesForSweepToBeValid && p < i - 1; p++)
         {
         lowP = TF[sweepTimeframe][p][2];
         if(lowP <= lowestLow && lowI > lowP && TF[sweepTimeframe][p+1][2] > lowP && lowI <= lowestClose)
            {
            if((lowI < TF[sweepTimeframe][i-1][2] && lowI < TF[sweepTimeframe][i+1][2]) || (lowI < TF[sweepTimeframe][i-1][2] && lowI <= TF[sweepTimeframe][i+1][2] && TF[sweepTimeframe][i+1][2] < TF[sweepTimeframe][i+2][2]))
               {
               if(sweepTimeframe <= 60 && !CheckActiveHours(IndexToTime(p, sweepTimeframe))) break;
               if(sweptLow > 0) break;
               else sweptLow = lowI;
               for(j = 1,high = TF[bosTimeframe][j][1],low = TF[bosTimeframe][j][2]; j <= (p + 1) * (double(sweepTimeframe) / double(bosTimeframe)); j++)
                  {
                  if(TF[bosTimeframe][j][2] < low) low = TF[bosTimeframe][j][2];
                  if(TF[bosTimeframe][j][1] > high) high = TF[bosTimeframe][j][1];
                  if(TF[bosTimeframe][j][2] == lowP && low == TF[bosTimeframe][j][2] && bosIndex != p)
                     {
                     stopLoss = lowP - addPippets / pipsDelta;
                     if(posDuplicated(1, stopLoss)) break; 
                     for(k = 1, swingHighIndex = 0; k != maxCandlesForSwingToBreak && swingHighIndex == 0; k++)
                        {
                        if(isSwingHigh(j+k,bosTimeframe) && (!newBosMode || TF[bosTimeframe][j+k][1] > TF[bosTimeframe][j][1])) swingHighIndex = j+k;
                        }
                     k--;   
                     if(swingHighIndex == 0) break;
                     
                     for(q = j-1, bosIndex = 0; q > 0 && bosIndex == 0; q--)
                        {
                        if(TF[bosTimeframe][q][3] > TF[bosTimeframe][swingHighIndex][1]) bosIndex = q;
                        }
                     if(bosIndex == 0) break;
                     
                     if(!CheckActiveHours(IndexToTime(bosIndex, bosTimeframe))) break;
                     if(!context(true, stopLoss, high)) break;
                     
                     lot = 0;
                     RCIndex = j;
                     if(LimitMode == limitBZ || LimitMode == limitFlexible)
                        {
                        for(k = 1; k != maxCandlesToFindLimit; k++)
                           {
                           if(TF[bosTimeframe][j+k][3] > TF[bosTimeframe][j+k][0]) break;
                           }
                        BZIndex = TF[bosTimeframe][j+k][1] > TF[bosTimeframe][swingHighIndex][1] ? swingHighIndex : j+k;
                        if(LimitMode == limitFlexible)
                           {
                           limitIndex = BZIndex;
                           limit = TF[bosTimeframe][limitIndex][1];
                           lot = positionCalculator(limit, stopLoss, true, false);
                           if(lot == 0)
                              {
                              limitIndex = RCIndex;
                              limit = TF[bosTimeframe][limitIndex][1];
                              lot = positionCalculator(limit, stopLoss, true, false);
                              if(lot == 0) limitIndex = swingHighIndex;
                              }
                           }   
                        else if(LimitMode == limitBZ) limitIndex = BZIndex;
                        }
                     else if(LimitMode == limitBTSSTB) limitIndex = swingHighIndex;
                     else if(LimitMode == limitRC) limitIndex = RCIndex;
                     
                     if(lot == 0)
                        {
                        limit = TF[bosTimeframe][limitIndex][1];
                        lot = positionCalculator(limit, stopLoss, true, true);
                        }
                     
                     if(lot != 0)
                        {
                        buyTakeProfit = limit + ((limit - stopLoss) * RRR);
                        if(pdlpdh && pdh != 0) buyTakeProfit = pdh;
                        cancelLevel = limit + ((limit - stopLoss) * CancelAtRRR);
                        if(CancelAtRRR != 0 && high > cancelLevel) break;
                        saveStopLoss(1, stopLoss);  
                        //if(skipNews && !CheckNews(IndexToTime(RCIndex,bosTimeframe))) break;
                        if(visual) 
                           {
                           newOrder(limit, stopLoss, buyTakeProfit, bosIndex, bosTimeframe, limitIndex, sweepTimeframe);
                           posNewSweepBos(i, p, swingHighIndex, bosIndex, limit, stopLoss, buyTakeProfit, sweepTimeframe);
                           }
                        CheckForOpen(lot, limit, stopLoss, buyTakeProfit, ORDER_TYPE_BUY_LIMIT);
                        entry = true;
                        break;
                        }
                     else break;
                     }
                  }
               }
            }
         }
      }
   return entry;   
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Context--------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

int timeframeStructure[40][3];
double timeframeOBs[40][5], timeframeFVGs[40][4];
bool timeframeSweepForShort = false, timeframeSweepForLong = false, timeframeShortFVGFF = false, timeframeLongFVGFF = false;

bool context(bool buy, double stopLoss, double counteragrumentsLevel)
   {
   const double localSL = stopLoss + (buy ? ((addPippets + _Point) / pipsDelta) : -((addPippets + _Point) / pipsDelta));
   bool valid = true;
   
   if(counterContextMode != Off) valid = checkContext(!buy, counteragrumentsLevel, true);
   
   if(stopLoss == 0) return valid; // For check counter context
   
   if(PremDiscMode != off) valid = valid ? checkPremDisc(localSL, buy) : valid;
      
   if(structureSyncMode != off) valid = valid ? checkStructure(buy) : valid;
   
   if(trendSyncMode != off) valid = valid ? checkTrend(buy) : valid;
   
   if(contextMode != off) valid = valid ? checkContext(buy, localSL, false) : valid;
   
   return valid;
   }
   
bool checkPremDisc(double localSL, bool buy)
   {
   int i;
   bool premDiscBool = false;
   double timeframeRange[4];
   for(i = 0; i < ArraySize(premiumDiscTfs); i++)
      {
      fillRanges(premiumDiscTfs[i]);
      timeframeRange[0] = lastRangeSwingLow;
      timeframeRange[1] = lastRangeSwingHigh;
      timeframeRange[2] = lastRangeSwingLow + (lastRangeSwingHigh - lastRangeSwingLow) / (100 / premdiscPercent);
      timeframeRange[3] = TFTrend[premiumDiscTfs[i]];
      if(timeframeRange[3] != 1 && timeframeRange[3] != -1)
         {
         if(PremDiscMode == allOf) 
            {
            premDiscBool = false;
            break;
            }
         else continue;   
         }
      if(buy)
         {
         if(localSL < timeframeRange[2] && localSL > timeframeRange[0])
            {
            premDiscBool = true;
            if(PremDiscMode == oneOf) break;
            }
         else if(PremDiscMode == allOf)
            {
            premDiscBool = false;
            break;
            }   
         }
      else if(!buy)
         {
         if(localSL > timeframeRange[2] && localSL < timeframeRange[1])
            {
            premDiscBool = true;
            if(PremDiscMode == oneOf) break;
            }
         else if(PremDiscMode == allOf)
            {
            premDiscBool = false;
            break;
            }
         }
      else if(PremDiscMode == allOf) 
         {
         premDiscBool = false;
         break;
         }
      }
   return premDiscBool;   
   }  
   
bool checkStructure(bool buy)
   {
   int i;
   bool structureBool = false;
   clearStructure(timeframeStructure);
   if(structureSyncMode == allOf)
      {
      structureBool = true;
      for(i = 0; i < ArraySize(strSyncTfs) && structureBool; i++)
         {
         fillStructure(timeframeStructure, strSyncTfs[i]);
         if(buy && lastStructure == -1) structureBool = false;
         else if(!buy && lastStructure == 1) structureBool = false;
         clearStructure(timeframeStructure);
         }
      }
   else if(structureSyncMode == oneOf)
      {
      for(i = 0; i < ArraySize(strSyncTfs) && !structureBool; i++)
         {
         fillStructure(timeframeStructure, strSyncTfs[i]);
         if(buy && lastStructure == 1) structureBool = true;
         else if(!buy && lastStructure == -1) structureBool = true;
         clearStructure(timeframeStructure);
         }
      }
   return structureBool;   
   }  
   
bool checkTrend(bool buy)
   {
   int i;
   bool trendBool = false;
   if(trendSyncMode == allOf)
      {
      trendBool = true;
      for(i = 0; i < ArraySize(trendSyncTfs) && trendBool; i++)
         {
         fillRanges(trendSyncTfs[i]);
         if(buy && TFTrend[trendSyncTfs[i]] == -1) trendBool = false;
         else if(!buy && TFTrend[trendSyncTfs[i]] == 1) trendBool = false;
         else if(TFTrend[trendSyncTfs[i]] == 0) trendBool = false;
         }
      }
   else if(trendSyncMode == oneOf)
      {
      for(i = 0; i < ArraySize(trendSyncTfs) && !trendBool; i++)
         {
         fillRanges(trendSyncTfs[i]);
         if(buy && TFTrend[trendSyncTfs[i]] == 1) trendBool = true;
         else if(!buy && TFTrend[trendSyncTfs[i]] == -1) trendBool = true;
         }
      }
   return trendBool;   
   }  

bool checkContext(bool buy, double level, bool counter)
   {
   int i;
   bool contextBool = (contextMode == oneOf || counter) ? false : true;
   clearPois(timeframeStructure, timeframeOBs, timeframeFVGs, timeframeSweepForShort, timeframeSweepForLong, timeframeShortFVGFF, timeframeLongFVGFF, counter);
   for(i = 0; i < (counter ? ArraySize(counterPoiTfs) : ArraySize(poiTfs)); i++)
      {
      fillPois(timeframeStructure, timeframeOBs, timeframeFVGs, timeframeSweepForShort, timeframeSweepForLong, timeframeShortFVGFF, timeframeLongFVGFF, counter ? counterPoiTfs[i] : poiTfs[i], counter);
      contextBool = checkPois(timeframeOBs, timeframeFVGs, timeframeSweepForShort, timeframeSweepForLong, timeframeShortFVGFF, timeframeLongFVGFF, buy, level, counter);
      clearPois(timeframeStructure, timeframeOBs, timeframeFVGs, timeframeSweepForShort, timeframeSweepForLong, timeframeShortFVGFF, timeframeLongFVGFF, counter);
      if((contextMode == oneOf || counter) && contextBool) break;
      else if(contextMode == allOf && !counter && !contextBool) break;
      }
   return(counter ? !contextBool : contextBool);
   }

bool checkPois(double& OB[][], double& FVG[][], bool& sweepForShort, bool& sweepForLong, bool& shortFVGFF, bool& longFVGFF, bool buy, double stopLoss, bool counterContext)
   {
   bool isValid = false;
   int i = 0;
   
   if((countOB && !counterContext) || (counterContext && countCounterOB))
      {
      for(i = 0; i < maxPOICount && OB[i][2] != 0 && !isValid; i++)
         {
         if(buy && OB[i][2] != 1) continue;
         if(!buy && OB[i][2] != -1) continue;
         if(stopLoss < OB[i][1] && stopLoss > OB[i][0]) isValid = true;
         }
      }   
   
   if((countFVG && !counterContext) || (counterContext && countCounterFVG))
      {
      for(i = 0; i < maxPOICount && FVG[i][2] != 0 && !isValid; i++)
         {
         if(buy && FVG[i][2] != 1) continue;
         if(!buy && FVG[i][2] != -1) continue;
         if(stopLoss <= FVG[i][1] && stopLoss >= FVG[i][0]) isValid = true;
         } 
      }
   if((countSweep && !counterContext) || (counterContext && countCounterSweep))
      {
      if(buy && sweepForLong) isValid = true;
      if(!buy && sweepForShort) isValid = true;
      }
   if((countFF && !counterContext) || (counterContext && countCounterFF))
      {
      if(buy && longFVGFF) isValid = true;
      if(!buy && shortFVGFF) isValid = true;
      }
   return isValid;
   }

void clearPois(int& structure[][], double& OB[][], double& FVG[][], bool& sweepForShort, bool& sweepForLong, bool& shortFVGFF, bool& longFVGFF, bool counterContext)
   {
   clearStructure(structure);
   if((countOB && !counterContext) || (counterContext && countCounterOB)) clearOB(OB);
   if((countFVG && !counterContext) || (counterContext && countCounterFVG)) clearFVG(FVG);
   if((countSweep && !counterContext) || (counterContext && countCounterSweep))
      {
      sweepForShort = false; 
      sweepForLong = false;
      }
   if((countFF && !counterContext) || (counterContext && countCounterFF))
      {
      shortFVGFF = false; 
      longFVGFF = false;
      }
   }
void fillPois(int& structure[][], double& OB[][], double& FVG[][], bool& sweepForShort, bool& sweepForLong, bool& shortFVGFF, bool& longFVGFF, int timeframe, bool counterContext)
   {
   fillStructure(structure, timeframe);
   if((countOB && !counterContext) || (counterContext && countCounterOB)) fillOB(structure, OB, timeframe);
   if((countFVG && !counterContext) || (counterContext && countCounterFVG)) fillFVG(FVG, timeframe);
   if((countSweep && !counterContext) || (counterContext && countCounterSweep)) sweep(sweepForShort, sweepForLong, timeframe, counterContext);
   if((countFF && !counterContext) || (counterContext && countCounterFF)) FF(shortFVGFF, longFVGFF, timeframe, counterContext);
   }
void clearOB(double& OB[][], bool visualize = false)
   {
   for(int i = 0; i < maxPOICount; i++)
      {
      OB[i][0] = 0;
      OB[i][1] = 0;
      OB[i][2] = 0;
      OB[i][3] = 0;
      OB[i][4] = 0;
      }
   if(visualize) ObjectsDeleteAll(0,OBText + MinutesToTF(PeriodSeconds() / 60),0,OBJ_RECTANGLE);
   }
void clearFVG(double& FVG[][], bool visualize = false)
   {
   for(int i = 0; i < maxPOICount; i++)
      {
      FVG[i][0] = 0;
      FVG[i][1] = 0;
      FVG[i][2] = 0;
      FVG[i][3] = 0;
      }
   if(visualize) ObjectsDeleteAll(0,FVGText + MinutesToTF(PeriodSeconds() / 60),0,OBJ_RECTANGLE);
   }
void clearStructure(int& structure[][])
   {
   lastStructure = 0;
   for(int i = 0; i < maxPOICount; i++)
      {
      structure[i][0] = 0;
      structure[i][1] = 0;
      structure[i][2] = 0;
      }
   }
void clearSweeps()
   {
   lastLongSweep[0] = 0;
   lastLongSweep[1] = 0;
   lastLongSweep[2] = 0;
   lastShortSweep[0] = 0;
   lastShortSweep[1] = 0;
   lastShortSweep[2] = 0;
   timeframeSweepForLong = false;
   timeframeSweepForShort = false;
   }
void clearRanges(bool visualize = false)
   {
   for(int i = 0; i < maxPOICount; i++)
      {
      ranges[i][0] = 0;
      ranges[i][1] = 0;
      ranges[i][2] = 0;
      ranges[i][3] = 0;
      }
   if(visualize) 
      {
      ObjectsDeleteAll(0,PremDiscText + MinutesToTF(PeriodSeconds() / 60),0,OBJ_RECTANGLE);
      ObjectsDeleteAll(0,PremDiscText + MinutesToTF(PeriodSeconds() / 60),0,OBJ_TREND);
      }
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------POI Definition-------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void fillOB(int& structure[][], double& OB[][], int timeframe, bool breaker = false)
   {
   double lowestLow = TF[timeframe][0][2], highestHigh = TF[timeframe][0][1], lastOppositeLow = 0, lastOppositeHigh = 0;
   int k = 0, j = 0, i = 0, d = 0, c = 0, lastOBIndex = 0, OBIndex = 0, strSweepCandleIndex, strBosCandleIndex;
   bool OBRepeated = false, swingNotBosed = false, replaceOB = false;
   
   for(i = 0; i < maxPOICount && structure[i][0] != 0; i++)
      {
      replaceOB = false;
      if(structure[i][0] == 1)
         {
         lastOppositeLow = 0;
         strSweepCandleIndex = structure[i][2];
         strBosCandleIndex = structure[i][1];
         for(k = 0; k != structure[i][1]; k++)
            {
            if(TF[timeframe][k][2] < lowestLow) lowestLow = TF[timeframe][k][2];
            }
         for(j = strBosCandleIndex + 1; j != strSweepCandleIndex + 1; j++)
            {
            if(TF[timeframe][j][3] < TF[timeframe][j][0])
               {
               if(TF[timeframe][j][1] > TF[timeframe][strBosCandleIndex][3]) 
                  {
                  if(lastOppositeLow == 0 || TF[timeframe][j][2] < lastOppositeLow) lastOppositeLow = TF[timeframe][j][2];
                  continue;
                  }
               if(lastOppositeLow != 0 && lastOppositeLow < TF[timeframe][j][2]) continue;
               for(c = j, swingNotBosed = false; c != strSweepCandleIndex; c++)
                  {
                  if(TF[timeframe][c][1] > TF[timeframe][strSweepCandleIndex][1])
                     {
                     if(TF[timeframe][c][1] > TF[timeframe][c-1][1] && TF[timeframe][c][1] > TF[timeframe][c+1][1])
                        {
                        if(TF[timeframe][strBosCandleIndex][3] < TF[timeframe][c][1]) 
                           {
                           swingNotBosed = true;
                           break;
                           }
                        }   
                     }      
                  }
               if(swingNotBosed) continue;
               for(d = OBIndex - 1, OBRepeated = false; d >= 0 && OB[d][3] != 0; d--)
                  {
                  if(OB[d][3] == j) OBRepeated = true;
                  }
               if(OBRepeated) continue;
               if(OBIndex > 0) 
                  {
                  for(d = OBIndex - 1, lastOBIndex = -1; d >= 0 && OB[d][3] != 0; d--)
                     {
                     if(OB[d][2] == 1) 
                        {
                        if(OB[d][3] < strSweepCandleIndex && OB[d][3] > strBosCandleIndex && (lastOBIndex == -1 || OB[d][0] < OB[lastOBIndex][0]))
                           {
                           lastOBIndex = d;
                           }
                        }
                     }
                  if(lastOBIndex >= 0 && (TF[timeframe][j][1] >= OB[lastOBIndex][1] || TF[timeframe][j][2] >= OB[lastOBIndex][0])) continue;
                  }
               if(replaceOB) OBIndex--;
               if(lowestLow <= TF[timeframe][j][2] && !breaker) continue;
               OB[OBIndex][0] = TF[timeframe][j][2];
               OB[OBIndex][1] = TF[timeframe][j][1];
               OB[OBIndex][2] = 1;
               OB[OBIndex][3] = j;
               OB[OBIndex][4] = strBosCandleIndex;
               OBIndex++;
               replaceOB = true;
               continue;
               }
            }
         }
      else if(structure[i][0] == -1)
         {
         lastOppositeHigh = 0;
         strSweepCandleIndex = structure[i][2];
         strBosCandleIndex = structure[i][1];
         for(k = 0; k != strBosCandleIndex; k++)
            {
            if(TF[timeframe][k][1] > highestHigh) highestHigh = TF[timeframe][k][1];
            }
         for(j = strBosCandleIndex + 1; j != strSweepCandleIndex + 1; j++)
            { 
            if(TF[timeframe][j][3] > TF[timeframe][j][0])
               {
               if(TF[timeframe][j][2] < TF[timeframe][strBosCandleIndex][3])
                  {
                  if(lastOppositeHigh == 0 || TF[timeframe][j][1] > lastOppositeHigh) lastOppositeHigh = TF[timeframe][j][1];
                  continue;
                  }
               if(lastOppositeHigh != 0 && lastOppositeHigh > TF[timeframe][j][1]) continue;
               for(c = j, swingNotBosed = false; c != strSweepCandleIndex; c++)
                  {
                  if(TF[timeframe][c][2] < TF[timeframe][strSweepCandleIndex][2])
                     {
                     if(TF[timeframe][c][2] < TF[timeframe][c-1][2] && TF[timeframe][c][2] < TF[timeframe][c+1][2])
                        {
                        if(TF[timeframe][strBosCandleIndex][3] > TF[timeframe][c][2]) 
                           {
                           swingNotBosed = true;
                           break;
                           }
                        }   
                     }      
                  }
               if(swingNotBosed) continue;
               for(d = OBIndex - 1, OBRepeated = false; d >= 0 && OB[d][3] != 0; d--)
                  {
                  if(OB[d][3] == j) OBRepeated = true;
                  }
               if(OBRepeated) continue;
               if(OBIndex > 0) 
                  {
                  for(d = OBIndex - 1, lastOBIndex = -1; d >= 0 && OB[d][3] != 0; d--)
                     {
                     if(OB[d][2] == -1) 
                        {
                        if(OB[d][3] < strSweepCandleIndex && OB[d][3] > strBosCandleIndex && (lastOBIndex == -1 || OB[d][1] > OB[lastOBIndex][1]))
                           {
                           lastOBIndex = d;
                           }
                        }
                     }
                  if(lastOBIndex >= 0 && (TF[timeframe][j][1] <= OB[lastOBIndex][1] || TF[timeframe][j][2] <= OB[lastOBIndex][0])) continue;
                  }
               if(replaceOB) OBIndex--;
               if(highestHigh >= TF[timeframe][j][1] && !breaker) continue;
               OB[OBIndex][0] = TF[timeframe][j][2];
               OB[OBIndex][1] = TF[timeframe][j][1];
               OB[OBIndex][2] = -1;
               OB[OBIndex][3] = j;
               OB[OBIndex][4] = strBosCandleIndex;
               OBIndex++;
               replaceOB = true;
               continue;
               }
            }
         }      
      }
   }

void fillFVG(double& FVG[][], int timeframe)
   {
   double lowestLow = TF[timeframe][0][2], highestHigh = TF[timeframe][0][1];
   int i = 0, maxCandlesToFindFVG = 100, FVGIndex = 0;
   
   for(i = 1; i != maxCandlesToFindFVG; i++)
      {
      if(TF[timeframe][i][1] < TF[timeframe][i+2][2] && highestHigh < TF[timeframe][i+2][2])
         {
         FVG[FVGIndex][0] = TF[timeframe][i][1];
         FVG[FVGIndex][1] = TF[timeframe][i+2][2];
         FVG[FVGIndex][2] = -1;
         FVG[FVGIndex][3] = i+1;
         FVGIndex++;
         }
      if(TF[timeframe][i][2] > TF[timeframe][i+2][1] && lowestLow > TF[timeframe][i+2][1])
         {
         FVG[FVGIndex][0] = TF[timeframe][i+2][1];
         FVG[FVGIndex][1] = TF[timeframe][i][2];
         FVG[FVGIndex][2] = 1;
         FVG[FVGIndex][3] = i+1;
         FVGIndex++;
         }
      if(TF[timeframe][i][2] < lowestLow) lowestLow = TF[timeframe][i][2];
      if(TF[timeframe][i][1] > highestHigh) highestHigh = TF[timeframe][i][1];
      }
   }

void sweep(bool& sweepForShort, bool& sweepForLong, int timeframe, bool counterContext, bool visualize = false)
   {
   double bodyLow = 0, lowestLow = TF[timeframe][0][2], bodyHigh = 0, highestHigh = TF[timeframe][0][1];
   double highestSwingHigh = 0, lowestSwingLow = 0;
   int i, p, q, maxCandlesToCountSweepLocal = maxCandlesToCountSweep;
   int maxCandlesForSweepRangeContext = 50;
   
   if(counterContext) maxCandlesToCountSweepLocal = maxCandlesToCountCounterSweep;
   if(visualize) maxCandlesToCountSweepLocal = maxCandlesForSweepRangeContext;
   
   if(TF[timeframe][1][2] < lowestLow) lowestLow = TF[timeframe][1][2];
   if(TF[timeframe][1][1] > highestHigh) highestHigh = TF[timeframe][1][1];
   
   for(i = 3; i != maxCandlesForSweepRangeContext && sweepForLong != true; i++)
      {
      for(q = 1; q < i; q++)
         {
         if(TF[timeframe][q][3] < TF[timeframe][q][0])
            {
            if(TF[timeframe][q][3] < bodyLow || bodyLow == 0) bodyLow = TF[timeframe][q][3];
            }
         else if(TF[timeframe][q][0] < bodyLow || bodyLow == 0) bodyLow = TF[timeframe][q][0];
         }
      if(!isSwingLow(i,timeframe)) continue; 
      if(TF[timeframe][i][2] > bodyLow) continue;
      for(p = 1, lowestSwingLow = 0; p < maxCandlesToCountSweepLocal + 1 && !sweepForLong; p++)
         {
         if(p < i)
            {
            if(TF[timeframe][i][2] < lowestLow) lowestLow = TF[timeframe][i][2];
            }
         else break;
         if(TF[timeframe][i][2] > TF[timeframe][p][2] && TF[timeframe][p+1][2] > TF[timeframe][p][2] && TF[timeframe][p][2] <= lowestLow) 
            {
            for(q = p + 2; q < i - 1; q++) 
               {
               if(isSwingLow(q,timeframe) && (lowestSwingLow == 0 || TF[timeframe][q][2] < lowestSwingLow)) lowestSwingLow = TF[timeframe][q][2];
               }
            if(lowestSwingLow != 0 && TF[timeframe][i][2] > lowestSwingLow) break;
            sweepForLong = true;
            if(visualize)
               {
               lastShortSweep[0] = i;
               lastShortSweep[1] = p;
               lastShortSweep[2] = TF[timeframe][i][2];
               }
            }
         }
      }
   for(i = 3; i != maxCandlesForSweepRangeContext && sweepForShort != true; i++)
      {
      for(q = 1; q < i; q++)
         {
         if(TF[timeframe][q][3] > TF[timeframe][q][0])
            {
            if(TF[timeframe][q][3] > bodyHigh || bodyHigh == 0) bodyHigh = TF[timeframe][q][3];
            }
         else if(TF[timeframe][q][0] > bodyHigh || bodyHigh == 0) bodyHigh = TF[timeframe][q][0];
         }
      if(!isSwingHigh(i,timeframe)) continue; 
      if(TF[timeframe][i][1] < bodyHigh) continue;
      for(p = 1, highestSwingHigh = 0; p < maxCandlesToCountSweepLocal + 1 && !sweepForShort; p++)
         {
         if(p < i) 
            {
            if(TF[timeframe][i][1] > highestHigh) highestHigh = TF[timeframe][i][1];
            }
         else break;   
         if(TF[timeframe][i][1] < TF[timeframe][p][1] && TF[timeframe][p+1][1] < TF[timeframe][p][1] && TF[timeframe][p][1] >= highestHigh) 
            {
            for(q = p + 2; q < i - 1; q++) 
               {
               if(isSwingHigh(q,timeframe) && (highestSwingHigh == 0 || TF[timeframe][q][1] > highestSwingHigh)) highestSwingHigh = TF[timeframe][q][1];
               }
            if(highestSwingHigh != 0 && TF[timeframe][i][1] < highestSwingHigh) break;
            sweepForShort = true;
            if(visualize)
               {
               lastLongSweep[0] = i;
               lastLongSweep[1] = p;
               lastLongSweep[2] = TF[timeframe][i][1];
               }
            }
         }
      }
   }

void FF(bool& shortFVGFF, bool& longFVGFF, int timeframe, bool counterContext)
   {
   double low0 = TF[timeframe][0][2], high0 = TF[timeframe][0][1], high1 = TF[timeframe][1][1], low1 = TF[timeframe][1][2];
   double FFPercentageLocal = FFPercentage, FFlevel = 0, longFVGLow = 0, longFVGHigh = 0, shortFVGLow = 0, shortFVGHigh = 0, highestHigh = 0, lowestLow = 0;
   int i = 0, maxCandlesToFindFVG = 100;
   
   if(counterContext) FFPercentageLocal = CounterFFPercentage;
   
   for(i = 1; i != maxCandlesToFindFVG && (shortFVGFF != true || longFVGFF != true); i++)
      {
      shortFVGLow = TF[timeframe][i][1];
      shortFVGHigh = TF[timeframe][i+2][2];
      longFVGLow = TF[timeframe][i+2][1];
      longFVGHigh = TF[timeframe][i][2];
      
      if(i > 2)
         {
         if(highestHigh == 0 || TF[timeframe][i][1] > highestHigh) highestHigh = TF[timeframe][i][1];
         if(lowestLow == 0 || TF[timeframe][i][2] < lowestLow) lowestLow = TF[timeframe][i][2];
         }
      if(shortFVGLow < shortFVGHigh)
         {
         FFlevel = shortFVGLow + ((shortFVGHigh - shortFVGLow) * (FFPercentageLocal / 100));
         if((highestHigh == 0 || highestHigh < FFlevel) && ((low0 < FFlevel && high0 > FFlevel) || (low1 < FFlevel && high1 > FFlevel))) shortFVGFF = true;
         }
      if(longFVGLow < longFVGHigh)
         {
         FFlevel = longFVGHigh - ((longFVGHigh - longFVGLow) * (FFPercentageLocal / 100));
         if((lowestLow == 0 || lowestLow > FFlevel) && ((low0 < FFlevel && high0 > FFlevel) || (low1 < FFlevel && high1 > FFlevel))) longFVGFF = true;
         }
      }
   }
    
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Premium/Discount Definition------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void fillRangesForPremDisc(double& currentRange[], int timeframe, bool entry = false)
   {
   int i = 0, j = 0;
   double rangeHigh = 0, rangeLow = 0, mid = 0, highestHigh = TF[timeframe][0][1], lowestLow = TF[timeframe][0][2];
   int rangeStartIndex = 0, rangeEndIndex = 0;
   
   for(i = 1; i <= lastStructureBosIndex; i++) //         НАХОДИМ ХХ и ЛЛ от последнего слома включительно
      {
      if(TF[timeframe][i][1] > highestHigh) 
         {
         highestHigh = TF[timeframe][i][1];
         if(entry && lastStructure == -1) rangeEndIndex = i;
         }
      if(TF[timeframe][i][2] < lowestLow) 
         {
         lowestLow = TF[timeframe][i][2];
         if(entry && lastStructure == 1) rangeEndIndex = i;
         }
      }
   
   if(lastStructure == 1)
      {
      for(j = 1; j != MaxCandlesOfRangeWidth; j++)
         {
         if(j >= lastStructureBosIndex)
            {
            if(rangeLow == 0)
               {
               if((TF[timeframe][j][2] < TF[timeframe][j-1][2] && TF[timeframe][j][2] < TF[timeframe][j+1][2]) || (TF[timeframe][j][2] <= TF[timeframe][j-1][2] && TF[timeframe][j][2] <= TF[timeframe][j+1][2] && TF[timeframe][j+1][2] < TF[timeframe][j+2][2]))
                  {
                  rangeLow = TF[timeframe][j][2];
                  rangeStartIndex = j;
                  }
               }   
            }         
         if(rangeHigh == 0 || TF[timeframe][j][1] > rangeHigh)
            {
            if((TF[timeframe][j][1] > TF[timeframe][j-1][1] && TF[timeframe][j][1] > TF[timeframe][j+1][1]) || (TF[timeframe][j][1] >= TF[timeframe][j-1][1] && TF[timeframe][j][1] >= TF[timeframe][j+1][1] && TF[timeframe][j+1][1] > TF[timeframe][j+2][1]))
               {
               rangeHigh = TF[timeframe][j][1];
               }
            }   
               
         if(rangeLow != 0 && rangeHigh != 0 && highestHigh == rangeHigh)
            {
            mid = rangeLow + (rangeHigh - rangeLow) / 2;
            break;
            }
         }
      if(mid != 0)
         {
         currentRange[0] = rangeLow;
         currentRange[1] = rangeHigh;
         currentRange[2] = entry ? rangeStartIndex : mid;
         currentRange[3] = entry ? rangeEndIndex : 1;    
         }
      }   
   else if(lastStructure == -1)
      {
      for(j = 1; j != MaxCandlesOfRangeWidth; j++)
         {
         if(j >= lastStructureBosIndex)
            {
            if(rangeHigh == 0)
               {
               if((TF[timeframe][j][1] > TF[timeframe][j-1][1] && TF[timeframe][j][1] > TF[timeframe][j+1][1]) || (TF[timeframe][j][1] >= TF[timeframe][j-1][1] && TF[timeframe][j][1] >= TF[timeframe][j+1][1] && TF[timeframe][j+1][1] > TF[timeframe][j+2][1]))
                  {
                  rangeHigh = TF[timeframe][j][1];
                  rangeStartIndex = j;
                  }
               }   
            }      
         if(rangeLow == 0 || TF[timeframe][j][2] > rangeLow)
            {
            if((TF[timeframe][j][2] < TF[timeframe][j-1][2] && TF[timeframe][j][2] < TF[timeframe][j+1][2]) || (TF[timeframe][j][2] <= TF[timeframe][j-1][2] && TF[timeframe][j][2] <= TF[timeframe][j+1][2] && TF[timeframe][j+1][2] < TF[timeframe][j+2][2]))
               {
               rangeLow = TF[timeframe][j][2];
               }
            }   
               
         if(rangeLow != 0 && rangeHigh != 0 && lowestLow == rangeLow)
            {
            mid = rangeLow + (rangeHigh - rangeLow) / 2;
            break;
            }
         }
      if(mid != 0)
         {
         currentRange[0] = rangeLow;
         currentRange[1] = rangeHigh;
         currentRange[2] = entry ? rangeStartIndex : mid;
         currentRange[3] = entry ? rangeEndIndex : -1;       
         }
      }
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Trend Definition-------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
double lastRangeSwingHigh = 0, lastRangeSwingLow = 0;
int lastRangeSwingHighIndex = 0, lastRangeSwingLowIndex = 0, lastRangeBosIndex = 0;
void fillRanges(int timeframe, bool visualize = false)
   {
   int i = 1, j = 0, k = 0, q = 0, cycle = 0;
   int start = MaxCandlesToCountRanges, localTrend = 0, candlesAfterLastRangeBosCounter = 0;
   int lastSwingHighIndex = 0, lastSwingLowIndex = 0;
   int higherHighIndex = 0, lowerLowIndex = 0;
   double lastSwingLowBuffer = 0, lastSwingHighBuffer = 0;
   double highestHigh = 0, lowestLow = 0;
   double lastSwingHigh = 0, lastSwingLow = 0, localLowestClose = 0, localHighestClose = 0;
   bool localWaitForBos = false, localWaitForLow = false, localWaitForHigh = false, swingFound = false;
   
   for(cycle = 1; i > 0; cycle++)
      {
      lastSwingHigh = 0;
      lastSwingLow = 0;
      lastSwingHighIndex = 0;
      lastSwingLowIndex = 0;
      lastRangeSwingHigh = 0;
      lastRangeSwingLow = 0;
      lastRangeSwingHighIndex = 0;
      lastRangeSwingLowIndex = 0;
      lastRangeBosIndex = 0;
      localLowestClose = 0;
      localHighestClose = 0;
      higherHighIndex = 0;
      lowerLowIndex = 0;
      lastSwingLowBuffer = 0;
      lastSwingHighBuffer = 0;
      localWaitForBos = false;
      localWaitForLow = false;
      localWaitForHigh = false;
      swingFound = false;
      candlesAfterLastRangeBosCounter = 0;
      for(i = start; i >= 0; i--)
         {
         if(i == 0) break;
         if(lastRangeSwingHigh == 0)
            {
            if((TF[timeframe][i][1] > TF[timeframe][i + 1][1] || (TF[timeframe][i][1] >= TF[timeframe][i + 1][1] && TF[timeframe][i + 1][1] > TF[timeframe][i + 2][1])) && TF[timeframe][i][1] > TF[timeframe][i - 1][1])
               {
               lastSwingHighIndex = i;
               lastSwingHigh = TF[timeframe][lastSwingHighIndex][1];
               lastRangeSwingLowIndex = 0;
               lastRangeSwingLow = 0;
               lastSwingLowIndex = 0;
               lastSwingLow = 0;
               for(j = lastSwingHighIndex - 1; lastSwingHighIndex - j < MaxCandlesOfRangeWidth && j > 0; j--)
                  {
                  if(TF[timeframe][j][3] > lastSwingHigh)
                     {
                     lastRangeBosIndex = j;
                     break;
                     }
                  }
               if(lastRangeBosIndex != 0)   
                  {
                  for(j = lastSwingHighIndex - 1; j >= lastRangeBosIndex; j--)
                     {
                     if((TF[timeframe][j][2] < TF[timeframe][j + 1][2] || (TF[timeframe][j][2] <= TF[timeframe][j + 1][2] && TF[timeframe][j + 1][2] < TF[timeframe][j + 2][2])) && TF[timeframe][j][2] < TF[timeframe][j - 1][2])
                        {
                        if(lastRangeSwingLow == 0 || TF[timeframe][j][2] < lastRangeSwingLow)
                           {
                           lastRangeSwingLowIndex = j;
                           lastRangeSwingLow = TF[timeframe][lastRangeSwingLowIndex][2];
                           lastSwingLowIndex = j;
                           lastSwingLow = TF[timeframe][lastRangeSwingLowIndex][2];
                           }
                        }
                     }
                  if(lastRangeSwingLow == 0 || lastSwingHighIndex - lastSwingLowIndex - 1 < MinCandlesOfRangeWidth) 
                     {
                     lastRangeBosIndex = 0;
                     continue;
                     }
                  highestHigh = 0;
                  for(j = lastRangeSwingLowIndex + 1; j < lastSwingHighIndex; j++)
                     {
                     if(highestHigh == 0 || TF[timeframe][j][1] > highestHigh) highestHigh = TF[timeframe][j][1];
                     if(TF[timeframe][j][1] >= highestHigh && (TF[timeframe][j][1] < lastSwingHigh || TF[timeframe][j][1] > lastSwingHigh) && (TF[timeframe][j][1] > TF[timeframe][j + 1][1] || (TF[timeframe][j][1] >= TF[timeframe][j + 1][1] && TF[timeframe][j + 1][1] > TF[timeframe][j + 2][1])) && TF[timeframe][j][1] > TF[timeframe][j - 1][1])
                        {
                        lastSwingHighIndex = j;
                        lastSwingHigh = TF[timeframe][lastSwingHighIndex][1];
                        lastRangeBosIndex = 0;
                        for(k = lastSwingHighIndex - 1; lastSwingHighIndex - k < MaxCandlesOfRangeWidth && k > 0; k--)
                           {
                           if(k > lastRangeSwingLowIndex) continue;
                           if(TF[timeframe][k][3] > lastSwingHigh)
                              {
                              lastRangeBosIndex = k;
                              break;
                              }
                           }
                        break;
                        }
                     }
                  if(lastRangeBosIndex != 0 && lastRangeSwingLow != 0 && lastSwingHighIndex - lastSwingLowIndex - 1 >= MinCandlesOfRangeWidth && TF[timeframe][lastSwingLowIndex][2] < TF[timeframe][lastSwingHighIndex][2])   
                     {
                     lastRangeSwingHighIndex = lastSwingHighIndex;
                     lastRangeSwingHigh = TF[timeframe][lastSwingHighIndex][1];
                     i = lastRangeBosIndex + 1;
                     
                     localTrend = 1;
                     if(visualize) addRange(localTrend, lastRangeSwingHighIndex, lastRangeSwingLowIndex, lastRangeBosIndex); 
                     localWaitForBos = false;
                     localWaitForLow = false;
                     localWaitForHigh = false;
                     swingFound = false;
                     continue;
                     }
                  else lastRangeBosIndex = 0;
                  }
               }
            }
         if(lastRangeSwingLow == 0)
            {
            if((TF[timeframe][i][2] < TF[timeframe][i + 1][2] || (TF[timeframe][i][2] <= TF[timeframe][i + 1][2] && TF[timeframe][i + 1][2] < TF[timeframe][i + 2][2])) && TF[timeframe][i][2] < TF[timeframe][i - 1][2])
               {
               lastSwingLowIndex = i;
               lastSwingLow = TF[timeframe][lastSwingLowIndex][2];
               lastRangeSwingHighIndex = 0;
               lastRangeSwingHigh = 0;
               lastSwingHighIndex = 0;
               lastSwingHigh = 0;
               for(j = lastSwingLowIndex - 1; lastSwingLowIndex - j < MaxCandlesOfRangeWidth && j > 0; j--)
                  {
                  if(TF[timeframe][j][3] < lastSwingLow)
                     {
                     lastRangeBosIndex = j;
                     break;
                     }
                  }
               if(lastRangeBosIndex != 0)   
                  {
                  for(j = lastSwingLowIndex - 1; j >= lastRangeBosIndex; j--)
                     {
                     if((TF[timeframe][j][1] > TF[timeframe][j + 1][1] || (TF[timeframe][j][1] >= TF[timeframe][j + 1][1] && TF[timeframe][j + 1][1] > TF[timeframe][j + 2][1])) && TF[timeframe][j][1] > TF[timeframe][j - 1][1])
                        {
                        if(lastRangeSwingHigh == 0 || TF[timeframe][j][1] > lastRangeSwingHigh)
                           {
                           lastRangeSwingHighIndex = j;
                           lastRangeSwingHigh = TF[timeframe][lastRangeSwingHighIndex][1];
                           lastSwingHighIndex = j;
                           lastSwingHigh = TF[timeframe][lastRangeSwingHighIndex][1];
                           }
                        }
                     }
                  if(lastRangeSwingHigh == 0 || lastSwingLowIndex - lastSwingHighIndex - 1 < MinCandlesOfRangeWidth) 
                     {
                     lastRangeBosIndex = 0;
                     continue;
                     }
                  lowestLow = 0;
                  for(j = lastRangeSwingHighIndex + 1; j < lastSwingLowIndex; j++)
                     {
                     if(lowestLow == 0 || TF[timeframe][j][2] < lowestLow) lowestLow = TF[timeframe][j][2];
                     if(TF[timeframe][j][2] <= lowestLow && (TF[timeframe][j][2] > lastSwingLow || TF[timeframe][j][2] < lastSwingLow) && (TF[timeframe][j][2] < TF[timeframe][j + 1][2] || (TF[timeframe][j][2] <= TF[timeframe][j + 1][2] && TF[timeframe][j + 1][2] < TF[timeframe][j + 2][2])) && TF[timeframe][j][2] < TF[timeframe][j - 1][2])
                        {
                        lastSwingLowIndex = j;
                        lastSwingLow = TF[timeframe][lastSwingLowIndex][2];
                        lastRangeBosIndex = 0;
                        for(k = lastSwingLowIndex - 1; lastSwingLowIndex - k < MaxCandlesOfRangeWidth && k > 0; k--)
                           {
                           if(k > lastRangeSwingHighIndex) continue;
                           if(TF[timeframe][k][3] < lastSwingLow)
                              {
                              lastRangeBosIndex = k;
                              break;
                              }
                           }
                        break;
                        }
                     }
                  if(lastRangeBosIndex != 0 && lastRangeSwingHigh != 0 && lastSwingLowIndex - lastSwingHighIndex - 1 >= MinCandlesOfRangeWidth && TF[timeframe][lastSwingHighIndex][1] > TF[timeframe][lastSwingLowIndex][1])   
                     {
                     lastRangeSwingLowIndex = lastSwingLowIndex;
                     lastRangeSwingLow = TF[timeframe][lastSwingLowIndex][2];
                     i = lastRangeBosIndex + 1;
                     
                     localTrend = -1;
                     if(visualize) addRange(localTrend, lastRangeSwingLowIndex, lastRangeSwingHighIndex, lastRangeBosIndex); 
                     localWaitForBos = false;
                     localWaitForLow = false;
                     localWaitForHigh = false;
                     swingFound = false;
                     continue;
                     }
                  else lastRangeBosIndex = 0;
                  }
               }
            }
            
         if(lastRangeSwingLow != 0 && lastRangeSwingHigh != 0) 
            {
            if(candlesAfterLastRangeBosCounter > MaxCandlesOfRangeWidth)
               {
               start = lastRangeBosIndex;
               break;
               }
            if(localTrend == 1)
               {
               if(i != lastRangeBosIndex && TF[timeframe][i][3] > lastSwingHigh)
                  {
                  if(localWaitForBos)
                     {
                     if(TF[timeframe][i][2] < lastSwingLow)
                        {
                        lastSwingLowIndex = i;
                        lastSwingLow = TF[timeframe][i][2];
                        }
                     lastRangeSwingHighIndex = lastSwingHighIndex;
                     lastRangeSwingHigh = lastSwingHigh;
                     
                     lastRangeSwingLowIndex = lastSwingLowIndex;
                     lastRangeSwingLow = lastSwingLow;
                     
                     lastRangeBosIndex = i;
                     
                     localTrend = 1;
                     if(visualize) addRange(localTrend, lastSwingHighIndex, lastSwingLowIndex, lastRangeBosIndex);
                     TFTrend[timeframe] = localTrend; 
                     
                     candlesAfterLastRangeBosCounter = 0;
                     localWaitForBos = false;
                     localWaitForLow = false;
                     swingFound = false;
                     higherHighIndex = 0;
                     lastSwingLowBuffer = 0;
                     i++;
                     continue;
                     }
                  localWaitForBos = false;
                  localWaitForLow = false;
                  swingFound = false;
                  higherHighIndex = 0;
                  lastSwingLowBuffer = 0;
                  }   
               if(i > 1)
                  { 
                  if((TF[timeframe][i][1] > TF[timeframe][i + 1][1] || (TF[timeframe][i][1] >= TF[timeframe][i + 1][1] && TF[timeframe][i + 1][1] > TF[timeframe][i + 2][1])) && TF[timeframe][i][1] > TF[timeframe][i - 1][1])
                     {
                     if(TF[timeframe][i][1] > lastSwingHigh)
                        {
                        if(localWaitForLow && localWaitForBos)
                           {
                           if(higherHighIndex == 0 || TF[timeframe][i][1] > TF[timeframe][higherHighIndex][1])
                              {
                              higherHighIndex = i;
                              lastSwingLowBuffer = 0;
                              }
                           }
                        else
                           { 
                           lastSwingHighIndex = i;
                           lastSwingHigh = TF[timeframe][i][1];
                           localWaitForLow = true;
                           }   
                        }
                     }
                  if(localWaitForLow && lastSwingHighIndex != i && TF[timeframe][i][2] < lastSwingHigh && TF[timeframe][i][2] < TF[timeframe][lastSwingHighIndex][2] && i < lastRangeBosIndex && (TF[timeframe][i][2] < TF[timeframe][i + 1][2] || (TF[timeframe][i][2] <= TF[timeframe][i + 1][2] && TF[timeframe][i + 1][2] < TF[timeframe][i + 2][2])) && TF[timeframe][i][2] < TF[timeframe][i - 1][2] && TF[timeframe][i][3] > lastRangeSwingLow) 
                     {
                     if(!swingFound || TF[timeframe][i][2] < lastSwingLow || higherHighIndex != 0)   
                        {
                        if(higherHighIndex != 0)
                           {
                           if(lastSwingLowBuffer == 0 || TF[timeframe][i][2] < lastSwingLowBuffer) lastSwingLowBuffer = TF[timeframe][i][2];
                           if(higherHighIndex - i - 1 >= MinCandlesOfRangeWidth && TF[timeframe][i][2] <= lastSwingLowBuffer)
                              {
                              lastSwingLowIndex = i;
                              lastSwingLow = TF[timeframe][i][2];
                              lastSwingHighIndex = higherHighIndex;
                              lastSwingHigh = TF[timeframe][higherHighIndex][1];
                              higherHighIndex = 0;
                              lastSwingLowBuffer = 0;
                              }
                           else if(TF[timeframe][i][2] < lastSwingLow && lastSwingHighIndex - i - 1 >= MinCandlesOfRangeWidth) 
                              {
                              lastSwingLowIndex = i;
                              lastSwingLow = TF[timeframe][i][2];
                              }  
                           }
                        else 
                           {
                           lastSwingLowIndex = i;
                           lastSwingLow = TF[timeframe][i][2];
                           if(lastSwingHighIndex - i - 1 >= MinCandlesOfRangeWidth) localWaitForBos = true;
                           }
                        }
                     swingFound = true;
                     }
                  }  
               if(TF[timeframe][i][3] < lastRangeSwingLow)
                  {
                  for(j = lastRangeSwingLowIndex - 1; j >= i; j--)
                     {
                     if(TF[timeframe][j][1] > lastSwingHigh)
                        {
                        lastSwingHighIndex = j;
                        lastSwingHigh = TF[timeframe][j][1];
                        }
                     }
                  
                  for(j = lastRangeSwingLowIndex - 1; j > i; j--)
                     {
                     if(j < lastSwingHighIndex) continue;
                     if(TF[timeframe][j][2] < lastRangeSwingLow && ((TF[timeframe][j][2] < TF[timeframe][j + 1][2] || (TF[timeframe][j][2] <= TF[timeframe][j + 1][2] && TF[timeframe][j + 1][2] < TF[timeframe][j + 2][2])) && TF[timeframe][j][2] < TF[timeframe][j - 1][2]))
                        {
                        lastRangeSwingLowIndex = j;
                        lastRangeSwingLow = TF[timeframe][j][2];
                        }
                     }
                  if(TF[timeframe][i][3] >= lastRangeSwingLow) continue;
                     
                  lastSwingLow = lastRangeSwingLow;
                  lastSwingLowIndex = lastRangeSwingLowIndex;
                  
                  lastRangeSwingHighIndex = lastSwingHighIndex;
                  lastRangeSwingHigh = lastSwingHigh;
                  
                  lastRangeBosIndex = i;
                  
                  localTrend = -1;
                  if(visualize) addRange(localTrend, lastSwingLowIndex, lastSwingHighIndex, lastRangeBosIndex);
                  TFTrend[timeframe] = localTrend; 
                  
                  candlesAfterLastRangeBosCounter = 0;
                  localWaitForBos = false;
                  localWaitForLow = false;
                  swingFound = false;
                  higherHighIndex = 0;
                  lastSwingLowBuffer = 0;
                  i++;
                  continue;
                  }
               else if(TF[timeframe][i][2] < lastRangeSwingLow) TFTrend[timeframe] = 0;
               }
            else if(localTrend == -1)
               {
               if(i != lastRangeBosIndex && TF[timeframe][i][3] < lastSwingLow)
                  {
                  if(localWaitForBos)
                     {
                     if(TF[timeframe][i][1] > lastSwingHigh)
                        {
                        lastSwingHighIndex = i;
                        lastSwingHigh = TF[timeframe][i][1];
                        }
                     lastRangeSwingLowIndex = lastSwingLowIndex;
                     lastRangeSwingLow = lastSwingLow;
                     
                     lastRangeSwingHighIndex = lastSwingHighIndex;
                     lastRangeSwingHigh = lastSwingHigh;
                     
                     lastRangeBosIndex = i;
                     
                     localTrend = -1;
                     if(visualize) addRange(localTrend, lastSwingLowIndex, lastSwingHighIndex, lastRangeBosIndex);
                     TFTrend[timeframe] = localTrend; 
                     
                     candlesAfterLastRangeBosCounter = 0;
                     localWaitForBos = false;
                     localWaitForHigh = false;
                     swingFound = false;
                     lowerLowIndex = 0;
                     lastSwingHighBuffer = 0;
                     i++;
                     continue;
                     }
                  localWaitForBos = false;
                  localWaitForHigh = false;  
                  swingFound = false; 
                  lowerLowIndex = 0;
                  lastSwingHighBuffer = 0;
                  }   
               if(i > 1)
                  {
                  if((TF[timeframe][i][2] < TF[timeframe][i + 1][2] || (TF[timeframe][i][2] <= TF[timeframe][i + 1][2] && TF[timeframe][i + 1][2] < TF[timeframe][i + 2][2])) && TF[timeframe][i][2] < TF[timeframe][i - 1][2])
                     {
                     if(TF[timeframe][i][2] < lastSwingLow)
                        {
                        if(localWaitForHigh && localWaitForBos)
                           {
                           if(lowerLowIndex == 0 || TF[timeframe][i][2] < TF[timeframe][lowerLowIndex][2])
                              {
                              lowerLowIndex = i;
                              lastSwingHighBuffer = 0;
                              }
                           }
                        else
                           { 
                           lastSwingLowIndex = i;
                           lastSwingLow = TF[timeframe][i][2];
                           localWaitForHigh = true;
                           } 
                        }
                     }
                  if(localWaitForHigh && lastSwingLowIndex != i && TF[timeframe][i][1] > lastSwingLow && TF[timeframe][i][1] > TF[timeframe][lastSwingLowIndex][1] && i < lastRangeBosIndex && (TF[timeframe][i][1] > TF[timeframe][i + 1][1] || (TF[timeframe][i][1] >= TF[timeframe][i + 1][1] && TF[timeframe][i + 1][1] > TF[timeframe][i + 2][1])) && TF[timeframe][i][1] > TF[timeframe][i - 1][1] && TF[timeframe][i][3] < lastRangeSwingHigh) 
                     {
                     if(!swingFound || TF[timeframe][i][1] > lastSwingHigh || lowerLowIndex != 0)
                        {
                        if(lowerLowIndex != 0)
                           {
                           if(lastSwingHighBuffer == 0 || TF[timeframe][i][1] > lastSwingHighBuffer) lastSwingHighBuffer = TF[timeframe][i][1];
                           if(lowerLowIndex - i - 1 >= MinCandlesOfRangeWidth && TF[timeframe][i][1] >= lastSwingHighBuffer)
                              {
                              lastSwingHighIndex = i;
                              lastSwingHigh = TF[timeframe][i][1];
                              lastSwingLowIndex = lowerLowIndex;
                              lastSwingLow = TF[timeframe][lowerLowIndex][2];
                              lowerLowIndex = 0;
                              lastSwingHighBuffer = 0;
                              }
                           else if(TF[timeframe][i][1] > lastSwingHigh && lastSwingLowIndex - i - 1 >= MinCandlesOfRangeWidth) 
                              {
                              lastSwingHighIndex = i;
                              lastSwingHigh = TF[timeframe][i][1];
                              }  
                           }
                        else 
                           {
                           lastSwingHighIndex = i;
                           lastSwingHigh = TF[timeframe][i][1];
                           if(lastSwingLowIndex - i - 1 >= MinCandlesOfRangeWidth) localWaitForBos = true;
                           }
                        }
                     swingFound = true;
                     }
                  }  
               if(TF[timeframe][i][3] > lastRangeSwingHigh)
                  {
                  for(j = lastRangeSwingHighIndex - 1; j >= i; j--)
                     {
                     if(TF[timeframe][j][2] < lastSwingLow)
                        {
                        lastSwingLowIndex = j;
                        lastSwingLow = TF[timeframe][j][2];
                        }
                     }
                  
                  for(j = lastRangeSwingHighIndex - 1; j > i; j--)
                     {
                     if(j < lastSwingLowIndex) continue;
                     if(TF[timeframe][j][1] > lastRangeSwingHigh && ((TF[timeframe][j][1] > TF[timeframe][j + 1][1] || (TF[timeframe][j][1] >= TF[timeframe][j + 1][1] && TF[timeframe][j + 1][1] > TF[timeframe][j + 2][1])) && TF[timeframe][j][1] > TF[timeframe][j - 1][1]))
                        {
                        lastRangeSwingHighIndex = j;
                        lastRangeSwingHigh = TF[timeframe][j][1];
                        }
                     }
                  if(TF[timeframe][i][3] <= lastRangeSwingHigh) continue;
                   
                  lastSwingHigh = lastRangeSwingHigh;
                  lastSwingHighIndex = lastRangeSwingHighIndex;
                  
                  lastRangeSwingLowIndex = lastSwingLowIndex;
                  lastRangeSwingLow = lastSwingLow;
                  
                  lastRangeBosIndex = i;
                  
                  localTrend = 1;
                  if(visualize) addRange(localTrend, lastSwingHighIndex, lastSwingLowIndex, lastRangeBosIndex);
                  TFTrend[timeframe] = localTrend; 
                  candlesAfterLastRangeBosCounter = 0;
                  localWaitForBos = false;
                  localWaitForHigh = false;
                  swingFound = false;
                  lowerLowIndex = 0;
                  lastSwingHighBuffer = 0;
                  i++;
                  continue;
                  }
               else if(TF[timeframe][i][1] > lastRangeSwingHigh) TFTrend[timeframe] = 0;
               }
            candlesAfterLastRangeBosCounter++;     
            } 
         }
      }
   }

void addRange(int direction, int start, int end, int bosIndex)
   {
   static int i;
   for(i = maxPOICount - 1; i > 0; i--)
      {
      if(ranges[i-1][0] == 0) continue;
      ranges[i][0] = ranges[i-1][0];
      ranges[i][1] = ranges[i-1][1];
      ranges[i][2] = ranges[i-1][2];
      ranges[i][3] = ranges[i-1][3];
      }
   ranges[0][0] = start;
   ranges[0][1] = end;
   ranges[0][2] = direction;
   ranges[0][3] = bosIndex;
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Structure Definition-------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void fillStructure(int& structure[][], int timeframe)
   {
   double swingHigh, swingLow, closeForLowMSB = 0, closeForHighMSB = 0;
   int p = 0, structureIntervalIndex = 0, latestBosIndex = 0; 
   int firstHighMSBCandleIndex = 0, firstLowMSBCandleIndex = 0;
   double highestSwingHigh = 0, lowestSwingLow = 0;
   
   for(int i = 3; i != maxCandlesForStructureIntervals && structureIntervalIndex < maxPOICount - 1; i++)
      {
      if(isSwingHigh(i, timeframe)) 
         {
         swingHigh = TF[timeframe][i][1];
         closeForHighMSB = 0;
         for(p = i - 2; p > 0; p--)
            {
            if(swingHigh < TF[timeframe][p][3]) 
               {
               closeForHighMSB = TF[timeframe][p][3];
               firstHighMSBCandleIndex = p;
               break;
               }
            }
         for(p = i - 2, highestSwingHigh = swingHigh; p > firstHighMSBCandleIndex; p--)
            {
            if(isSwingHigh(p, timeframe) && TF[timeframe][p][1] > highestSwingHigh) highestSwingHigh = TF[timeframe][p][1];
            }   
         if(highestSwingHigh > swingHigh && highestSwingHigh > closeForHighMSB) continue;
         if(closeForHighMSB != 0 && closeForHighMSB > swingHigh) 
            {
            structure[structureIntervalIndex][0] = 1;
            structure[structureIntervalIndex][1] = firstHighMSBCandleIndex;
            structure[structureIntervalIndex][2] = i;
            structureIntervalIndex++;
            if(latestBosIndex == 0 || firstHighMSBCandleIndex < latestBosIndex)
               {
               latestBosIndex = firstHighMSBCandleIndex;
               lastStructure = 1;
               lastStructureBosIndex = firstHighMSBCandleIndex;
               }
            }
         }   
      if(isSwingLow(i, timeframe))
         {
         swingLow = TF[timeframe][i][2];
         closeForLowMSB = 0;
         for(p = i - 2; p > 0; p--)
            {
            if(swingLow > TF[timeframe][p][3]) 
               {
               closeForLowMSB = TF[timeframe][p][3];
               firstLowMSBCandleIndex = p;
               break;
               }
            }
         for(p = i - 2, lowestSwingLow = swingLow; p > firstLowMSBCandleIndex; p--)
            {
            if(isSwingLow(p, timeframe) && TF[timeframe][p][2] < lowestSwingLow) lowestSwingLow = TF[timeframe][p][1];
            }   
         if(lowestSwingLow < swingLow && lowestSwingLow < closeForLowMSB) continue;
         if(closeForLowMSB != 0 && closeForLowMSB < swingLow) 
            {
            structure[structureIntervalIndex][0] = -1;
            structure[structureIntervalIndex][1] = firstLowMSBCandleIndex;
            structure[structureIntervalIndex][2] = i;
            structureIntervalIndex++;
            if(latestBosIndex == 0 || firstLowMSBCandleIndex < latestBosIndex)
               {
               latestBosIndex = firstLowMSBCandleIndex;
               lastStructure = -1;
               lastStructureBosIndex = firstLowMSBCandleIndex;
               }
            }
         }
      }
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Capture Info about Opened and Closed Orders--------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/ 
  
void newOrder(double limit, double stopLoss, double takeProfit, int indexFormed, int timeframeFormed, int limitIndex, int tf)
   {
   Order localOrder;
   
   localOrder.ticket = 0;
   localOrder.buy = stopLoss > takeProfit ? false : true;
   localOrder.formationTime = IndexToTime(indexFormed - 1,timeframeFormed);
   localOrder.limitCandleTime = IndexToTime(limitIndex,timeframeFormed);
   localOrder.limit = limit;
   localOrder.stopLoss = stopLoss;
   localOrder.takeProfit = takeProfit;
   localOrder.fillTime = 0;
   localOrder.TPTime = 0;
   localOrder.SLTime = 0;
   localOrder.profit = 0;
   localOrder.win = 2;
   localOrder.timeframe = tf;
   
   orderIndex = ArraySize(orders);
   ArrayResize(orders, orderIndex + 1);
   orders[orderIndex] = localOrder;
   }

int addInvalidOrder(orderInvalidationReason code, double limit, double stopLoss, bool finalTry)
   {
   if(!finalTry) return 0;
   invalidOrder localOrder;
   
   localOrder.id = (int) StringToInteger(IntegerToString((int) (limit * pow(10,tickDigits))) + IntegerToString((int) (stopLoss * pow(10,tickDigits))));
   localOrder.code = code;
   
   if(ArraySize(invalidOrders) > 0)
      {
      for(int i = ArraySize(invalidOrders) - 1; ArraySize(invalidOrders) - i < 10 && i >= 0; i--)
         {
         if(invalidOrders[i].id == localOrder.id) return 0;
         }
      }
   
   invalidOrderIndex = ArraySize(invalidOrders);
   
   ArrayResize(invalidOrders, invalidOrderIndex + 1);
   invalidOrders[invalidOrderIndex] = localOrder;
   return 0;
   }
   
void updateOrders()
   {
   static ulong lastClosedPosId = 0, localClosedPosId = 0;
   static int DealsPrev = 0, PositionsPrev = 0, OrdersPrev = 0;
   static double priceOut = 0;
   ulong dealTicket, posId, orderTicket;
   int i, j;
   HistorySelect(0,TimeCurrent());
   if(DealsPrev < HistoryDealsTotal() || PositionsPrev != PositionsTotal())
      {
      for(i = 1; i < HistoryDealsTotal(); i++)
         {
         dealTicket = HistoryDealGetTicket(HistoryDealsTotal()-i);
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (int) orderMagicNumber) continue;
         posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posId == lastClosedPosId) break;
         for(j = 0; j < ArraySize(orders); j++)
            {
            if(orders[orderIndex - j].ticket == posId) break;
            }
         if(j == ArraySize(orders)) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
            if(partial && PositionSelectByTicket(posId)) continue;
            if(orders[orderIndex - j].win != 2) continue;
            orders[orderIndex - j].profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            if(HistoryDealGetDouble(dealTicket, DEAL_PROFIT) < 0)
               {
               orders[orderIndex - j].win = 0;
               orders[orderIndex - j].SLTime = (datetime) HistoryDealGetInteger(dealTicket, DEAL_TIME);
               }  
            else
               {
               orders[orderIndex - j].win = 1;
               orders[orderIndex - j].TPTime = (datetime) HistoryDealGetInteger(dealTicket, DEAL_TIME);
               } 
            if(!live) analyticsWindowVisualize(orderIndex - j);   
            localClosedPosId = posId;
            priceOut = 0;
            if(breakeven && ((orders[orderIndex - j].buy && HistoryDealGetDouble(dealTicket, DEAL_PRICE) < orders[orderIndex - j].takeProfit) 
               || 
               (!orders[orderIndex - j].buy && HistoryDealGetDouble(dealTicket, DEAL_PRICE) > orders[orderIndex - j].takeProfit)))
               priceOut = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            if(trail) priceOut = HistoryDealGetDouble(dealTicket, DEAL_PRICE);   
            posUpdate(orderIndex - j, priceOut);
            }
         else if(HistoryDealGetInteger(dealTicket, DEAL_REASON) == DEAL_REASON_EXPERT && orders[orderIndex - j].fillTime == 0)
            {
            orders[orderIndex - j].fillTime = (datetime) HistoryDealGetInteger(dealTicket, DEAL_TIME);
            posUpdate(orderIndex - j);
            }
         }  
      lastClosedPosId = localClosedPosId;
      }
   if(OrdersTotal() < OrdersPrev)
      {
      for(i = 1; i < HistoryOrdersTotal(); i++)
         {
         orderTicket = HistoryOrderGetTicket(HistoryOrdersTotal()-i);
         if(HistoryOrderGetInteger(orderTicket, ORDER_MAGIC) != (int) orderMagicNumber) continue;
         if(HistoryOrderGetInteger(orderTicket, ORDER_STATE) != ORDER_STATE_CANCELED && HistoryOrderGetInteger(orderTicket, ORDER_STATE) != ORDER_STATE_EXPIRED) break;
         for(j = 0; j < ArraySize(orders); j++)
            {
            if(orders[orderIndex - j].ticket == orderTicket) break;
            }
         if(j == ArraySize(orders)) continue;
         posUpdate(orderIndex - j);
         }
      }   
   DealsPrev = HistoryDealsTotal();
   PositionsPrev = PositionsTotal();
   OrdersPrev = OrdersTotal();
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------OnInit Functions-----------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void defineTimeframes()
   {
   int tfCounter = 0, i;
   string values[], stringTfs = "";
   
   ArrayResize(tfs,1);
   tfs[0] = 1;
   tfCounter++;
   
   if(entrySetup == sweepBos)  
      {
      if(additionalTF == none)
         {
         Print("Please select a BOS timeframe to test Sweep+BOS setups.");
         ExpertRemove();
         return;
         }
      additionalTimeframe = (int) additionalTF;
      addTF(additionalTimeframe,tfCounter);
      if((int) entry1 / additionalTimeframe * maxCandlesForSweepToBeValid > maxAggregatedCandles - 100 || (int) entry2 / additionalTimeframe * maxCandlesForSweepToBeValid > maxAggregatedCandles - 100 || (int) entry3 / additionalTimeframe * maxCandlesForSweepToBeValid > maxAggregatedCandles - 100)
         {
         Print("Difference between the Sweep and BOS timeframes is too big. \nPlease, select a lower BOS timeframe or reduce the number of valid sweep candles in Technical Details tab.");
         ExpertRemove();
         return;
         }
      }
   
   if(entry1 != none) stringTfs += (string) entry1;
   if(entry2 != none) stringTfs += stringTfs == "" ? (string) entry2 : "," + (string) entry2;
   if(entry3 != none) stringTfs += stringTfs == "" ? (string) entry3 : "," + (string) entry3;
   StringSplit(stringTfs, ',', values);
   addTF(values, entryTfs, tfCounter);
   ArraySort(entryTfs);
   stringTfs = "";
   //if(bosTimeframe > sweepTimeframe) TesterStop(); // remove for bos > sweep
   
   if(structureSyncMode != off)
      {   
      if(structure1 != none) stringTfs += (string) structure1;
      if(structure2 != none) stringTfs += stringTfs == "" ? (string) structure2 : "," + (string) structure2;
      if(structure3 != none) stringTfs += stringTfs == "" ? (string) structure3 : "," + (string) structure3;
      StringSplit(stringTfs, ',', values);
      addTF(values, strSyncTfs, tfCounter);
      }  
   stringTfs = "";
   if(trendSyncMode != off)
      {   
      if(trend1 != none) stringTfs += (string) trend1;
      if(trend2 != none) stringTfs += stringTfs == "" ? (string) trend2 : "," + (string) trend2;
      if(trend3 != none) stringTfs += stringTfs == "" ? (string) trend3 : "," + (string) trend3;
      StringSplit(stringTfs, ',', values);
      addTF(values, trendSyncTfs, tfCounter);
      } 
   stringTfs = "";
   if(PremDiscMode != off)
      {   
      if(premdisc1 != none) stringTfs += (string) premdisc1;
      if(premdisc2 != none) stringTfs += stringTfs == "" ? (string) premdisc2 : "," + (string) premdisc2;
      if(premdisc3 != none) stringTfs += stringTfs == "" ? (string) premdisc3 : "," + (string) premdisc3;
      StringSplit(stringTfs, ',', values);
      addTF(values, premiumDiscTfs, tfCounter);
      } 
   stringTfs = "";
   if(contextMode != off)
      {   
      if(context1 != none) stringTfs += (string) context1;
      if(context2 != none) stringTfs += stringTfs == "" ? (string) context2 : "," + (string) context2;
      if(context3 != none) stringTfs += stringTfs == "" ? (string) context3 : "," + (string) context3;
      StringSplit(stringTfs, ',', values);
      addTF(values, poiTfs, tfCounter);
      } 
   stringTfs = "";
   if((counterContext1 != none || counterContext1 != none || counterContext1 != none) && (countCounterFF || countCounterFVG || countCounterSweep || countCounterOB))
      {
      counterContextMode = On;
      if(counterContext1 != none) stringTfs += (string) counterContext1;
      if(counterContext2 != none) stringTfs += stringTfs == "" ? (string) counterContext2 : "," + (string) counterContext2;
      if(counterContext3 != none) stringTfs += stringTfs == "" ? (string) counterContext3 : "," + (string) counterContext3;
      StringSplit(stringTfs, ',', values);
      addTF(values, counterPoiTfs, tfCounter);
      }
      
   // predefined trend tfs
   if(visual) 
      {
      ArrayResize(trendTfs, 0);
      ArrayResize(values,3);
      values[0] = "60";
      values[1] = "240";
      values[2] = "720";
      addTF(values, trendTfs, tfCounter);
      for(i = 0; i < ArraySize(strSyncTfs); i++)
         {
         if(strSyncTfs[i] != 60 && strSyncTfs[i] != 240 && strSyncTfs[i] != 720)
            {
            ArrayResize(trendTfs, ArraySize(trendTfs) + 1);
            trendTfs[ArraySize(trendTfs) - 1] = strSyncTfs[i];
            }
         }
      for(i = 0; i < ArraySize(trendSyncTfs); i++)
         {
         if(trendSyncTfs[i] != 60 && trendSyncTfs[i] != 240 && trendSyncTfs[i] != 720)
            {
            ArrayResize(trendTfs, ArraySize(trendTfs) + 1);
            trendTfs[ArraySize(trendTfs) - 1] = trendSyncTfs[i];
            }
         }
      ArraySort(trendTfs);
      }
   addTF(PeriodSeconds() / 60,tfCounter);
   addTF(1440,tfCounter);
   }
   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Open Order Functions-------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

bool checkDailyLoss()
   {
   if(AccountInfoDouble(ACCOUNT_EQUITY) - (initialBalance * Risk / 100) < dayInitialBalance - initialBalance * maxDailyLoss / 100) return false;
   return true;
   }

double positionCalculator(double limit, double stopLoss, bool buy, bool finalTry)
   {
   double lot, pips, accBalance, totalMargin = 0, marginNeeded, totalVolume = 0, marginFree, check;
   marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE); 
   accBalance = AccountInfoDouble(ACCOUNT_BALANCE) > AccountInfoDouble(ACCOUNT_EQUITY) ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   pips = buy ? (limit - stopLoss) * pipsDelta : (stopLoss - limit) * pipsDelta;
   lot = (initialBalance * Risk / AccountInfoInteger(ACCOUNT_LEVERAGE)) / (pips / pipsDelta * posSizeDelta);
   check = OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,lot,limit,marginNeeded);
   
   if(pips < PipsFrom || pips > PipsTo) return(addInvalidOrder(INVALID_PIPS, limit, stopLoss, finalTry));
   
   if(OrdersTotal() > 0 || PositionsTotal() > 0)
      {
      int i, o = 0, p = 0;
      double marginLocal = 0;
      ulong ticket;
      for(i = 0; o < OrdersTotal() || p < PositionsTotal(); i++)
         {
         ticket = OrderGetTicket(i);
         if(OrderSelect(ticket) == true) 
            {
            totalVolume += OrderGetDouble(ORDER_VOLUME_INITIAL);
            o++;
            check = OrderCalcMargin((ENUM_ORDER_TYPE) OrderGetInteger(ORDER_TYPE),_Symbol,OrderGetDouble(ORDER_VOLUME_INITIAL),OrderGetDouble(ORDER_PRICE_OPEN),marginLocal);
            totalMargin += marginLocal;
            }
         ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
            {
            totalVolume += PositionGetDouble(POSITION_VOLUME);
            p++;
            check = OrderCalcMargin(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),marginLocal);
            totalMargin += marginLocal;
            }
         }
      if(accBalance - totalMargin < marginFree) marginFree = accBalance - totalMargin;
      }      
      
   if(marginNeeded > marginFree) return(addInvalidOrder(NOT_ENOUGH_MARGIN, limit, stopLoss, finalTry));
   if(totalVolume + lot > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT) && SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT) != 0) return(addInvalidOrder(VOLUME_LIMIT_REACHED, limit, stopLoss, finalTry));
   if(lot > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)) return(addInvalidOrder(MAX_VOLUME_REACHED, limit, stopLoss, finalTry));
   if(lot <= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) return(addInvalidOrder(MIN_VOLUME_REACHED, limit, stopLoss, finalTry));
   if(maxDailyLoss != 0 && !checkDailyLoss()) return(addInvalidOrder(DAILY_LOSS_REACHED, limit, stopLoss, finalTry));
   
   return(StringToDouble(DoubleToString(lot, volumeDigits)));
   }

void CheckForOpen(double lot, double limit, double stopLoss, double takeProfit, ENUM_ORDER_TYPE orderType)
   {
   int res, i, threshold = 0;
   double stopLimit = 0; // move to function parameters if stopLimit needed
   double limitHigh = limit, limitLow = limit;
   datetime expiration = TimeCurrent();
   MqlTradeRequest request={};
   MqlTradeResult result={};
   MqlTick Latest_Price; 
   SymbolInfoTick(_Symbol, Latest_Price);
   limit = StringToDouble(DoubleToString(limit, tickDigits));
   request.symbol=_Symbol;
   request.volume=lot;
   request.magic=(int) orderMagicNumber;
   
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL) request.action=TRADE_ACTION_DEAL;
   else request.action=TRADE_ACTION_PENDING;
   if(LimitExpiresInMinutes != 0)
      {
      request.type_time=ORDER_TIME_SPECIFIED;
      request.expiration= expiration + LimitExpiresInMinutes*60;
      }
   
   if(ORDER_FILLING_FOK && SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == ORDER_FILLING_FOK) request.type_filling = ORDER_FILLING_FOK;
   else request.type_filling = ORDER_FILLING_IOC;
   
   while(threshold < 5 && result.order == 0 && (result.retcode == 0 || result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_INVALID_PRICE || result.retcode == TRADE_RETCODE_INVALID_STOPS))
      {
      if(takeProfit > stopLoss)
         {
         if(orderType != ORDER_TYPE_BUY)
            {
            if(stopLimit == 0)
               {
               if((orderType == ORDER_TYPE_BUY_STOP && limit - Latest_Price.ask < symbolTradeStopsLevel) || (orderType != ORDER_TYPE_BUY_STOP && Latest_Price.ask - limit < symbolTradeStopsLevel))
                  {
                  request.action=TRADE_ACTION_DEAL;
                  orderType=ORDER_TYPE_BUY;
                  limit=Latest_Price.ask;
                  }
               }
            else
               {
               if(stopLimit - Latest_Price.ask < symbolTradeStopsLevel)
                  {
                  stopLimit = 0;
                  orderType=ORDER_TYPE_BUY_LIMIT;
                  if(limit - Latest_Price.ask < symbolTradeStopsLevel)
                     {
                     request.action=TRADE_ACTION_DEAL;
                     orderType=ORDER_TYPE_BUY;
                     limit=Latest_Price.ask;
                     }
                  }
               if(orderType != ORDER_TYPE_BUY)   
                  {
                  if(limit < Latest_Price.ask)
                     {
                     if(Latest_Price.ask - limit < symbolTradeStopsLevel) limit = Latest_Price.ask - symbolTradeStopsLevel;
                     }
                  else
                     {
                     if(limit - Latest_Price.ask < symbolTradeStopsLevel) limit = Latest_Price.ask + symbolTradeStopsLevel;
                     }  
                  if(stopLimit != 0 && stopLimit - limit < symbolTradeStopsLevel) stopLimit = limit + symbolTradeStopsLevel;
                  }   
               }     
            } 
         if(limit - stopLoss < symbolTradeStopsLevel) limit = stopLoss + symbolTradeStopsLevel;   
         if(stopLoss > Latest_Price.bid - symbolTradeStopsLevel) stopLoss = Latest_Price.bid - symbolTradeStopsLevel;
         //if(takeProfit < Latest_Price.bid + symbolTradeStopsLevel) takeProfit = Latest_Price.bid + symbolTradeStopsLevel;
         }
      else
         {
         if(orderType != ORDER_TYPE_SELL)
            {
            if(stopLimit == 0)
               {
               if((orderType == ORDER_TYPE_SELL_STOP && Latest_Price.bid - limit < symbolTradeStopsLevel) || (orderType != ORDER_TYPE_SELL_STOP && limit - Latest_Price.bid < symbolTradeStopsLevel))
                  {
                  request.action=TRADE_ACTION_DEAL;
                  orderType=ORDER_TYPE_SELL;
                  limit=Latest_Price.bid;
                  }
               }
            else
               {
               if(Latest_Price.bid - stopLimit < symbolTradeStopsLevel)
                  {
                  stopLimit = 0;
                  orderType=ORDER_TYPE_SELL_LIMIT;
                  if(Latest_Price.bid - limit < symbolTradeStopsLevel)
                     {
                     request.action=TRADE_ACTION_DEAL;
                     orderType=ORDER_TYPE_SELL;
                     limit=Latest_Price.bid;
                     }
                  }
               if(orderType != ORDER_TYPE_SELL)   
                  {
                  if(limit > Latest_Price.bid)
                     {
                     if(limit - Latest_Price.bid < symbolTradeStopsLevel) limit = Latest_Price.bid + symbolTradeStopsLevel;
                     }
                  else
                     {
                     if(Latest_Price.bid - limit < symbolTradeStopsLevel) limit = Latest_Price.bid - symbolTradeStopsLevel;
                     }   
                  if(stopLimit != 0 && limit - stopLimit < symbolTradeStopsLevel) stopLimit = limit - symbolTradeStopsLevel;
                  }   
               }     
            } 
         if(stopLoss - limit < symbolTradeStopsLevel) limit = stopLoss - symbolTradeStopsLevel;
         if(stopLoss < Latest_Price.ask + symbolTradeStopsLevel) stopLoss = Latest_Price.ask + symbolTradeStopsLevel;
         //if(takeProfit > Latest_Price.ask - symbolTradeStopsLevel) takeProfit = Latest_Price.ask - symbolTradeStopsLevel;
         } 
      
      request.sl=stopLoss;
      request.type = orderType;
      request.price=StringToDouble(DoubleToString(limit, tickDigits));
      request.tp=takeProfit;
      if(stopLimit != 0) request.stoplimit = stopLimit;
      
      res = OrderSend(request,result);
      SymbolInfoTick(_Symbol, Latest_Price);
      if(result.retcode == TRADE_RETCODE_REQUOTE)
         {
         limitHigh = limit;
         limitLow = limit;
         for(i = 0; i < 5 && result.order == 0; i++)
            {
            limitHigh += _Point;
            limitLow -= _Point;
            request.price = limitHigh;
            res = OrderSend(request,result);
            if(result.order != 0) break;
            else
               {
               request.price = limitLow;
               res = OrderSend(request,result);
               }
            }   
         }  
      threshold++;   
      }
      
   if(visual && result.order != 0) orders[orderIndex].ticket = result.order;
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------POSITION OPENING HELPERS-----------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void checkForTrailing()
   {
   static int res, o, posCounter;
   static ulong ticket;
   static MqlTradeRequest request={};
   static MqlTradeResult result={};
   static MqlTick Latest_Price;   
   SymbolInfoTick(_Symbol, Latest_Price);
   const double stoplossLong = StringToDouble(DoubleToString(Latest_Price.ask - trailPips / pipsDelta,tickDigits)), stoplossShort = StringToDouble(DoubleToString(Latest_Price.bid + trailPips / pipsDelta,tickDigits));
   static double stopLoss;
   for(o = 0, posCounter = 0; o <= 10 && posCounter <= PositionsTotal(); o++)
      {
      ticket = PositionGetTicket(o);
      if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != (int) orderMagicNumber) continue;
      posCounter++;
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      //request.tp = PositionGetDouble(POSITION_TP);
      stopLoss = StringToDouble(DoubleToString(PositionGetDouble(POSITION_SL),tickDigits));
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
         {
         request.sl = stoplossLong;
         if(stoplossLong > PositionGetDouble(POSITION_PRICE_OPEN) && stoplossLong > stopLoss + (symbolTradeStopsLevel == 0 ? _Point * 2 : symbolTradeStopsLevel)
            &&
            stoplossLong > stopLoss + symbolTradeFreezeLevel) res = OrderSend(request,result);
         }
      else
         {
         request.sl = stoplossShort;
         if(stoplossShort < PositionGetDouble(POSITION_PRICE_OPEN) && stoplossShort < stopLoss - (symbolTradeStopsLevel == 0 ? _Point * 2 : symbolTradeStopsLevel)
            &&
            stoplossShort < stopLoss - symbolTradeFreezeLevel) res = OrderSend(request,result);
         }   
      }
   }

void checkForBE()
   {
   static int res, o, posCounter;
   static double open, stoploss;
   static ulong ticket;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   MqlTick Latest_Price; // Structure to get the latest prices      
   SymbolInfoTick(_Symbol, Latest_Price);
   for(o = 0; o <= 10 && posCounter <= PositionsTotal(); o++)
      {
      ticket = PositionGetTicket(o);
      if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != (int) orderMagicNumber) continue;
      posCounter++;
      open = PositionGetDouble(POSITION_PRICE_OPEN);
      stoploss = PositionGetDouble(POSITION_SL);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
         if(stoploss >= open) continue;
         if(Latest_Price.ask < open + (open - stoploss) * BreakevenRRR) continue;
         }
      else 
         {
         if(stoploss <= open) continue;
         if(Latest_Price.bid > open - (stoploss - open) * BreakevenRRR) continue;
         }
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.sl = open;
      request.tp = PositionGetDouble(POSITION_TP);
      res = OrderSend(request,result);  
      }
   }
   
double pdl = 0, pdh = 0;
void CheckPDLPDH()
   {
   if(iHigh(_Symbol,PERIOD_D1,0) < iHigh(_Symbol,PERIOD_D1,1)) pdh = iHigh(_Symbol,PERIOD_D1,1);
   if(iLow(_Symbol,PERIOD_D1,1) < iLow(_Symbol,PERIOD_D1,0)) pdl = iLow(_Symbol,PERIOD_D1,1);
   }
   
void CheckCounterContext()
   {
   int res, j;
   ulong ticket;
   double stopLoss;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   
   for(int o = 10; o >= 0; o--)
      {
      ticket = OrderGetTicket(o);
      if(OrderSelect(ticket) == true && OrderGetInteger(ORDER_MAGIC) == (int) orderMagicNumber)
         {
         stopLoss = OrderGetDouble(ORDER_SL);
         request.action = TRADE_ACTION_REMOVE;
         request.order = ticket;
         if(stopLoss < OrderGetDouble(ORDER_TP))
            {
            if(!context(true, 0, TF[1][1][1])) 
               {
               if(_Ask < OrderGetDouble(ORDER_PRICE_OPEN) + symbolTradeFreezeLevel) continue;
               res = OrderSend(request,result);
               for(j = 0; j < ArraySize(orders); j++)
                  {
                  if(orders[orderIndex - j].ticket == ticket) break;
                  }
               if(j == ArraySize(orders)) continue;
               if(visual) posUpdate(orderIndex - j);
               }
            }
         else
            {
            if(!context(false, 0, TF[1][1][2])) 
               {
               if(_Bid > OrderGetDouble(ORDER_PRICE_OPEN) - symbolTradeFreezeLevel) continue;
               res = OrderSend(request,result);
               for(j = 0; j < ArraySize(orders); j++)
                  {
                  if(orders[orderIndex - j].ticket == ticket) break;
                  }
               if(j == ArraySize(orders)) continue;
               if(visual) posUpdate(orderIndex - j);
               }
            }
         }
      }
   }
void CheckForClose()
   {
   int res, j;
   ulong ticket;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   
   MqlTick Latest_Price; // Structure to get the latest prices      
   SymbolInfoTick(_Symbol, Latest_Price);
   
   for(int o = 10; o >= 0; o--)
      {
      ticket = OrderGetTicket(o);
      if(OrderSelect(ticket) == true && OrderGetInteger(ORDER_MAGIC) == (int) orderMagicNumber)
         {
         request.action = TRADE_ACTION_REMOVE;
         request.order = ticket;
         request.magic=(int) orderMagicNumber;
         if((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT
            && Latest_Price.bid <= OrderGetDouble(ORDER_PRICE_OPEN) - (OrderGetDouble(ORDER_SL) - OrderGetDouble(ORDER_PRICE_OPEN)) * CancelAtRRR) 
            ||
            (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT
            && Latest_Price.ask >= OrderGetDouble(ORDER_PRICE_OPEN) + (OrderGetDouble(ORDER_PRICE_OPEN) - OrderGetDouble(ORDER_SL)) * CancelAtRRR)) 
            {
            res = OrderSend(request,result);
            for(j = 0; j < ArraySize(orders); j++)
               {
               if(orders[orderIndex - j].ticket == ticket) break;
               }
            if(j == ArraySize(orders)) continue;
            if(visual) posUpdate(orderIndex - j);
            }
         }
      }
   }
void CheckForPartial()
   {
   static int res, o;
   static ulong ticket;
   static double stopLoss, limit, takeProfit, cur;
   static bool buy;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   
   for(o = 10; o >= 0; o--)
      {
      ticket = PositionGetTicket(o);
      if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != (int) orderMagicNumber) continue;
      HistoryOrderSelect(ticket);
      if(HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL) != PositionGetDouble(POSITION_VOLUME)) continue;
      buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? true : false;
      stopLoss = PositionGetDouble(POSITION_SL);
      limit = PositionGetDouble(POSITION_PRICE_OPEN);
      takeProfit = PositionGetDouble(POSITION_TP);
      cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      if((buy && (cur >= limit + (limit - stopLoss) * PartialRRR)) || (!buy && (cur <= limit - (stopLoss - limit) * PartialRRR))) request.volume = PositionGetDouble(POSITION_VOLUME) * PartialPercent / 100;
      else continue;
      if((buy && (cur < stopLoss + symbolTradeFreezeLevel || cur > takeProfit - symbolTradeFreezeLevel)) || (!buy && (cur > stopLoss - symbolTradeFreezeLevel || cur < takeProfit + symbolTradeFreezeLevel))) continue;
      request.volume = StringToDouble(DoubleToString(request.volume,volumeDigits));
      request.type = buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, (buy ? SYMBOL_BID : SYMBOL_ASK));
      request.action = TRADE_ACTION_DEAL;
      request.position = PositionGetInteger(POSITION_TICKET);
      request.symbol = _Symbol;
      if(ORDER_FILLING_FOK && SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == ORDER_FILLING_FOK) request.type_filling = ORDER_FILLING_FOK;
      else request.type_filling = ORDER_FILLING_IOC;
      request.magic=(int) orderMagicNumber;
      res = OrderSend(request,result);  
      }
   }

void ClosePositions()
   {
   int res, o, j;
   ulong ticket;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   
   for(o = 10; o >= 0; o--)
      {
      ticket = OrderGetTicket(o);
      if(OrderSelect(ticket) == true && OrderGetInteger(ORDER_MAGIC) == (int) orderMagicNumber)
         {
         request.magic=(int) orderMagicNumber;
         request.action = TRADE_ACTION_REMOVE;
         request.order = ticket;
         res = OrderSend(request,result);
         if(visual)
            {
            for(j = 0; j < ArraySize(orders); j++)
               {
               if(orders[orderIndex - j].ticket == ticket) break;
               }
            if(j == ArraySize(orders)) continue;
            posUpdate(orderIndex - j);
            }
         }
      }
   for(o = 10; o >= 0; o--)
      {
      ulong ticket = PositionGetTicket(o);
      if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != (int) orderMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
         request.type = ORDER_TYPE_SELL;
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
         request.type = ORDER_TYPE_BUY;
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         }
      else continue;
      request.action = TRADE_ACTION_DEAL;
      request.position = PositionGetInteger(POSITION_TICKET);
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.symbol = _Symbol;
      if(ORDER_FILLING_FOK && SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == ORDER_FILLING_FOK) request.type_filling = ORDER_FILLING_FOK;
      else request.type_filling = ORDER_FILLING_IOC;
      request.magic=(int) orderMagicNumber;
      res = OrderSend(request,result);
      if(visual)
         {
         for(j = 0; j < ArraySize(orders); j++)
            {
            if(orders[orderIndex - j].ticket == ticket) break;
            }
         if(j == ArraySize(orders)) continue;
         orders[orderIndex - j].profit = HistoryDealGetDouble(result.deal, DEAL_PROFIT);
         if(HistoryDealGetDouble(result.deal, DEAL_PROFIT) < 0)
            {
            orders[orderIndex - j].win = 0;
            orders[orderIndex - j].SLTime = TimeCurrent();
            }  
         else
            {
            orders[orderIndex - j].win = 1;
            orders[orderIndex - j].TPTime = TimeCurrent();
            }
         if(!live) analyticsWindowVisualize(orderIndex - j);
         posUpdate(orderIndex - j, HistoryDealGetDouble(result.deal, DEAL_PRICE));
         }   
      }
   }

bool CheckActiveHours(datetime formedMinute)
   {
   datetime cur = TimeCurrent(), timeForCheck = formedMinute == 0 ? cur : formedMinute;
   TimeToStruct(cur, structTime);
   int i, month = structTime.mon, day = structTime.day;
   bool OperationsAllowedChanged = OperationsAllowed;
   datetime timeStart, timeEnd;
   OperationsAllowed = false;
   
   for(i = 0; i < ArraySize(hourIntervals); i++)
      {
      timeStart = cur - (cur % 86400) + tradeIntervals[i][0][0] * 3600 + tradeIntervals[i][0][1] * 60;
      timeEnd = cur - (cur % 86400) + tradeIntervals[i][1][0] * 3600 + tradeIntervals[i][1][1] * 60;
      if(timeForCheck >= timeStart && timeForCheck < timeEnd) OperationsAllowed = true;
      }
      
   if((month == 12 || (month == 1 && day <= 10)) && tradeInWinterHolidays != 1) OperationsAllowed = false;
   
   OperationsAllowedChanged = OperationsAllowed == OperationsAllowedChanged ? false : true;
   
   if(OperationsAllowedChanged && ClosePositionsAtSessionEnd == 1) ClosePositions();
   return OperationsAllowed;
   }

double checkPositionForValidity(double stopLoss, double limit, double takeProfit, double contrLevel, datetime formationTime)
   {
   int direction = stopLoss < takeProfit ? 1 : 0;
   bool buy = stopLoss < takeProfit ? true : false;
   double lot = 0;
   
   if(posDuplicated(direction, stopLoss)) return 0;
   
   if(!CheckActiveHours(formationTime)) return 0;
   
   if(LimitExpiresInMinutes != 0 && formationTime < TimeCurrent() - LimitExpiresInMinutes * 60) return 0;
   
   if(!context(buy, stopLoss, contrLevel)) return 0;
   
   if(CancelAtRRR != 0 && ((buy && contrLevel > limit + ((limit - stopLoss) * CancelAtRRR)) || (!buy && contrLevel < limit - ((stopLoss - limit) * CancelAtRRR)))) return 0;
   
   lot = positionCalculator(limit, stopLoss, buy, true);
   if(lot == 0) return 0;
   
   saveStopLoss(direction,stopLoss);
   
   return lot;
   }
   
void saveStopLoss(int direction, double stoploss)
   {
   if(SLIndex[direction] > 3)
      {
      static int q = 0;
      for(q = 0; q < 4; q++)
         {
         SL[q][direction] = SL[q + 1][direction];
         }
      SL[q][direction] = stoploss;   
      }
   else 
      {
      SL[SLIndex[direction]][direction] = stoploss;
      SLIndex[direction]++;
      } 
   } 
   
bool posDuplicated(int direction, double stopLoss)
   {
   for(int k = 0; k < 5; k++) 
      {
      if(stopLoss == SL[k][direction]) return true;
      }
   return false;   
   }

bool isSwingLow(int index, int timeframe) { return((TF[timeframe][index][2] < TF[timeframe][index-1][2] && TF[timeframe][index][2] < TF[timeframe][index+1][2]) || (TF[timeframe][index][2] < TF[timeframe][index-1][2] && TF[timeframe][index][2] <= TF[timeframe][index+1][2] && TF[timeframe][index+1][2] < TF[timeframe][index+2][2])); }
bool isSwingHigh(int index, int timeframe) { return((TF[timeframe][index][1] > TF[timeframe][index-1][1] && TF[timeframe][index][1] > TF[timeframe][index+1][1]) || (TF[timeframe][index][1] > TF[timeframe][index-1][1] && TF[timeframe][index][1] >= TF[timeframe][index+1][1] && TF[timeframe][index+1][1] > TF[timeframe][index+2][1])); }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Add TF functions OnInit----------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
   
bool addTF(int tf, int& counter)
   {
   if(tfs[ArrayBsearch(tfs, tf)] != tf)
      {
      ArrayResize(tfs,counter+1);
      tfs[counter] = tf;
      TF[tf][0][0] = 0;
      aggregatorHH[tf] = 0;
      aggregatorLL[tf] = 0;
      minuteChecker[tf] = 0;
      TFAdditionalShift[tf] = 0;
      counter++;
      ArraySort(tfs);  
      ArrayResize(timeframeBars, tfs[ArraySize(tfs) - 1] + 1);
      timeframeBars[tf] = 0;
      return true;
      } 
   return false;   
   }
   
void addTF(string& values[], int& arrayOfTfs[], int& counter)
   {
   for(int i = 0; i < ArraySize(values); i++)
      {
      ArrayResize(arrayOfTfs,i+1);
      arrayOfTfs[i] = (int) StringToInteger(values[i]);
      if(tfs[ArrayBsearch(tfs, StringToInteger(values[i]))] == arrayOfTfs[i]) continue;
      ArrayResize(tfs,counter+1);
      tfs[counter] = arrayOfTfs[i];
      TF[tfs[counter]][0][0] = 0;
      aggregatorHH[tfs[counter]] = 0;
      aggregatorLL[tfs[counter]] = 0;
      minuteChecker[tfs[counter]] = 0;
      TFAdditionalShift[tfs[counter]] = 0;
      ArraySort(tfs);
      ArrayResize(timeframeBars, tfs[ArraySize(tfs) - 1] + 1);
      timeframeBars[tfs[counter]] = 0;
      counter++;
      }
   }
    
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Time Intervals OnInit------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void defineTradeIntervals()
   {
   int i, j = 0;
   string hourMinute[2];
   string hourMinuteSeparate[2];
   
   StringSplit(tradeHours, ';', hourIntervals);
   for(i = 0; i < ArraySize(hourIntervals); i++)
      {
      StringSplit(hourIntervals[i], '-', hourMinute);
      for(j = 0; j < 2; j++)
         {
         StringSplit(hourMinute[j], ':', hourMinuteSeparate);
         tradeIntervals[i][j][0] = (int) StringToInteger(hourMinuteSeparate[0]);
         tradeIntervals[i][j][1] = (int) StringToInteger(hourMinuteSeparate[1]);
         }
      }   
   }
    
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Delta Recalculation for CFD OnInit-----------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void calculateDelta()
   {
   long CalcMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   if((CalcMode == SYMBOL_CALC_MODE_CFD) || (CalcMode == SYMBOL_CALC_MODE_CFDINDEX) || (CalcMode == SYMBOL_CALC_MODE_CFDLEVERAGE))
     {
      double TickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double LotSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double TickValue = TickSize * LotSize;
      const string prof = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
      const string acc  = AccountInfoString(ACCOUNT_CURRENCY);
      if(prof != acc) TickValue *= GetCrossRate(prof, acc);
      posSizeDelta = TickValue / TickSize;
     }
   }
   
double GetCrossRate(string curr_prof, string curr_acc)
  {
   if(StringCompare(curr_prof, curr_acc, false) == 0) return (1.0);
   string symbol = curr_prof + curr_acc;
   if(CheckMarketWatch(symbol))
     {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(bid != 0.0) return (bid);
     }
   symbol = curr_acc + curr_prof;
   if(CheckMarketWatch(symbol))
     {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(ask != 0.0) return (1 / ask);
     }
   Print(__FUNCTION__, ": Error, cannot get cross rate for ", curr_prof + curr_acc);
   return(0.0);
  }
  
bool CheckMarketWatch(string symbol)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol,SYMBOL_SELECT))
     {
      if(GetLastError()==ERR_MARKET_UNKNOWN_SYMBOL) return(false);
      if(!SymbolSelect(symbol,true)) return(false);
     }
   return(true);
  }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Set Chart Colors OnInit----------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void setChartColors(long chart_id)
   {
   ChartSetInteger(chart_id,CHART_SHOW_BID_LINE, 0);
   ChartSetInteger(chart_id,CHART_SHOW_ASK_LINE, 0);
   ChartSetInteger(chart_id,CHART_COLOR_BID, clrNONE);
   ChartSetInteger(chart_id,CHART_COLOR_ASK, clrNONE);
   ChartSetInteger(chart_id,CHART_COLOR_BACKGROUND, clrWhiteSmoke);
   ChartSetInteger(chart_id,CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(chart_id,CHART_SHOW_GRID,false);
   ChartSetInteger(chart_id,CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(chart_id,CHART_COLOR_CANDLE_BEAR, clrBlack);
   ChartSetInteger(chart_id,CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(chart_id,CHART_COLOR_CHART_DOWN, clrBlack);
   ChartSetInteger(chart_id,CHART_COLOR_CHART_LINE, clrBlack);
   ChartSetInteger(chart_id,CHART_COLOR_STOP_LEVEL, clrWhiteSmoke);
   ChartSetInteger(chart_id,CHART_SHOW_TRADE_LEVELS, false);
   ChartSetInteger(chart_id,CHART_SHOW_TRADE_HISTORY, false);
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Add Watermark OnInit----------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

#resource "algoIndustries.png" as uchar png_data[]
CPng png1(png_data);

void addWatermark()
   {
   png1.Resize(1060*(int)DPIMultiplier);
   png1._CreateCanvas(220*(int)DPIMultiplier,100*(int)DPIMultiplier);
   png1.BmpArrayFree();
   }
   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------News History---------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*
void checkNewsHistory()
   {
   string Currencies[2];
   Currencies[0] = ::SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   Currencies[1] = ::SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   bool Res = false;

   if(MQLInfoInteger(MQL_TESTER))
      {
      Res = Calendar.Load(CALENDAR_FILENAME) && Calendar.FilterByCurrency(Currencies) && Calendar.FilterByImportance((ENUM_CALENDAR_EVENT_IMPORTANCE) importance);
      
      if(!Res) Print("Run the EA in the MT5-Terminal!");
      }
#ifdef __MQL5__
  // Работаем в Терминале.
  else if (Calendar.Set(NULL, CALENDAR_IMPORTANCE_MODERATE, 0, 0) && Calendar.Save(CALENDAR_FILENAME))
    MessageBox("You can run the EA in the MT4/5-Tester.");
#endif
   }

bool CheckNews(datetime time = 0)
   {
   const datetime posTime = time == 0 ? TimeCurrent() : time;
   int Pos = Calendar.GetPosAfter(posTime);
   bool NoNews = true;
   if(Pos < Calendar.GetAmount() && Calendar[Pos].TimeMode == CALENDAR_TIMEMODE_DATE) return NoNews;
   if(Pos < Calendar.GetAmount() && Calendar[Pos].time < posTime + skipHoursBeforeNews * 3600) NoNews = false;
   else if(Pos > 0 && Calendar[Pos - 1].time > posTime - skipHoursAfterNews * 3600) NoNews = false;
   if(!NoNews && time == 0 && (OrdersTotal() > 0 || PositionsTotal() > 0)) ClosePositions();
   return NoNews;   
   }

void DrawNews()
   {
   int Pos = Calendar.GetPosAfter(TimeCurrent());
   
   static newsZone lastNewsZone;
   static newsZone nextNewsZone;
   
   if(Pos < Calendar.GetAmount() && Calendar[Pos].TimeMode == CALENDAR_TIMEMODE_DATE) Pos++;
   
   if(Pos > nextNewsZone.endPos)
      {
      if(Pos < Calendar.GetAmount()) 
         {
         lastNewsZone = nextNewsZone;
         const datetime time = Calendar[Pos].time;
         nextNewsZone.start = time - (int) (skipHoursBeforeNews * 3600);
         nextNewsZone.end = time + (int) (skipHoursAfterNews * 3600);
         nextNewsZone.startPos = Pos;
         nextNewsZone.endPos = Pos;
         ArrayResize(nextNewsZone.newsTimes, 1);
         nextNewsZone.newsTimes[0] = time;
         datetime nextNewsStart, nextNewsEnd;
         
         for(int i = Pos + 1; i < Calendar.GetAmount() && Calendar[i].time - (int) (skipHoursBeforeNews * 3600) <= nextNewsZone.end; i++)
            {
            if(Calendar[i].TimeMode == CALENDAR_TIMEMODE_DATE) continue;
            nextNewsStart = Calendar[i].time - (int) (skipHoursBeforeNews * 3600);
            nextNewsEnd = Calendar[i].time + (int) (skipHoursAfterNews * 3600);
            
            nextNewsZone.end = nextNewsEnd;
            nextNewsZone.endPos = i;
            
            ArrayResize(nextNewsZone.newsTimes, ArraySize(nextNewsZone.newsTimes) + 1);
            nextNewsZone.newsTimes[ArraySize(nextNewsZone.newsTimes) - 1] = Calendar[i].time;
            } 
         }
      }  
   if(lastNewsZone.end > TimeCurrent() - skipHoursAfterNews * 3600) createNewsZone(lastNewsZone); 
   createNewsZone(nextNewsZone);
   }

void createNewsZone(newsZone& zone)
   { 
   static int i = 0;
   const bool notStarted = zone.start > TimeCurrent() ? true : false;
   const double dayLow = iLow(_Symbol,PERIOD_D1,0); 
   const double dayHigh = iHigh(_Symbol,PERIOD_D1,0);
   
   zone.low = notStarted ? dayLow : (dayLow < zone.low ? dayLow : zone.low);
   zone.high = notStarted ? dayHigh : (dayHigh > zone.high ? dayHigh : zone.high);
   
   createRectangle(newsText + (string) zone.newsTimes[0],zone.start,zone.end,zone.low,zone.high,newsClr);
   
   createLine(newsStartText + (string) zone.start,zone.start,zone.start,zone.low,newsBorderClr,newsBorderStyle,zone.high);
   createLine(newsEndText + (string) zone.end,zone.end,zone.end,zone.low,newsBorderClr,newsBorderStyle,zone.high);
   createLine(newsStartText + (string) zone.end,zone.start,zone.end,zone.high,newsBorderClr,newsBorderStyle,zone.high);
   createLine(newsEndText + (string) zone.start,zone.end,zone.start,zone.low,newsBorderClr,newsBorderStyle,zone.low);
   
   for(i = 0; i < ArraySize(zone.newsTimes); i++)
      {
      createLine(newsTimeText + (string) zone.newsTimes[i],zone.newsTimes[i],zone.newsTimes[i],zone.low,newsTimeClr,newsTimeStyle,zone.high);
      }
   }
*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Converters-----------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

datetime IndexToTime(int index, int timeframe) { return(iTime(_Symbol, (ENUM_TIMEFRAMES) MinutesToPeriod(timeframe), index)); }
int MinutesToPeriod(int minutes)
   {
   int x = minutes >= 60 ? 1 : 0;
   if(minutes > 1440) x = 2;
   int offset = x == 0 ? 1 : 60;
   if(x == 2) offset = 10080;
   return(minutes == 43200 ? PERIOD_MN1 : (x<<14) + minutes/offset);
   }
   
string MinutesToTF(int minutes)
   {
   if(minutes < 60) return("M" + IntegerToString((int) minutes));
   else if(minutes < 1440) return("H" + IntegerToString((int) (minutes / 60)));
   else if(minutes < 10080) return("D" + IntegerToString((int) (minutes / 1440)));
   else if(minutes < 43200) return("W" + IntegerToString((int) (minutes / 10080)));
   else return("MN");
   }
long PeriodForObject(ENUM_TIMEFRAMES period)
   {
   switch (period) {
      case PERIOD_M1:  return(OBJ_PERIOD_M1 );
      case PERIOD_M2:  return(OBJ_PERIOD_M2 );
      case PERIOD_M3:  return(OBJ_PERIOD_M3 );
      case PERIOD_M4:  return(OBJ_PERIOD_M4 );
      case PERIOD_M5:  return(OBJ_PERIOD_M5 );
      case PERIOD_M6:  return(OBJ_PERIOD_M6 );
      case PERIOD_M10: return(OBJ_PERIOD_M10);
      case PERIOD_M12: return(OBJ_PERIOD_M12);
      case PERIOD_M15: return(OBJ_PERIOD_M15);
      case PERIOD_M20: return(OBJ_PERIOD_M20);
      case PERIOD_M30: return(OBJ_PERIOD_M30);
      case PERIOD_H1:  return(OBJ_PERIOD_H1 );
      case PERIOD_H2:  return(OBJ_PERIOD_H2 );
      case PERIOD_H3:  return(OBJ_PERIOD_H3 );
      case PERIOD_H4:  return(OBJ_PERIOD_H4 );
      case PERIOD_H6:  return(OBJ_PERIOD_H6 );
      case PERIOD_H8:  return(OBJ_PERIOD_H8 );
      case PERIOD_H12: return(OBJ_PERIOD_H12);
      case PERIOD_D1:  return(OBJ_PERIOD_D1 );
      case PERIOD_W1:  return(OBJ_PERIOD_W1 );
      case PERIOD_MN1: return(OBJ_PERIOD_MN1);
   }
   return(0);
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Timeframe Aggregator-------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
  
void Aggregator(bool newTF = false)
   {
   datetime barTime = iTime(_Symbol, 1, 0);
   TimeToStruct(barTime, structTime);
   int i = 0, j = 0, k = 0, p = 0, minute = structTime.min, hour = structTime.hour, day = structTime.day_of_year, weekDay = structTime.day_of_week, localMinute, localCounter, shift = 0, tf;
   int yearStartShift = 0;
   minute += hour * 60;
   int minuteWithDays = minute + day * 1440, localMinuteWithDays = 0, divider = 1440, minutesLeftForPrevCycleCompletion = 0, minutesMissedInNewCycle = 0, index = 0;
   
   for(i = 0; i < ArraySize(tfs) && tfs[i] != 0; i++)
      {
      if(tfs[i] == 1 && !newTF)
         {
         if(TF[1][maxAggregatedCandles - 1][0] == 0)
            {
            for(j = 0; j != maxAggregatedCandles; j++)
               {
               TimeToStruct(iTime(_Symbol,1,j), structTime);
               localMinute = structTime.min + structTime.hour * 60;
               TF[1][j][0] = iOpen(Symbol(),1,j);
               TF[1][j][1] = iHigh(Symbol(),1,j);
               TF[1][j][2] = iLow(Symbol(),1,j);
               TF[1][j][3] = iClose(Symbol(),1,j);
               TF[1][j][4] = localMinute;
               TF[1][j][5] = 0;
               }
            }
         else
            {
            for(j = maxAggregatedCandles - 1; j > 0; j--) // cмещаем элементы массива "вправо" (освобождаем нулевой элемент)
               {
               TF[1][j][0] = TF[1][j - 1][0];
               TF[1][j][1] = TF[1][j - 1][1];
               TF[1][j][2] = TF[1][j - 1][2];
               TF[1][j][3] = TF[1][j - 1][3];
               TF[1][j][4] = TF[1][j - 1][4];
               }
               
            TF[1][1][1] = iHigh(Symbol(),1,1);
            TF[1][1][2] = iLow(Symbol(),1,1);
            TF[1][1][3] = iClose(Symbol(),1,1);
            
            TF[1][0][0] = iOpen(Symbol(),1,0);
            TF[1][0][1] = iHigh(Symbol(),1,0);
            TF[1][0][2] = iLow(Symbol(),1,0);
            TF[1][0][3] = iClose(Symbol(),1,0);
            TF[1][0][4] = minute;
            TF[1][0][5] = 0;
            } 
         }
      else
         {
         tf = tfs[i];
         if(tf >= 1440) 
            {
            minute = (int) TimeCurrent() / 60;
            }
         if(TF[tf][0][0] != 0 && !newTF)   
            {
            if(tf >= 1440) 
               {
               if(timeframeBars[tf] < Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(tf)))
                  {
                  for(j = maxAggregatedCandles - 1; j > 0; j--) // cмещаем элементы массива "вправо" (освобождаем нулевой элемент)
                     {
                     TF[tf][j][0] = TF[tf][j - 1][0];
                     TF[tf][j][1] = TF[tf][j - 1][1];
                     TF[tf][j][2] = TF[tf][j - 1][2];
                     TF[tf][j][3] = TF[tf][j - 1][3];
                     TF[tf][j][4] = TF[tf][j - 1][4];
                     }
                  TF[1][1][1] = iHigh(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),1);
                  TF[1][1][2] = iLow(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),1);
                  TF[1][1][3] = iClose(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),1);
                  
                  TF[1][0][0] = iOpen(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  TF[1][0][1] = iHigh(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  TF[1][0][2] = iLow(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  TF[1][0][3] = iClose(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  TF[1][0][4] = minute;
                  TF[1][0][5] = 0;
                  }  
               else
                  {
                  TF[tf][0][1] = iHigh(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  TF[tf][0][2] = iLow(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),0);
                  } 
               continue;     
               }
            if(minuteChecker[tf] + (tf - (minuteChecker[tf] % divider) % tf) <= minuteWithDays || minuteChecker[tf] - minuteWithDays > 0)
               {
               if(minuteChecker[tf] != 0)
                  {
                  if(tf <= 1440)
                     {
                     if((int) (minuteChecker[tf] / 1440) < (int) (minuteWithDays / 1440) && minuteChecker[tf] % 1440 + (tf - (minuteChecker[tf] % 1440) % tf) >= 1440)
                        {
                        minutesLeftForPrevCycleCompletion = 1440 - minuteChecker[tf] % 1440 - 1;
                        }
                     else
                        {
                        minutesLeftForPrevCycleCompletion = tf - (minuteChecker[tf] % 1440) % tf - 1;
                        }   
                     minutesMissedInNewCycle = minute % tf;
                     }
                  else
                     {
                     minutesLeftForPrevCycleCompletion = tf - minuteChecker[tf] % tf - 1;
                     minutesMissedInNewCycle = minuteWithDays % tf;
                     } 
                  if(minutesLeftForPrevCycleCompletion + minutesMissedInNewCycle > 0)
                     {
                     TFAdditionalShift[tf] += minutesLeftForPrevCycleCompletion;
                     }   
                  }  
               
               TF[tf][0][3] = iClose(Symbol(), 1, 1);
               if(iHigh(Symbol(), 1, 1) > aggregatorHH[tf]) TF[tf][0][1] = iHigh(Symbol(), 1, 1);
               else TF[tf][0][1] = aggregatorHH[tf];
               if(iLow(Symbol(), 1, 1) < aggregatorLL[tf]) TF[tf][0][2] = iLow(Symbol(), 1, 1);
               else TF[tf][0][2] = aggregatorLL[tf];
               TFAdditionalShift[tf] += TFMinutesElapsed[tf];
               TFMinutesElapsed[tf] = 0;
               TF[tf][0][5] = TFAdditionalShift[tf];
               for(p = maxAggregatedCandles - 1; p > 0; p--) // cмещаем элементы массива "вправо" (освобождаем нулевой элемент)
                  {
                  TF[tf][p][0] = TF[tf][p - 1][0];
                  TF[tf][p][1] = TF[tf][p - 1][1];
                  TF[tf][p][2] = TF[tf][p - 1][2];
                  TF[tf][p][3] = TF[tf][p - 1][3];
                  TF[tf][p][4] = TF[tf][p - 1][4];
                  TF[tf][p][5] = TF[tf][p - 1][5];
                  if(p > 1) TF[tf][p][5] += TFAdditionalShift[tf];
                  }
                     
               TF[tf][0][0] = iOpen(Symbol(), 1, 0);
               TF[tf][0][1] = iHigh(Symbol(), 1, 0);
               TF[tf][0][2] = iLow(Symbol(), 1, 0);
               TF[tf][0][3] = 0;
               TF[tf][0][4] = minute - (minute % tf);
               TFAdditionalShift[tf] = minutesMissedInNewCycle;
               aggregatorHH[tf] = TF[tf][0][1];
               aggregatorLL[tf] = TF[tf][0][2];
               minuteChecker[tf] = minuteWithDays;
               }
            else
               {
               if(minuteWithDays - minuteChecker[tf] > 1)
                  {
                  TFAdditionalShift[tf] += minuteWithDays - minuteChecker[tf] - 1;
                  }
               TFMinutesElapsed[tf]++;
               TFAdditionalShift[tf]--;
               minuteChecker[tf] = minuteWithDays;
               if(iHigh(Symbol(), 1, 1) > aggregatorHH[tf]) 
                  {
                  aggregatorHH[tf] = iHigh(Symbol(), 1, 1);
                  TF[tf][0][1] = aggregatorHH[tf];
                  }
               if(iLow(Symbol(), 1, 1) < aggregatorLL[tf]) 
                  {
                  aggregatorLL[tf] = iLow(Symbol(), 1, 1);
                  TF[tf][0][2] = aggregatorLL[tf];
                  }
               }   
            }
         else
            {
            if(tf >= 1440) 
               {
               for(j = 0; j != maxAggregatedCandles; j++)
                  {
                  localMinute = (int) iTime(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(tf),j) / 60;
                  TF[tf][j][0] = iOpen(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),j);
                  TF[tf][j][1] = iHigh(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),j);
                  TF[tf][j][2] = iLow(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),j);
                  TF[tf][j][3] = iClose(Symbol(),(ENUM_TIMEFRAMES) MinutesToPeriod(tf),j);
                  TF[tf][j][4] = localMinute;
                  TF[tf][j][5] = 0;
                  }
               timeframeBars[tf] = Bars(_Symbol,(ENUM_TIMEFRAMES) MinutesToPeriod(tf));
               continue;  
               }
            TF[tf][0][1] = iHigh(Symbol(), 1, 0);
            TF[tf][0][2] = iLow(Symbol(), 1, 0);
            TF[tf][0][3] = 0;
            aggregatorHH[tf] = TF[tf][0][1];
            aggregatorLL[tf] = TF[tf][0][2];
            localMinute = minute;
            minuteChecker[tf] = minuteWithDays;
            
            shift = 0;
            localCounter = 0;
            minutesMissedInNewCycle = 0;
            minutesLeftForPrevCycleCompletion = 0;
            
            for(p = 0; p < tf + 1; p++)
               {
               TimeToStruct(iTime(_Symbol,1,p), structTime);
               localMinute = structTime.min + structTime.hour * 60;
               localMinuteWithDays = localMinute + structTime.day_of_year * 1440;
               if(tf > 1440) 
                  {
                  weekDay = structTime.day_of_week;
                  if((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf != 0)
                     {
                     yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf - (weekDay - 1) * 1440);
                     }
                  else
                     {
                     yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf - 1) * tf - (weekDay - 1) * 1440);
                     } 
                  if(yearStartShift >= 10080) yearStartShift = 0;
                  localMinuteWithDays += yearStartShift;
                  localMinute = localMinuteWithDays;
                  }
               if(localCounter != 0)
                  {
                  if(localMinuteWithDays + (tf - (localMinuteWithDays % divider) % tf) <= localCounter || localMinuteWithDays - localCounter > 0)
                     {
                     if(tf <= 1440)
                        {
                        if((int) (localCounter / 1440) > (int) (localMinuteWithDays / 1440) && localMinute + (tf - localMinute % tf) >= 1440)
                           {
                           minutesMissedInNewCycle = 1440 - localMinute - 1;
                           }
                        else
                           {
                           minutesMissedInNewCycle = tf - localMinute % tf - 1;
                           }   
                        minutesLeftForPrevCycleCompletion = localCounter % tf;
                        }
                     else
                        {
                        minutesMissedInNewCycle = tf - localMinuteWithDays % tf - 1;
                        minutesLeftForPrevCycleCompletion = localCounter % tf;
                        } 
                     if(minutesLeftForPrevCycleCompletion + minutesMissedInNewCycle > 0)
                        {
                        shift += minutesLeftForPrevCycleCompletion;
                        }
                     p--;   
                     break;   
                     }
                  if(localCounter - localMinuteWithDays > 1)
                     {
                     shift += localCounter - localMinuteWithDays - 1;
                     }
                  }   
               if(iHigh(Symbol(), 1, p) > aggregatorHH[tf]) aggregatorHH[tf] = iHigh(Symbol(), 1, p);
               if(iLow(Symbol(), 1, p) < aggregatorLL[tf]) aggregatorLL[tf] = iLow(Symbol(), 1, p);
               localCounter = localMinuteWithDays;
               }
               
            TF[tf][0][0] = iOpen(Symbol(), 1, p);
            TF[tf][0][1] = aggregatorHH[tf];
            TF[tf][0][2] = aggregatorLL[tf];
            TF[tf][0][4] = minute - (minute % tf);
            shift -= p;
            TFMinutesElapsed[tf] = p;
            TFAdditionalShift[tf] = shift;
            
            index = 0;
            for(k = 1; k < maxAggregatedCandles; k++)
               {
               index = p + 1;
               
               shift += minutesMissedInNewCycle;
               
               TF[tf][k][3] = iClose(Symbol(), 1, index);
               TF[tf][k][1] = iHigh(Symbol(), 1, index);
               TF[tf][k][2] = iLow(Symbol(), 1, index);
               
               aggregatorHH[tf] = TF[tf][k][1];
               aggregatorLL[tf] = TF[tf][k][2];
               
               localCounter = 0;
               for(p = index; p < index + tf + 1; p++)
                  {
                  TimeToStruct(iTime(_Symbol,1,p), structTime);
                  localMinute = structTime.min + structTime.hour * 60;
                  localMinuteWithDays = localMinute + structTime.day_of_year * 1440;
                  if(tf > 1440) 
                     {
                     weekDay = structTime.day_of_week;
                     localMinuteWithDays += yearStartShift;
                     localMinute = localMinuteWithDays;
                     }
                  if(localCounter != 0)
                     {
                     if(localMinuteWithDays + (tf - (localMinuteWithDays % divider) % tf) <= localCounter || localMinuteWithDays - localCounter > 0)
                        {
                        if(tf <= 1440)
                           {
                           if((int) (localCounter / 1440) > (int) (localMinuteWithDays / 1440) && localMinute + (tf - localMinute % tf) >= 1440)
                              {
                              minutesMissedInNewCycle = 1440 - localMinute - 1;
                              }
                           else
                              {
                              minutesMissedInNewCycle = tf - localMinute % tf - 1;
                              }   
                           minutesLeftForPrevCycleCompletion = localCounter % tf;
                           }
                        else
                           {
                           if(localMinuteWithDays - localCounter > 0) 
                              {
                              localMinuteWithDays -= yearStartShift;
                              if(weekDay < 6 && yearStartShift != 0) localCounter -= tf;
                              else localCounter -= yearStartShift;
                              if((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf != 0)
                                 {
                                 yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf - (weekDay - 1) * 1440);
                                 }
                              else
                                 {
                                 yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf - 1) * tf - (weekDay - 1) * 1440);
                                 } 
                              if(yearStartShift >= 10080) yearStartShift = 0;
                              localMinuteWithDays += yearStartShift;
                              }
                           minutesMissedInNewCycle = tf - localMinuteWithDays % tf - 1;
                           minutesLeftForPrevCycleCompletion = localCounter % tf;
                           } 
                        if(minutesLeftForPrevCycleCompletion + minutesMissedInNewCycle > 0)
                           {
                           shift += minutesLeftForPrevCycleCompletion;
                           }
                        p--;   
                        break;   
                        }
                     if(localCounter - localMinuteWithDays > 1)
                        {
                        shift += localCounter - localMinuteWithDays - 1;
                        }
                     }   
                  if(iHigh(Symbol(), 1, p) > aggregatorHH[tf]) aggregatorHH[tf] = iHigh(Symbol(), 1, p);
                  if(iLow(Symbol(), 1, p) < aggregatorLL[tf]) aggregatorLL[tf] = iLow(Symbol(), 1, p);
                  localCounter = localMinuteWithDays;
                  TF[tf][k][4] = localMinute - (localMinute % tf);
                  if(tf > 1440) 
                     {
                     if((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf != 0)
                        {
                        yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf) * tf - (weekDay - 1) * 1440);
                        }
                     else
                        {
                        yearStartShift = tf - ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) - (structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) % 1440 - (int) ((structTime.min + structTime.hour * 60 + structTime.day_of_year * 1440) / tf - 1) * tf - (weekDay - 1) * 1440);
                        } 
                     if(yearStartShift >= 10080) yearStartShift = 0;
                     }
                  }
               
               TF[tf][k][0] = iOpen(Symbol(), 1, p);
               TF[tf][k][1] = aggregatorHH[tf];
               TF[tf][k][2] = aggregatorLL[tf];
               TF[tf][k][5] = shift;
               }
            aggregatorHH[tf] = TF[tf][0][1];
            aggregatorLL[tf] = TF[tf][0][2];
            }
         }
      }            
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Trade Time Visualization----------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

const string hoursStartText = "Interval start ";
const string hoursEndText = "Interval end ";
const color hoursClr = clrBlue;
const ENUM_LINE_STYLE hoursStyle = STYLE_DASHDOT;

void visualizeTradeHours()
   {
   int i;
   const double dayLow = iLow(_Symbol,PERIOD_D1,0) - (iHigh(_Symbol,PERIOD_D1,0) - iLow(_Symbol,PERIOD_D1,0)) * 0.05; 
   const double dayHigh = iHigh(_Symbol,PERIOD_D1,0) + (iHigh(_Symbol,PERIOD_D1,0) - iLow(_Symbol,PERIOD_D1,0)) * 0.05;
   const datetime cur = TimeCurrent();
   const int days = (int) cur / 86400;
   static datetime timeStart;
   static datetime timeEnd;
   
   for(i = 0; i < ArraySize(hourIntervals); i++)
      {
      timeStart = cur - (cur % 86400) + tradeIntervals[i][0][0] * 3600 + tradeIntervals[i][0][1] * 60;
      timeEnd = cur - (cur % 86400) + tradeIntervals[i][1][0] * 3600 + tradeIntervals[i][1][1] * 60;
      
      createLine(hoursStartText + (string) timeStart + (string) days,timeStart,timeStart,dayLow,hoursClr,hoursStyle,dayHigh);
      createLine(hoursEndText + (string) timeEnd + (string) days,timeEnd,timeEnd,dayLow,hoursClr,hoursStyle,dayHigh);
      createLine(hoursStartText + (string) i + (string) days,timeStart,timeEnd,dayHigh,hoursClr,hoursStyle);
      createLine(hoursEndText + (string) i + (string) days,timeEnd,timeStart,dayLow,hoursClr,hoursStyle);
      }
   }
   
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Positions Visualization----------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
//Positions visualization
const color sweepColor = clrBlack, bosColor = clrRed, limitColor = clrIndianRed;
const string sweepText = "sweep ", bosText = "bos ", posText = "position ", limitText = "limit ";
const color posPlacedSLColor = clrLightPink, posPlacedTPColor = clrPaleGreen, posWinSLColor = clrMistyRose, posWinTPColor = clrLimeGreen, posLoseSLColor = clrRed, posLoseTPColor = clrHoneydew;
const color btsstbColor = clrBlue, absorptionColor = clrPurple, orderblockColor = clrThistle, FVGColor = clrPowderBlue;
const color premdiscLongColor = clrMediumBlue, premdiscShortColor = clrBrown, premColor = clrPeachPuff, discColor = clrPaleTurquoise;
const int posWidthMultiplier = 12;

void posNewSweepBos(int sweepedIndex, int sweepIndex, int bosedSwingIndex, int bosIndex, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime sweepStart = IndexToTime(sweepedIndex,tf), sweepEnd = IndexToTime(sweepIndex,tf);
   const double sweepPrice = stopLoss > takeProfit ? TF[tf][sweepedIndex][1] : TF[tf][sweepedIndex][2];
   createLine(sweepText + (string) sweepStart, sweepStart, sweepEnd, sweepPrice, sweepColor);
   
   const datetime bosStart = IndexToTime(bosedSwingIndex,additionalTimeframe), bosEnd = IndexToTime(bosIndex,additionalTimeframe);
   const double bosPrice = stopLoss > takeProfit ? TF[additionalTimeframe][bosedSwingIndex][2] : TF[additionalTimeframe][bosedSwingIndex][1];
   createLine(bosText + (string) sweepStart, bosStart, bosEnd, bosPrice, bosColor);
   
   drawPosition(bosIndex, limit, stopLoss, takeProfit, tf, additionalTimeframe);
   }
   
void posBreaker(int breakerIndex, int bosIndex, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start = IndexToTime(breakerIndex,tf), end = IndexToTime(bosIndex,tf);
   const double breakerHighPrice = stopLoss > takeProfit ? TF[tf][breakerIndex][0] : TF[tf][breakerIndex][3];
   const double breakerLowPrice = stopLoss > takeProfit ? TF[tf][breakerIndex][3] : TF[tf][breakerIndex][0];
   createLine(sweepText + (string) start, start, end, breakerHighPrice, bosColor);
   createLine(bosText + (string) start, start, end, breakerLowPrice, bosColor);
   
   drawPosition(bosIndex, limit, stopLoss, takeProfit, tf);
   }
   
void posAbsorption(int entryIndex, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start = IndexToTime(entryIndex,tf), end = IndexToTime(entryIndex-1,tf);
   const double priceHigh = stopLoss > takeProfit ? TF[tf][entryIndex][1] : (TF[tf][entryIndex][3] > TF[tf][entryIndex][0] ? TF[tf][entryIndex][3] : TF[tf][entryIndex][0]);
   const double priceLow = stopLoss > takeProfit ? (TF[tf][entryIndex][3] < TF[tf][entryIndex][0] ? TF[tf][entryIndex][3] : TF[tf][entryIndex][0]) : TF[tf][entryIndex][2];
   createLine(sweepText + (string) start, start, end, priceHigh, absorptionColor);
   createLine(bosText + (string) start, start, end, priceLow, absorptionColor);
   
   drawPosition(entryIndex - 1, limit, stopLoss, takeProfit, tf);
   }
   
void posBtsstb(int swing1Index, int bos1Index, int swing2Index, int bos2Index, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start1 = IndexToTime(swing1Index,tf), end1 = IndexToTime(bos1Index,tf);
   const double price1 = stopLoss > takeProfit ? TF[tf][swing1Index][1] : TF[tf][swing1Index][2];
   const datetime start2 = IndexToTime(swing2Index,tf), end2 = IndexToTime(bos2Index,tf);
   const double price2 = stopLoss > takeProfit ? TF[tf][swing2Index][2] : TF[tf][swing2Index][1];
   
   createLine(sweepText + (string) start1, start1, end1, price1, btsstbColor);
   createLine(bosText + (string) start2, start2, end2, price2, bosColor);
   
   drawPosition(bos2Index, limit, stopLoss, takeProfit, tf);
   }
   
void posOrderblock(int obIndex, int limitIndex, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start = IndexToTime(obIndex,tf), end = IndexToTime(limitIndex-1,tf);
   const double priceHigh = TF[tf][obIndex][1];
   const double priceLow = TF[tf][obIndex][2] - _Point;
   createRectangle(sweepText + (string) start, start, end, priceLow, priceHigh, orderblockColor);
   
   drawPosition(limitIndex, limit, stopLoss, takeProfit, tf);
   }
   
void posFVG(int FVGIndexLeft, int FVGIndexRight, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start = IndexToTime(FVGIndexLeft - 1,tf), end = IndexToTime(FVGIndexRight-1,tf);
   const double priceHigh = stopLoss > takeProfit ? TF[tf][FVGIndexLeft][2] : TF[tf][FVGIndexRight][2];
   const double priceLow = stopLoss > takeProfit ? TF[tf][FVGIndexRight][1] : TF[tf][FVGIndexLeft][1];
   createRectangle(sweepText + (string) start, start, end, priceLow, priceHigh, FVGColor);
   
   drawPosition(FVGIndexRight, limit, stopLoss, takeProfit, tf);
   }
   
void posPremdisc(int rangeStartIndex, int rangeEndIndex, int bosIndex, double limit, double stopLoss, double takeProfit, int tf)
   {
   const datetime start1 = IndexToTime(rangeStartIndex,tf), end1 = IndexToTime(bosIndex,tf);
   const double price1 = stopLoss > takeProfit ? TF[tf][rangeStartIndex][2] : TF[tf][rangeStartIndex][1];
   const datetime start2 = IndexToTime(rangeEndIndex,tf), end2 = IndexToTime(bosIndex - 1,tf);
   const double price2 = stopLoss > takeProfit ? TF[tf][rangeEndIndex][1] : TF[tf][rangeEndIndex][2];
   
   createLine(sweepText + (string) start1, start1, end1, price1, stopLoss > takeProfit ? premdiscShortColor : premdiscLongColor);
   createLine(sweepText + (string) start2, start2, end2, price2, stopLoss > takeProfit ? premdiscShortColor : premdiscLongColor);
   //createLine(sweepText + (string) start2, start2, end2, price2, stopLoss > takeProfit ? premdiscShortColor : premdiscLongColor);
   createRectangle(bosText + (string) start2, start2, end2, limit, price2, stopLoss > takeProfit ? premColor : discColor);
   
   drawPosition(1, limit, stopLoss, takeProfit, tf);
   }
   
void drawPosition(int index, double limit, double stopLoss, double takeProfit, int tf, int secondaryTf = 0)
   {
   if(secondaryTf == 0) secondaryTf = tf;
   const datetime posStart = IndexToTime(index - 1,secondaryTf);
   const datetime posEnd = posStart + posWidthMultiplier * tf * 60;
   createRectangle(posText + (string) posStart, posStart, posEnd, stopLoss < takeProfit ? stopLoss : limit, stopLoss < takeProfit ? limit : stopLoss, posPlacedSLColor);
   createRectangle(posText + (string) posStart + (string) posEnd, posStart, posEnd, stopLoss < takeProfit ? limit : takeProfit, stopLoss < takeProfit ? takeProfit : limit, posPlacedTPColor);
   }   

void posUpdateOpened()
   {
   for(int i = 0; i < ArraySize(openedPositions); i++)
      {
      ObjectSetInteger(0,openedPositions[i].SLText,OBJPROP_TIME,1,TimeCurrent());
      ObjectSetInteger(0,openedPositions[i].SLText,OBJPROP_TIME,2,TimeCurrent());
      ObjectSetInteger(0,openedPositions[i].TPText,OBJPROP_TIME,1,TimeCurrent());
      ObjectSetInteger(0,openedPositions[i].TPText,OBJPROP_TIME,2,TimeCurrent());
      }
   updateOrders();
   }

void posUpdate(int index, double priceOut = 0)
   {
   const string SLText = posText + (string) orders[index].formationTime;
   const string TPText = posText + (string) orders[index].formationTime + (string) (orders[index].formationTime + posWidthMultiplier * orders[index].timeframe * 60);
   const bool buy = orders[index].stopLoss < orders[index].takeProfit;
   if(orders[index].fillTime != 0)
      {
      const datetime posStart = orders[index].fillTime;
      
      double SLLow = buy ? orders[index].stopLoss : orders[index].limit;
      double SLHigh = buy ? orders[index].limit : orders[index].stopLoss;
      double TPLow = buy ? orders[index].limit : orders[index].takeProfit;
      double TPHigh = buy ? orders[index].takeProfit : orders[index].limit;
      
      datetime posEnd = posStart + posWidthMultiplier * orders[index].timeframe * 60;
      color SLColor = posPlacedSLColor, TPColor = posPlacedTPColor;
      if(orders[index].SLTime != 0)
         {
         if(priceOut != 0)
            {
            if(buy) SLLow = priceOut;
            else SLHigh = priceOut;
            }
         posEnd = orders[index].SLTime;
         TPColor = posLoseTPColor;
         SLColor = posLoseSLColor;
         posClose(orders[index].ticket);
         }
      else if(orders[index].TPTime != 0)   
         {
         if(priceOut != 0)
            {
            if(buy) TPHigh = priceOut;
            else TPLow = priceOut;
            }
         posEnd = orders[index].TPTime;
         TPColor = posWinTPColor;
         SLColor = posWinSLColor;
         posClose(orders[index].ticket);
         }
      else posOpen(orders[index].ticket, SLText, TPText);
         
      createRectangle(SLText, posStart, posEnd, SLLow, SLHigh, SLColor);  
      createRectangle(TPText, posStart, posEnd, TPLow, TPHigh, TPColor);
      createLine(limitText + (string) posStart, orders[index].limitCandleTime, posStart, orders[index].limit, limitColor,STYLE_DOT);
      }
   else
      {
      ObjectsDeleteAll(0,SLText);
      ObjectsDeleteAll(0,TPText);
      }   
   }

void posOpen(ulong ticket, string SLText, string TPText)
   {
   Position localPosition;
   
   localPosition.ticket = ticket;
   localPosition.SLText = SLText;
   localPosition.TPText = TPText;
   
   ArrayResize(openedPositions, ArraySize(openedPositions) + 1);
   openedPositions[ArraySize(openedPositions) - 1] = localPosition;
   }

void posClose(ulong ticket)
   {
   for(int i = 0; i < ArraySize(openedPositions); i++)
      {
      if(openedPositions[i].ticket == ticket)
         {
         for(int j = 0; j + i < ArraySize(openedPositions) - 1; j++)
            {
            openedPositions[j + i].ticket = openedPositions[j + i + 1].ticket;
            openedPositions[j + i].SLText = openedPositions[j + i + 1].SLText;
            openedPositions[j + i].TPText = openedPositions[j + i + 1].TPText;
            }
         ArrayResize(openedPositions, ArraySize(openedPositions) - 1);
         break;
         }
      }
   }
   
void removeArrows() 
   { 
   ObjectsDeleteAll(0,0,OBJ_ARROW);
   }

void createLine(string text, datetime start, datetime end, double price, color clr, ENUM_LINE_STYLE style = STYLE_SOLID, double additionalPrice = 0, long tf = OBJ_ALL_PERIODS)
   {
   if(additionalPrice == 0) additionalPrice = price;
   ObjectCreate(0,text,OBJ_TREND,0,start,price,end,additionalPrice);
   ObjectSetInteger(0,text,OBJPROP_BACK,true);
   ObjectSetInteger(0,text,OBJPROP_PERIOD,tf);
   ObjectSetInteger(0,text,OBJPROP_TIMEFRAMES,tf);
   ObjectSetInteger(0,text,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,text,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,text,OBJPROP_STYLE,style);
   }
   
void createRectangle(string text, datetime start, datetime end, double priceLow, double priceHigh, color clr, bool back = true, long tf = OBJ_ALL_PERIODS)
   {
   ObjectCreate(0,text,OBJ_RECTANGLE,0,start,priceLow,end,priceHigh);
   ObjectSetInteger(0,text,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,text,OBJPROP_FILL,true);
   ObjectSetInteger(0,text,OBJPROP_BACK,back);
   ObjectSetInteger(0,text,OBJPROP_PERIOD,tf);
   ObjectSetInteger(0,text,OBJPROP_TIMEFRAMES,tf);
   if(ObjectGetInteger(0,"showHide",OBJPROP_STATE) == 1 && StringFind(text,posText) != -1) ObjectSetInteger(0,text,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Analytics Chart Functions--------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

//analytics window visualization
int analyticsWindowY;
int analyticsMainFontSize = (int) (16 * DPIMultiplier - DPIMultiplier), analyticsCellFontSize = (int) (15 * DPIMultiplier - DPIMultiplier), analyticsRows = 6;
const int analyticsRowHeight = (int) (30 * DPIMultiplier), analyticsBorderOffset = (int) (7 * DPIMultiplier), analyticsCellBorderOffset = (int) (2 * DPIMultiplier), analyticsCellValueBorderOffset = (int) (17 * DPIMultiplier);
const int chartWindowHeight = (int) (200 * DPIMultiplier);
const int analyticsWindowWidth = (int) (200 * DPIMultiplier), analyticsWindowHeight = analyticsRowHeight * analyticsRows, analyticsWindowX = (int) (4 * DPIMultiplier);

Chart balanceChart;
CGraphic balanceGraphic;
CCurve *balanceCurve;
void analyticsWindowCreate()
   {
   analyticsWindowY = trendWindowHeight + trendWindowY + analyticsWindowX;
   analyticsWindow.CreateBitmapLabel("analytics",analyticsWindowX,analyticsWindowY,crypto? analyticsWindowWidth + analyticsWindowWidth / 5 * 2 : analyticsWindowWidth,analyticsWindowHeight);
   analyticsWindow.Update();
   
   balanceChart.name = "Analytics Chart";
   balanceChart.curve1Name = "";
   balanceChart.XName = "USD";
   balanceChart.YName = "Poitions";
   ArrayResize(balanceChart.X, 1);
   ArrayResize(balanceChart.Y1, 1);
   balanceChart.X[0] = 0;
   balanceChart.Y1[0] = AccountInfoDouble(ACCOUNT_BALANCE);
   balanceGraphic.Create(0,balanceChart.name,0,analyticsWindowX,analyticsWindowY + analyticsWindowHeight + analyticsWindowX,analyticsWindowWidth + analyticsWindowX,analyticsWindowY + analyticsWindowHeight * 2);
   
   balanceCurve=balanceGraphic.CurveAdd(balanceChart.X,balanceChart.Y1,CURVE_LINES);
   balanceCurve.Name(balanceChart.curve1Name);   
   balanceCurve.Type(CURVE_STEPS);      
   balanceCurve.Color(clrRed);        
   balanceGraphic.XAxis().Name(balanceChart.XName);      
   balanceGraphic.XAxis().NameSize(18);          
   balanceGraphic.YAxis().Name(balanceChart.YName);      
   balanceGraphic.YAxis().NameSize(18); 
   balanceGraphic.GapSize(0);
   //balanceGraphic.GridLineColor(clrWhite);
   balanceGraphic.IndentRight((int) (-64));
   balanceGraphic.IndentDown((int) (-15));
   balanceGraphic.IndentLeft((int) (-16));
   balanceGraphic.IndentUp((int) (8));
   analyticsWindowVisualize(-1);
   }
   
const color analyticsMainTextClr = clrMaroon;
const color analyticsDaysTextClr = clrMediumVioletRed;

int longWinrate = 0, shortWinrate = 0;
int longWins = 0, shortWins = 0;
int longLoses = 0, shortLoses = 0;
int winrateByDays[7];
int winsByDays[7];
int losesByDays[7];
int totalFilled = 0;
double avgPipsWin = 0;
double avgPipsLoss = 0;
double totalPipsWin = 0;
double totalPipsLoss = 0;
int bestIntervalWinrate = 0;
string bestInterval = "00:00-00:30";

struct intervals {
   string time[48];
   int winrate[48];
   int wins[48];
   int loses[48];
   intervals();
};
intervals::intervals() {
   const string buf[] ={"00:00-00:30","00:30-01:00",
                        "01:00-01:30","01:30-02:00",
                        "02:00-02:30","02:30-03:00",
                        "03:00-03:30","03:30-04:00",
                        "04:00-04:30","04:30-05:00",
                        "05:00-05:30","05:30-06:00",
                        "06:00-06:30","06:30-07:00",
                        "07:00-07:30","07:30-08:00",
                        "08:00-08:30","08:30-09:00",
                        "09:00-09:30","09:30-10:00",
                        "10:00-10:30","10:30-11:00",
                        "11:00-11:30","11:30-12:00",
                        "12:00-12:30","12:30-13:00",
                        "13:00-13:30","13:30-14:00",
                        "14:00-14:30","14:30-15:00",
                        "15:00-15:30","15:30-16:00",
                        "16:00-16:30","16:30-17:00",
                        "17:00-17:30","17:30-18:00",
                        "18:00-18:30","18:30-19:00",
                        "19:00-19:30","19:30-20:00",
                        "20:00-20:30","20:30-21:00",
                        "21:00-21:30","21:30-22:00",
                        "22:00-22:30","22:30-23:00",
                        "23:00-23:30","23:30-24:00"};
   const int winrateBuf[] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
   ArrayInsert(time, buf, 0);
   ArrayInsert(winrate, winrateBuf, 0);
   ArrayInsert(wins, winrateBuf, 0);
   ArrayInsert(loses, winrateBuf, 0);
}

intervals timeIntervals;

void updateAnalytics(int index)
   {
   totalFilled++; 
   const bool win = orders[index].win == 1 ? true : false;
   const bool isLong = orders[index].stopLoss > orders[index].takeProfit ? false : true;
   TimeToStruct(orders[index].formationTime,structTime);
   const int dayOfWeek = crypto ? (structTime.day_of_week == 0 ? 6 : structTime.day_of_week - 1) : (structTime.day_of_week > 5 ? 4 : (structTime.day_of_week > 0 ? structTime.day_of_week - 1 : 0));
   const int intervalIndex = structTime.hour * 2 + structTime.min / 30;
   const int initialIntervalWinrate = timeIntervals.winrate[intervalIndex];
   const double pips = isLong ? (orders[index].limit - orders[index].stopLoss) * pipsDelta : (orders[index].stopLoss - orders[index].limit) * pipsDelta;
   
   if(win)
      {
      winsByDays[dayOfWeek]++;
      winrateByDays[dayOfWeek] = (int) ((double) winsByDays[dayOfWeek] / (winsByDays[dayOfWeek] + losesByDays[dayOfWeek]) * 100);
      timeIntervals.wins[intervalIndex]++;
      timeIntervals.winrate[intervalIndex] = (int) ((double) timeIntervals.wins[intervalIndex] / (timeIntervals.wins[intervalIndex] + timeIntervals.loses[intervalIndex]) * 100);
      totalPipsWin += pips;
      if(isLong)
         {
         longWins++;
         longWinrate = (int) ((double) longWins / (longWins + longLoses) * 100);
         }
      else
         {
         shortWins++;
         shortWinrate = (int) ((double) shortWins / (shortWins + shortLoses) * 100);
         }
      avgPipsWin = StringToDouble(DoubleToString(totalPipsWin / (shortWins + longWins),1));
      }
   else
      {
      losesByDays[dayOfWeek]++;
      winrateByDays[dayOfWeek] = (int) ((double) winsByDays[dayOfWeek] / (winsByDays[dayOfWeek] + losesByDays[dayOfWeek]) * 100);
      timeIntervals.loses[intervalIndex]++;
      timeIntervals.winrate[intervalIndex] = (int) ((double) timeIntervals.wins[intervalIndex] / (timeIntervals.wins[intervalIndex] + timeIntervals.loses[intervalIndex]) * 100);
      totalPipsLoss += pips;
      if(isLong)
         {
         longLoses++;
         longWinrate = (int) ((double) longWins / (longWins + longLoses) * 100);
         }
      else
         {
         shortLoses++;
         shortWinrate = (int) ((double) shortWins / (shortWins + shortLoses) * 100);
         }
      avgPipsLoss = StringToDouble(DoubleToString(totalPipsLoss / (shortLoses + longLoses),1));
      }
   
   if(bestIntervalWinrate != initialIntervalWinrate || win)
      {
      if(timeIntervals.winrate[intervalIndex] >= bestIntervalWinrate)
         {
         bestIntervalWinrate = timeIntervals.winrate[intervalIndex];
         bestInterval = timeIntervals.time[intervalIndex];
         }
      }
   else
      {
      int localBestWinrate = timeIntervals.winrate[intervalIndex];
      int localBestWinrateIndex = intervalIndex;
      for(int i = 0; i < 48; i++)
         {
         if(timeIntervals.winrate[i] > localBestWinrate)
            {
            localBestWinrate = timeIntervals.winrate[i];
            localBestWinrateIndex = i;
            }
         }
      bestIntervalWinrate = localBestWinrate;
      bestInterval = timeIntervals.time[localBestWinrateIndex];
      }
   }

void buildAnalyticsCarcass()
   {
   int i;
   // lines
   analyticsWindow.LineThickVertical(0,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   analyticsWindow.LineThickVertical(analyticsWindowWidth - 1,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   analyticsWindow.LineThickHorizontal(0,1000,0,clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   analyticsWindow.LineThickHorizontal(0,1000,analyticsWindowHeight - 1, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   
   if(crypto)
      {
      analyticsWindow.LineThickVertical(analyticsWindowWidth + analyticsWindowWidth / 5 * 2 - 1,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - analyticsWindowWidth / 5,rowHeight * 1,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth + analyticsWindowWidth / 5,rowHeight * 1,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,0,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3,rowHeight,rowHeight * 3, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 4,rowHeight,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,rowHeight * 3,rowHeight * 4, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,rowHeight * 5,rowHeight * 6, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      }
   else
      {
      analyticsWindow.LineThickVertical(analyticsWindowWidth - analyticsWindowWidth / 5,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,0,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3,rowHeight,rowHeight * 3, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 4,rowHeight,rowHeight * 2, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,rowHeight * 3,rowHeight * 4, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      analyticsWindow.LineThickVertical(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2,rowHeight * 5,rowHeight * 6, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      }   
   
   for(i = 1; i < analyticsRows; i++)
      {
      analyticsWindow.LineThickHorizontal(0,1000,i * rowHeight, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      }
   // texts
   analyticsWindow.FontSet("Arial",analyticsMainFontSize);
   analyticsWindow.FontFlagsSet(FW_BOLD);
   
   analyticsWindow.TextOut((int) borderOffset, borderOffset, "Winrate:", analyticsMainTextClr);
   analyticsWindow.TextOut((int) borderOffset, borderOffset + analyticsRowHeight * 2, "Best time:", analyticsMainTextClr);
   analyticsWindow.TextOut((int) borderOffset, borderOffset + analyticsRowHeight * 3, "Orders:", analyticsMainTextClr);
   analyticsWindow.TextOut((int) borderOffset, borderOffset + analyticsRowHeight * 4, "Orders skipped by pips:", analyticsMainTextClr);
   analyticsWindow.TextOut((int) borderOffset, borderOffset + analyticsRowHeight * 5, "AVG pips:", analyticsMainTextClr);
   
   analyticsWindow.FontSet("Bauhaus 93",analyticsMainFontSize);
   analyticsWindow.FontFlagsSet(FW_BOLD);
   
   i = 1;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) longWinrate + "%", clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) shortWinrate + "%", clrBlack);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) longWinrate + "%", clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) shortWinrate + "%", clrBlack);
      }   
   i++;
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[0] + "%", clrBlack);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 4 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[1] + "%", clrBlack);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[2] + "%", clrBlack);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[3] + "%", clrBlack);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 1 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[4] + "%", clrBlack);
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth + (analyticsWindowWidth / 5) * 0 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[5] + "%", clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth + (analyticsWindowWidth / 5) * 1 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) winrateByDays[6] + "%", clrBlack);
      }
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 - (int) (11 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, bestInterval, clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) bestIntervalWinrate + "%", clrBlack);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3 + (int) (7 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, bestInterval, clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) bestIntervalWinrate + "%", clrBlack);
      }   
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) ArraySize(orders), clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) totalFilled, clrBlack);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) ArraySize(orders), clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) totalFilled, clrBlack);
      }   
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset - (int) (5 * DPIMultiplier), (string) ArraySize(invalidOrders), clrBlack);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset - (int) (5 * DPIMultiplier), (string) ArraySize(invalidOrders), clrBlack);
      }  
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) - (int) (8 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) avgPipsWin, clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (8 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) avgPipsLoss, clrBlack);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (10 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) avgPipsWin, clrBlack);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (10 * DPIMultiplier), analyticsRowHeight * i - analyticsCellValueBorderOffset, (string) avgPipsLoss, clrBlack);
      }
   
   analyticsWindow.FontSet("Bauhaus 93",analyticsMainFontSize - (int) (2 * DPIMultiplier + DPIMultiplier));
   i = 1;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 - (int) (10 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Long", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (11 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Short", analyticsDaysTextClr);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (8 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Long", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (7 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Short", analyticsDaysTextClr);
      }  
   i++;
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 5 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Mon", analyticsDaysTextClr);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 4 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Tue", analyticsDaysTextClr);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Wed", analyticsDaysTextClr);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Thu", analyticsDaysTextClr);
   analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 1 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Fri", analyticsDaysTextClr);
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth + (analyticsWindowWidth / 5) * 0 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Sat", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth + (analyticsWindowWidth / 5) * 1 + (int) (9 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Sun", analyticsDaysTextClr);
      }
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (2 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Interval", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (6 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "WR", analyticsDaysTextClr);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 3 + (int) (23 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Interval", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (12 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "WR", analyticsDaysTextClr);
      }  
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) - (int) (13 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Placed", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (10 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Filled", analyticsDaysTextClr);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (5 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Placed", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (8 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Filled", analyticsDaysTextClr);
      }  
   i++;
   i++;
   if(crypto)
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) - (int) (6 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Win", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth + analyticsWindowWidth / 5 - (int) (10 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Loss", analyticsDaysTextClr);
      }
   else
      {
      analyticsWindow.TextOut(analyticsWindowWidth - (analyticsWindowWidth / 5) * 2 + (int) (12 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Win", analyticsDaysTextClr);
      analyticsWindow.TextOut(analyticsWindowWidth - analyticsWindowWidth / 5 + (int) (8 * DPIMultiplier), analyticsRowHeight * (i - 1) + analyticsCellBorderOffset, "Loss", analyticsDaysTextClr);
      } 
   }

void analyticsWindowVisualize(int index)
   {
   if(index != -1) updateAnalytics(index);
   
   analyticsWindow.Erase(clrWhite);
   
   // creation of analytics window carcass
   buildAnalyticsCarcass();
   
   analyticsWindow.Update();
   
   if(ArraySize(orders) > 0)
      {
      ArrayResize(balanceChart.X, ArraySize(balanceChart.X) + 1);
      ArrayResize(balanceChart.Y1, ArraySize(balanceChart.Y1) + 1);
      balanceChart.X[ArraySize(balanceChart.X) - 1] = ArraySize(balanceChart.X) - 1;
      balanceChart.Y1[ArraySize(balanceChart.Y1) - 1] = AccountInfoDouble(ACCOUNT_BALANCE);
      }
      
   balanceCurve.Update(balanceChart.X, balanceChart.Y1);
   balanceGraphic.CurvePlotAll();
   balanceGraphic.Redraw(true);
   balanceGraphic.LineAdd(0,analyticsWindowHeight - (int) (5 * DPIMultiplier),1000,analyticsWindowHeight - (int) (5 * DPIMultiplier),clrBlack,STYLE_DOT);
   balanceGraphic.LineAdd(0,0,1000,0,clrBlack,STYLE_DOT);
   balanceGraphic.LineAdd(analyticsWindowWidth - 1,0,analyticsWindowWidth - 1,1000,clrBlack,STYLE_DOT);
   balanceGraphic.LineAdd(0,0,0,1000,clrBlack,STYLE_DOT);
   balanceGraphic.Update();
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Trend Window Visualization-------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

int trendWindowHeight;
const int trendWindowWidth = (int) (200 * DPIMultiplier), trendWindowX = (int) (4 * DPIMultiplier), trendWindowY = (int) (15 * DPIMultiplier);
const int rowHeight = (int) (30 * DPIMultiplier), borderOffset = (int) (7 * DPIMultiplier);
const int fontSize = (int) (18 * DPIMultiplier - DPIMultiplier);

int trendWindowStructure[40][3];

void trendWindowCreate()
   {
   trendWindowHeight = (int) (((ArraySize(trendTfs) + 1) * rowHeight));
   trendWindow.CreateBitmapLabel("rect",trendWindowX,trendWindowY,trendWindowWidth,trendWindowHeight);
   }   

void trendWindowVisualize()
   {
   static string arrow;
   static color clr; 
   static int i;
   trendWindow.Erase(clrWhite);
   
   // creation of trend window carcass
   
   trendWindow.FontSet("Arial",fontSize);
   trendWindow.FontFlagsSet(FW_BOLD);
   
   trendWindow.TextOut((int) (50 * DPIMultiplier), borderOffset, "Structure", clrBlack);
   trendWindow.TextOut((int) (138 * DPIMultiplier), borderOffset, "Trend", clrBlack);
   trendWindow.LineThickVertical((int) (45 * DPIMultiplier),0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   trendWindow.LineThickVertical((int) (120 * DPIMultiplier),0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   
   trendWindow.TextOut((int) (14 * DPIMultiplier), borderOffset, "TF", clrBlack);
   
   trendWindow.LineThickVertical(0,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   trendWindow.LineThickVertical(trendWindowWidth - 1,0,1000, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   trendWindow.LineThickHorizontal(0,1000,0,clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   trendWindow.LineThickHorizontal(0,1000,trendWindowHeight - 1, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
   
   for(i = 0; i < ArraySize(trendTfs); i++)
      {
      trendWindow.LineThickHorizontal(0,1000,(i+1) * rowHeight, clrBlack,1,STYLE_DOT,LINE_END_ROUND);
      
      fillStructure(trendWindowStructure,trendTfs[i]);
      
      fillRanges(trendTfs[i]);
   
      trendWindow.FontSet("Arial",fontSize);
      trendWindow.FontFlagsSet(FW_BOLD);
      
      trendWindow.TextOut(borderOffset, (i+1) * rowHeight + borderOffset, MinutesToTF(trendTfs[i]), clrBlack);
      
      trendWindow.FontSet("Wingdings",fontSize);
      // structure
      arrow = lastStructure == 1 ? CharToString(233) : CharToString(234);
      clr = lastStructure == 1 ? clrGreen : clrBlue;
      trendWindow.TextOut((int) (78 * DPIMultiplier), (i+1) * rowHeight + borderOffset, arrow, clr);
      
      // trend
      arrow = TFTrend[trendTfs[i]] == 1 ? CharToString(233) : CharToString(234);
      clr = TFTrend[trendTfs[i]] == 1 ? clrGreen : clrBlue;
      trendWindow.TextOut((int) (153 * DPIMultiplier), (i+1) * rowHeight + borderOffset, arrow, clr);
      }
   trendWindow.Update();
   }
void addTrendWindowCurrentTF(int tf)
   {
   int i;
   for(i = 0; i < ArraySize(trendTfs); i++)
      {
      if(tf == trendTfs[i]) return;
      }
   ArrayResize(trendTfs, ArraySize(trendTfs) + 1);
   trendTfs[ArraySize(trendTfs) - 1] = tf;
   ArraySort(trendTfs);
   trendWindowHeight = (int) (((ArraySize(trendTfs) + 1) * rowHeight));
   trendWindow.Resize(trendWindowWidth, (int) (((ArraySize(trendTfs) + 1) * rowHeight)));
   trendWindowVisualize();
   moveButtons();
   }
   
void moveButtons()
   {
   ObjectSetInteger(0,"showHide",OBJPROP_YDISTANCE,ObjectGetInteger(0,"showHide",OBJPROP_YDISTANCE) + rowHeight);
   ObjectSetInteger(0,FVGButtonText,OBJPROP_YDISTANCE,ObjectGetInteger(0,FVGButtonText,OBJPROP_YDISTANCE) + rowHeight);
   ObjectSetInteger(0,OBButtonText,OBJPROP_YDISTANCE,ObjectGetInteger(0,OBButtonText,OBJPROP_YDISTANCE) + rowHeight);
   ObjectSetInteger(0,SweepButtonText,OBJPROP_YDISTANCE,ObjectGetInteger(0,SweepButtonText,OBJPROP_YDISTANCE) + rowHeight);
   ObjectSetInteger(0,PremDiscButtonText,OBJPROP_YDISTANCE,ObjectGetInteger(0,PremDiscButtonText,OBJPROP_YDISTANCE) + rowHeight);
   }
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Buttons Visualization-------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

void checkButtonState()
   {
   static bool buttonState = false;
   if(ObjectGetInteger(0,"showHide",OBJPROP_STATE) != buttonState)
      {
      buttonState = ObjectGetInteger(0,"showHide",OBJPROP_STATE);
      ShowHidePositions(buttonState);
      }
   }
   
const int buttonWidth = trendWindowWidth, buttonHeight = rowHeight;
void ShowHidePositions(bool state)
   {
   int propVal=OBJ_ALL_PERIODS;
   if(state) 
      {
      propVal=OBJ_NO_PERIODS;
      ObjectSetString(0,"showHide",OBJPROP_TEXT,"Show positions");
      }
   else ObjectSetString(0,"showHide",OBJPROP_TEXT,"Hide positions");
   for(int i=ObjectsTotal(0,-1,OBJ_RECTANGLE)-1;i>=0;i--)
      {
      string ObjName=ObjectName(0,i,0,OBJ_RECTANGLE);
      if(StringFind(ObjName,posText) != -1) ObjectSetInteger(0,ObjName,OBJPROP_TIMEFRAMES,propVal);
      }
   ChartRedraw();   
   }
   
const int contextButtonWidth = trendWindowWidth / 2 - trendWindowX / 2, contextButtonHeight = rowHeight;
bool hideFVG = false, hideOB = false, hideSweep = false, hidePremDisc = false;
void ShowHideFVG(bool state)
   {
   ObjectSetString(0,FVGButtonText,OBJPROP_TEXT,state? "Show FVG" : "Hide FVG");
   hideFVG = state;
   if(state) ObjectsDeleteAll(0,FVGText);
   else visualizeContext();
   ChartRedraw();   
   }
void ShowHideOB(bool state)
   {
   ObjectSetString(0,OBButtonText,OBJPROP_TEXT,state? "Show OB" : "Hide OB");
   hideOB = state;
   if(state)
      {
      ObjectsDeleteAll(0,OBText);
      OBHide = state;
      }
   else visualizeContext();
   ChartRedraw();
   }
void ShowHideSweep(bool state)
   {
   ObjectSetString(0,SweepButtonText,OBJPROP_TEXT,state? "Show Sweeps" : "Hide Sweeps");
   hideSweep = state;
   if(state) ObjectsDeleteAll(0,SweepsText);
   else visualizeContext();
   ChartRedraw();   
   }
void ShowHidePremDisc(bool state)
   {
   ObjectSetString(0,PremDiscButtonText,OBJPROP_TEXT,state? "Show Ranges" : "Hide Ranges");
   hidePremDisc = state;
   if(state) 
      {
      ObjectsDeleteAll(0,PremDiscText);
      rangeHide = state;
      }
   else visualizeContext();
   ChartRedraw();   
   }
   
const long buttonTextFontSize = 11;
string FVGButtonText = "Button FVG", OBButtonText = "Button OB", SweepButtonText = "Button Sweep", PremDiscButtonText = "Button PremDisc";
void showHideButtonCreate()
   {
   long x = trendWindowX, y = live? trendWindowX * 3 + trendWindowY + trendWindowHeight + contextButtonHeight * 2 : trendWindowX + trendWindowHeight + analyticsWindowHeight + chartWindowHeight;
   buttonCreate("showHide",x,y,buttonWidth,buttonHeight,C'1,160,254',clrWhite,clrGray,"Hide positions", buttonTextFontSize);
   }   
   
void FVGButtonCreate()
   {
   long x = trendWindowX, y = trendWindowX + trendWindowY + trendWindowHeight;
   buttonCreate(FVGButtonText,x,y,contextButtonWidth,contextButtonHeight,C'1,160,254',clrWhite,clrGray,"Hide FVG", buttonTextFontSize);
   }  
void OBButtonCreate()
   {
   long x = trendWindowX * 2 + contextButtonWidth, y = trendWindowX + trendWindowY + trendWindowHeight;
   buttonCreate(OBButtonText,x,y,contextButtonWidth,contextButtonHeight,C'1,160,254',clrWhite,clrGray,"Hide OB", buttonTextFontSize);
   }  
void SweepButtonCreate()
   {
   long x = trendWindowX, y = trendWindowX * 2 + trendWindowY + trendWindowHeight + contextButtonHeight;
   buttonCreate(SweepButtonText,x,y,contextButtonWidth,contextButtonHeight,C'1,160,254',clrWhite,clrGray,"Hide Sweeps", buttonTextFontSize);
   }  
void PremDiscButtonCreate()
   {
   long x = trendWindowX * 2 + contextButtonWidth, y = trendWindowX * 2 + trendWindowY + trendWindowHeight + contextButtonHeight;
   buttonCreate(PremDiscButtonText,x,y,contextButtonWidth,contextButtonHeight,C'1,160,254',clrWhite,clrGray,"Hide Ranges",buttonTextFontSize);
   }  

void buttonCreate(string name, long x, long y, long width, long height, color bgColor, color textColor, color borderColor, string text, long buttonTextSize)
   {
   ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,INT_MAX);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,borderColor);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,buttonTextSize);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   }

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------Context Visualization-------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
   
int ranges[40][4]; // startIndex, endIndex, direction, bosIndex
bool rangeHide = true, OBHide = true;
void visualizeContext(bool tfChanged = false)
   {
   const int tf = PeriodSeconds() / 60;
   int counter = 0;
   if(addTF(tf,counter)) Aggregator(true);
   // добавить тф в тренд виндоу
   addTrendWindowCurrentTF(tf);
   
   // визуал премдиска
   if(rangeHide != hidePremDisc || tfChanged)
      {
      rangeHide = hidePremDisc;
      if(!hidePremDisc) 
         {
         clearRanges(true);
         fillRanges(tf, true);
         visualizeRanges(tf);
         }
      }
   
   // визуал ОБ
   if(OBHide != hideOB|| tfChanged)
      {
      OBHide = hideOB;
      if(!hideOB) 
         {
         clearStructure(timeframeStructure);
         clearOB(timeframeOBs, true);
         fillStructure(timeframeStructure,tf);
         fillOB(timeframeStructure,timeframeOBs,tf);
         visualizeOBs(timeframeOBs,tf);
         }
      }
   
   // визуал фвг
   clearFVG(timeframeFVGs, true);
   fillFVG(timeframeFVGs,tf);
   if(!hideFVG) visualizeFVGs(timeframeFVGs,tf);
   
   // визуал свипов
   clearSweeps();
   sweep(timeframeSweepForShort,timeframeSweepForLong,tf,false,true);
   if(!hideSweep) visualizeSweeps(tf);
   } 

const string FVGText = "FVG ", OBText = "OB ", SweepsText = "Sweep ", PremDiscText = "PremDisc ";

void visualizeRanges(int tf)
   {
   int i, j, closestIndex;
   datetime start1, start2, end1, end2, cur = TimeCurrent(); 
   double priceHigh, priceLow, priceMid;
   
   for(i = maxPOICount - 1; i >= 0; i--)
      {
      if(ranges[i][0] == 0) continue;
      end1 = IndexToTime((int) ranges[i][3],tf);
      end2 = cur + tf * 60;
      start1 = IndexToTime((int) ranges[i][0],tf);
      start2 = IndexToTime((int) ranges[i][1],tf);
      priceHigh = ranges[i][2] == 1 ? TF[tf][(int) ranges[i][0]][1] : TF[tf][(int) ranges[i][1]][1];
      priceLow = ranges[i][2] == 1 ? TF[tf][(int) ranges[i][1]][2] : TF[tf][(int) ranges[i][0]][2];
      priceMid = ranges[i][2] == 1 ? priceLow + (priceHigh - priceLow) * premdiscPercent / 100 : priceHigh - (priceHigh - priceLow) * premdiscPercent / 100;
      
      for(j = 0, closestIndex = -1; j < maxPOICount && ranges[j][0] != 0; j++)
         {
         if(j == i) continue;
         if(ranges[j][0] < ranges[i][0] && (closestIndex == -1 || ranges[j][0] > ranges[closestIndex][0])) closestIndex = j;
         }
      if(closestIndex != -1) end2 = IndexToTime(ranges[closestIndex][2] == ranges[i][2] ? (int) ranges[closestIndex][1] : (int) ranges[closestIndex][3],tf);
      
      for(j = ranges[i][1]; j > 0; j--)
         {
         if(closestIndex != -1 && j < ranges[closestIndex][1]) break;
         if((ranges[i][2] == 1 && TF[tf][j][3] < TF[tf][ranges[i][1]][2]) || (ranges[i][2] == -1 && TF[tf][j][3] > TF[tf][ranges[i][1]][1])) 
            {
            end2 = IndexToTime(j,tf);
            break;
            }
         }
      createLine(PremDiscText + MinutesToTF(tf) +" "+ sweepText + (string) start1, start1, end1, ranges[i][2] == 1 ? priceHigh : priceLow, ranges[i][2] == 1 ? premdiscShortColor : premdiscLongColor,STYLE_SOLID,0,PeriodForObject(_Period));
      createLine(PremDiscText + MinutesToTF(tf) +" "+ sweepText + (string) start2, start2, end2, ranges[i][2] == 1 ? priceLow : priceHigh, ranges[i][2] == 1 ? premdiscShortColor : premdiscLongColor,STYLE_SOLID,0,PeriodForObject(_Period));
      createRectangle(PremDiscText + MinutesToTF(tf) +" "+ (string) start2, start2, end2, priceMid, ranges[i][2] == 1 ? priceLow : priceHigh, ranges[i][2] == 1 ? premColor : discColor, true, PeriodForObject(_Period));  
      }
   }
   
const color orderblockLongColor = C'208, 191, 255', orderblockShortColor = clrThistle;
void visualizeOBs(double& OBs[][], int tf)
   {
   int i, j, closestIndex;
   datetime start, end, cur = TimeCurrent(); 
   for(i = 0; i < maxPOICount && OBs[i][0] != 0; i++)
      {
      end = cur + tf * 60;
      for(j = 0, closestIndex = -1; j < maxPOICount && OBs[j][0] != 0; j++)
         {
         if(j == i) continue;
         if(OBs[j][3] < OBs[i][3] && OBs[j][2] == OBs[i][2] && (closestIndex == -1 || OBs[j][3] > OBs[closestIndex][3])) closestIndex = j;
         }
      if(closestIndex != -1 && OBs[closestIndex][1] > OBs[i][0] && OBs[closestIndex][0] < OBs[i][1]) end = IndexToTime((int) OBs[closestIndex][3],tf);
      start = IndexToTime((int) OBs[i][3],tf);   
      createRectangle(OBText + MinutesToTF(tf) +" "+ (string) start, start, end, OBs[i][0], OBs[i][1], OBs[i][2] == 1 ? orderblockLongColor : orderblockShortColor, true, PeriodForObject(_Period));   
      }
   }
   
void visualizeFVGs(double& FVGs[][], int tf)
   {
   int i;
   datetime start, end, cur = TimeCurrent(); 
   for(i = 0; i < maxPOICount && FVGs[i][0] != 0; i++)
      {
      start = IndexToTime((int) FVGs[i][3],tf);   
      end = cur + tf * 60;
      createRectangle(FVGText + MinutesToTF(tf) +" "+ (string) start, start, end, FVGs[i][0], FVGs[i][1], FVGColor, true, PeriodForObject(_Period));   
      }
   }
   
double lastLongSweep[3], lastShortSweep[3];
void visualizeSweeps(int tf)
   {
   datetime start, end, cur = TimeCurrent();
   if(lastLongSweep[0] != 0)
      {
      start = IndexToTime((int) lastLongSweep[0],tf);   
      end = IndexToTime((int) lastLongSweep[1],tf);
      createLine(SweepsText + MinutesToTF(tf) +" long "+ (string) start, start, end, lastLongSweep[2], sweepColor, STYLE_SOLID, 0, PeriodForObject(_Period));
      }
   if(lastShortSweep[0] != 0)
      {
      start = IndexToTime((int) lastShortSweep[0],tf);   
      end = IndexToTime((int) lastShortSweep[1],tf);
      createLine(SweepsText + MinutesToTF(tf) +" short "+ (string) start, start, end, lastShortSweep[2], sweepColor, STYLE_SOLID, 0, PeriodForObject(_Period));
      }
   }
