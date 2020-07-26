#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <Trade\Trade.mqh>

#define TOSTRING(A)  #A + " = " + (string)(A) + "\n"
#define TOSTRING2(A) #A + " = " + EnumToString(A) + " (" + (string)(A) + ")\n"
#define EXPERT_MAGIC 9797

input double LossPercentage;

input int TakeProfit;
input int StopLoss;

input double DefaultVolume;
input bool UseTrailingStop;
input bool UseDefaultVolume;
input bool IsDebug = false;

CTrade trade;

CChartObjectButton _sellButton;
CChartObjectButton _buyButton;

CChartObjectButton _closeSellButton;
CChartObjectButton _closeBuyButton;
CChartObjectButton _closeAllButton;

string currentSymbol;

double points;
int digits;
double contractSize;
   
double minVolume;
double maxVolume;
double stepVolume;

ulong trailingTicket;
bool isTrailingPosition;
bool isTrailingStopStarted;
bool isTrailingSell;
double trailingStartingPrice;
int trailingStopMaxPoint;


int OnInit()
{
   CreatePanel();
   EventSetTimer(1);
   
   currentSymbol = Symbol();
   
   //Getting Fix Symbol Info
   points = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
   digits = SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
   contractSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   minVolume = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
   maxVolume = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);
   stepVolume = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeletePanel();
}

void OnTimer()
{
   //Getting USDCAD Info
   MqlTick usdCad;
   SymbolInfoTick("USDCAD", usdCad);
   
   //Getting Symbol Price
   double ask = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(currentSymbol, SYMBOL_BID);

   //Calculate Volume Of Order
   double maxLoss = (AccountInfoDouble(ACCOUNT_BALANCE) * (LossPercentage / 100));
   
   double Volume = (StopLoss == 0 || UseDefaultVolume) ? DefaultVolume : (maxLoss / (StopLoss * contractSize * points * usdCad.ask));
   Volume = Clamp(minVolume, maxVolume, Volume);
   Volume = MathFloor(Volume / stepVolume) / stepVolume;
   
   //Generating Sell Order
   if(_sellButton.State())
   {
      _sellButton.State(false);
      
      MqlTradeRequest request = {0};
      MqlTradeResult result = {0};
      
      ZeroMemory(request);
      ZeroMemory(result);
      
      //Create Sell Request
      request.action = TRADE_ACTION_DEAL;
      request.symbol = currentSymbol;
      request.volume = NormalizeDouble(Volume, 2);
      request.type = ORDER_TYPE_SELL;
      request.price = bid;
      request.deviation = 30;
      
      if(UseTrailingStop && !isTrailingPosition)
         request.comment = "Trailing Stop";
      
      if(StopLoss >= 1)
         request.sl = NormalizeDouble(bid + (points * StopLoss), digits);
      else
         request.sl = 0;
      
      if(TakeProfit >= 1 && (!UseTrailingStop || isTrailingPosition))
         request.tp = NormalizeDouble(bid - (points * TakeProfit), digits);
      else
         request.tp = 0;
         
      request.type_filling = ORDER_FILLING_IOC;
      request.magic = EXPERT_MAGIC;
      
      //Send Request And Check For Error
      if(!OrderSend(request, result))
         PrintFormat("OrderSend error %d (%s)",GetLastError(), result.comment);
      else if(UseTrailingStop && !isTrailingPosition)
      {
         isTrailingPosition = true;
         trailingTicket = result.deal;
      }
         
      if(IsDebug)
         Print(ToString(request) + ToString(result));
   }
   else if(_buyButton.State())
   {
      _buyButton.State(false);
      
      MqlTradeRequest request = {0};
      MqlTradeResult result = {0};
      
      ZeroMemory(request);
      ZeroMemory(result);
      
      //Create Buy Request
      request.action = TRADE_ACTION_DEAL;
      request.symbol = currentSymbol;
      request.volume = NormalizeDouble(Volume, 2);
      request.type = ORDER_TYPE_BUY;
      request.price = ask;
      request.deviation = 30;
      
      if(UseTrailingStop && !isTrailingPosition)
         request.comment = "Trailing Stop";
      
      if(StopLoss >= 1)
         request.sl = NormalizeDouble(ask - (points * StopLoss), digits);
      else
         request.sl = 0;
         
      if(TakeProfit >= 1 && (!UseTrailingStop || isTrailingPosition))
         request.tp = NormalizeDouble(ask + (points * TakeProfit), digits);
      else
         request.tp = 0;
        
      request.type_filling = ORDER_FILLING_IOC;
      request.magic = EXPERT_MAGIC;
      
      //Send Request And Check For Error
      if(!OrderSend(request, result))
         PrintFormat("OrderSend error %d (%s)",GetLastError(), result.comment);
      else if(UseTrailingStop && !isTrailingPosition)
      {
         isTrailingPosition = true;
         trailingTicket = result.deal;
      }
      
      if(IsDebug)
         Print(ToString(request) + ToString(result));
   }
   else if(_closeSellButton.State())
   {
      _closeSellButton.State(false);
      
      //Close All Sell Position
      int total = PositionsTotal();
      for(int pos=total-1;pos>=0;pos--)
      {
         ulong ticket = PositionGetTicket(pos);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == currentSymbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               trade.PositionClose(ticket);
            }
         }
      }
   }
   else if(_closeBuyButton.State())
   {
      _closeBuyButton.State(false);
      
      //Close All Buy Position
      int total = PositionsTotal();
      for(int pos=total-1;pos>=0;pos--)
      {
         ulong ticket = PositionGetTicket(pos);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == currentSymbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               trade.PositionClose(ticket);
            }
         }
      }
   }
   else if(_closeAllButton.State())
   {
      _closeAllButton.State(false);
      
      //Close All Position
      int total = PositionsTotal();
      for(int pos=total-1;pos>=0;pos--)
      {
         ulong ticket = PositionGetTicket(pos);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == currentSymbol)
            {
               trade.PositionClose(ticket);
            }
         }
      }
   }
   
   //The Custom Trailing Stop
   if(UseTrailingStop && isTrailingPosition)
   {
      if(isTrailingStopStarted)
      {
         int currentDeltaPoints = isTrailingSell ? ((bid - trailingStartingPrice) / points) * -1 : (ask - trailingStartingPrice) / points;
         trailingStopMaxPoint = MathMax(trailingStopMaxPoint, currentDeltaPoints);
         
         if(trailingStopMaxPoint - currentDeltaPoints >= TakeProfit)
         {
            //Close The Position
            trade.PositionClose(trailingTicket);
         }
      }
      else
      {
         //Check If The Price Have Cross The TakeProfit Line To Start Trailing Stop
         if(isTrailingSell)
         {
            if(bid <= trailingStartingPrice - (points * TakeProfit))
            {
               isTrailingStopStarted = true;   
               trailingStopMaxPoint =  ((bid - trailingStartingPrice) / points) * -1;
            }
         }
         else
         {
            if(ask >= trailingStartingPrice + (points * TakeProfit))
            {
               isTrailingStopStarted = true;
               trailingStopMaxPoint = (ask - trailingStartingPrice) / points;
            }
         }
      }
   }
}

void CreatePanel()
{
   //Generating Sell Button
   _sellButton.Create(0 , "SellButton", 0, 245, 25, 100, 36);
   _sellButton.Description("Sell");
   _sellButton.FontSize(20);
   _sellButton.Color(clrBlack);
   _sellButton.BackColor(clrRed);
   _sellButton.BorderColor(clrBlack);
   
   //Generating Buy Button
   _buyButton.Create(0 , "BuyButton", 0, 354, 25, 100, 36);
   _buyButton.Description("Buy");
   _buyButton.FontSize(20);
   _buyButton.Color(clrBlack);
   _buyButton.BackColor(clrLimeGreen);
   _buyButton.BorderColor(clrBlack);
   
   //Generate Close Sell
   _closeSellButton.Create(0, "CloseSellButton", 0, 225, 65, 80, 28);
   _closeSellButton.Description("Close Sell");
   _closeSellButton.FontSize(10);
   _closeSellButton.Color(clrBlack);
   _closeSellButton.BackColor(clrGray);
   _closeSellButton.BorderColor(clrBlack);
   
   //Generate Close Buy
   _closeBuyButton.Create(0, "CloseBuyButton", 0, 395, 65, 80, 28);
   _closeBuyButton.Description("Close Buy");
   _closeBuyButton.FontSize(10);
   _closeBuyButton.Color(clrBlack);
   _closeBuyButton.BackColor(clrGray);
   _closeBuyButton.BorderColor(clrBlack);
   
   //Generate Close All
   _closeAllButton.Create(0, "CloseAllButton", 0, 310, 65, 80, 28);
   _closeAllButton.Description("Close All");
   _closeAllButton.FontSize(10);
   _closeAllButton.Color(clrBlack);
   _closeAllButton.BackColor(clrBlueViolet);
   _closeAllButton.BorderColor(clrBlack);
}

void DeletePanel()
{
   //Deleting All Object
   _sellButton.Delete();
   _buyButton.Delete();
   
   _closeSellButton.Delete();
   _closeBuyButton.Delete();
   _closeAllButton.Delete();
}

double Clamp(double Min, double Max, double Value)
{
   return MathMin(Max, MathMax(Min, Value));
}

string ToString( const MqlTradeRequest &Request )
{
  return(TOSTRING2(Request.action) + TOSTRING(Request.magic) + TOSTRING(Request.order) +
         TOSTRING(Request.symbol) + TOSTRING(Request.volume) + TOSTRING(Request.price) + 
         TOSTRING(Request.stoplimit) + TOSTRING(Request.sl) +  TOSTRING(Request.tp) + 
         TOSTRING(Request.deviation) + TOSTRING2(Request.type) + TOSTRING2(Request.type_filling) +
         TOSTRING2(Request.type_time) + TOSTRING(Request.expiration) + TOSTRING(Request.comment) +
         TOSTRING(Request.position) + TOSTRING(Request.position_by));
}

string ToString( const MqlTradeResult &Result )
{
  return(TOSTRING(Result.retcode) + TOSTRING(Result.deal) + TOSTRING(Result.order) +
         TOSTRING(Result.volume) + TOSTRING(Result.price) + TOSTRING(Result.bid) +  
         TOSTRING(Result.ask) + TOSTRING(Result.comment) + TOSTRING(Result.request_id) +  
         TOSTRING(Result.retcode_external));
}