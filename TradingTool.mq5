#include <ChartObjects\ChartObjectsTxtControls.mqh>

#define TOSTRING(A)  #A + " = " + (string)(A) + "\n"
#define TOSTRING2(A) #A + " = " + EnumToString(A) + " (" + (string)(A) + ")\n"
#define EXPERT_MAGIC 9797

input double LossPercentage;

input int TakeProfit;
input int StopLoss;

input bool IsDebug = false;

CChartObjectButton _sellButton;
CChartObjectButton _buyButton;

string currentSymbol;

double points;
int digits;
double contractSize;
   
double minVolume;
double maxVolume;
double stepVolume;

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
   
   double Volume = maxLoss / (StopLoss * contractSize * points * usdCad.ask);
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
      
      if(StopLoss >= 1)
         request.sl = NormalizeDouble(bid + (points * StopLoss), digits);
      else
         request.sl = 0;
         
      if(TakeProfit >= 1)
         request.tp = NormalizeDouble(bid - (points * TakeProfit), digits);
      else
         request.tp = 0;
         
      request.type_filling = ORDER_FILLING_IOC;
      request.magic = EXPERT_MAGIC;
      
      //Send Reqeust And Check For Error
      if(!OrderSend(request, result))
         PrintFormat("OrderSend error %d (%s)",GetLastError(), result.comment);
         
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
      
      if(StopLoss >= 1)
         request.sl = NormalizeDouble(ask - (points * StopLoss), digits);
      else
         request.sl = 0;
         
      if(TakeProfit >= 1)
         request.tp = NormalizeDouble(ask + (points * TakeProfit), digits);
      else
         request.tp = 0;
        
      request.type_filling = ORDER_FILLING_IOC;
      request.magic = EXPERT_MAGIC;
      
      //Send Reqeust And Check For Error
      if(!OrderSend(request, result))
         PrintFormat("OrderSend error %d (%s)",GetLastError(), result.comment);
      
      if(IsDebug)
         Print(ToString(request) + ToString(result));
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
}

void DeletePanel()
{
   //Deleting All Object
   _sellButton.Delete();
   _buyButton.Delete();
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