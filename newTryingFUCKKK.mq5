#include <trade/trade.mqh>
enum smoothMode
  {
   SMA=0,// Simple MA
   EMA=1 // Exponential MA
  };
input int          InpSmoothPeriod=10;  // Smoothing period
input int          InpCHVPeriod=10;     // Chaikin Volatility period
input smoothMode smoothTypeInp=EMA;   // Smoothing Mode
input int InpMAPeriod=10; //MA Period
input ENUM_MA_METHOD InpMAMode=MODE_EMA; // MA Mode
input double lotSize=1.0;
input double slPips = 300;
input double tpPips = 600;
ulong posTicket;
int chv;
int ma;
int barsTotal;
double riskPercent=0.1;
CTrade trade;
int OnInit()
  {
   barsTotal=iBars(_Symbol,PERIOD_CURRENT);
   chv = iCustom(_Symbol,PERIOD_CURRENT,"Custom_CHV",InpSmoothPeriod,InpCHVPeriod, smoothTypeInp, lotSize, slPips, tpPips);
   ma=iMA(_Symbol,PERIOD_CURRENT, InpMAPeriod, 0, InpMAMode, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   Print("EA is removed");
  }
void OnTick()
  {
   int bars=iBars(_Symbol,PERIOD_CURRENT);
   if(barsTotal < bars)
     {
      barsTotal=bars;
      double chvInd[];
      double maInd[];
      CopyBuffer(chv,0,0,3,chvInd);
      ArraySetAsSeries(chvInd,true);
      CopyBuffer(ma,0,0,3,maInd);
      ArraySetAsSeries(maInd,true);
      double chvVal = NormalizeDouble(chvInd[0], 1);
      double chvValPrev = NormalizeDouble(chvInd[1], 1);
      double maVal = NormalizeDouble(maInd[0], 5);
      double maValPrev = NormalizeDouble(maInd[1], 5);
      double lastClose=iClose(_Symbol,PERIOD_CURRENT,1);
      double prevLastClose=iClose(_Symbol,PERIOD_CURRENT,2);

      if(prevLastClose<maValPrev && lastClose>maVal && chvVal>0)
        {
         if(posTicket>0){
           if(PositionSelectByTicket(posTicket)){
             if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               if(trade.PositionClose(posTicket)){
                 posTicket=0;
               }
             }
           }else{
              posTicket=0;
           }
         }
         if(posTicket<=0){
           double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
           double slVal = ask - slPips*_Point;
           double tpVal = ask + tpPips*_Point;
           double lotSizeNew=calcLots(riskPercent,ask-slVal);
           if(trade.Buy(lotSizeNew,_Symbol,ask,slVal,tpVal)){
             posTicket=trade.ResultOrder();
           }
         }
        }
      if(prevLastClose>maValPrev && lastClose<maVal && chvVal<0)
        {
         if(posTicket>0){
           if(PositionSelectByTicket(posTicket)){
             if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               if(trade.PositionClose(posTicket)){
                 posTicket=0;
               }
             }
           }else{
              posTicket=0;
           }
         }
         if(posTicket<=0){
           double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
           double slVal = bid + slPips*_Point;
           double tpVal = bid - tpPips*_Point;
           double lotSizeNew=calcLots(riskPercent,slVal-bid);
           if(trade.Sell(lotSizeNew,_Symbol,bid,slVal,tpVal)){
             posTicket=trade.ResultOrder();
           }
         }
        }
     }
  }
  
  double calcLots(double riskpercent, double slDistance){
  double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  
  if(tickSize==0 || tickValue==0 || lotstep==0){
    Print(__FUNCTION__,"LotsSize cannot be calculated");
    return 0;
  }
  
  double riskMoney=AccountInfoDouble(ACCOUNT_BALANCE)*riskpercent/100;
  double moneyLotsStep=(slDistance/tickSize)*tickValue*lotstep;
  
  if(moneyLotsStep==0){
    Print(__FUNCTION__,"LotsSize cannot be calculated");
    return 0;
  }
  
  double lotsNew=MathFloor(riskMoney/moneyLotsStep)*lotstep;
  return lotsNew;
}