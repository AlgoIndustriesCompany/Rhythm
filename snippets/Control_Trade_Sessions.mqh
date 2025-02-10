//+------------------------------------------------------------------+
//|                                       Control_Trade_Sessions.mqh |
//+------------------------------------------------------------------+
//sample
//static TRADE_SESSIONS TradeSession(_Symbol);//получение времени откр/закр рынка и сохраниение в массивы по дням недели
//if(!TradeSession.isSessionTrade(TimeCurrent())){Print("Market closed. OnTick return");return;}//

//контроль торгововой сессии
//#define LoadSessionFromInputs // Чтение сессий из input-ов
#ifdef LoadSessionFromInputs
   sinput group "TradeSessions by days"
   sinput string TradeSessionsMonday="";//TradeSessionsMonday sample: 00:15-17:45,17:55-23:55
   sinput string TradeSessionsTuesday ="";//TradeSessionsTuesday sample: 00:00-24:00 - full day trade
   sinput string TradeSessionsWednesday ="";//TradeSessionsWednesday sample: 00:15-23:55
   sinput string TradeSessionsThursday ="";//TradeSessionsThursday sample: 00:15-23:55
   sinput string TradeSessionsFriday="";//TradeSessionsFriday sample: 00:10-17:45,17:55-23:00,23:05-23:55
   sinput string TradeSessionsSaturday ="";//TradeSessionsSaturday sample: empty - trade not allowed
   sinput string TradeSessionsSunday ="";//TradeSessionsSunday sample: 00:00-00:00 - trade not allowed
#endif

struct TRADE_SESSIONS{
public:
   datetime NextTradeStop;//время конца текущей сессии, до него можно не проверять массивы
   datetime NextTradeStart;//время начала следующей сессии, до него можно не проверять массивы
   datetime TradeTimeFrom[10][7], TradeTimeTo[10][7];//время торговой сессии по 7 дням до 10 сессий 7*10=70
   int TradeSessions[7]; //число сессий в дне недели
   
   void TRADE_SESSIONS ( string symb){//считать торг сессии 1 раз при создании объекта
      #ifdef LoadSessionFromInputs
         string s[7]; s[0]=TradeSessionsSunday;s[1]=TradeSessionsMonday;s[2]=TradeSessionsTuesday;s[3]=TradeSessionsWednesday;s[4]=TradeSessionsThursday;s[5]=TradeSessionsFriday;s[6]=TradeSessionsSaturday;
         LoadFromInputs(s); return;
      #endif 
      for(ENUM_DAY_OF_WEEK d=0; d<7; d++){// получение времени откр/закр рынка и сохраниение в массивы по дням недели https://www.mql5.com/ru/forum/1111/page1803#comment_4092783
        this.TradeSessions[d] = 0; string out="";
        for (int i = 0; i<10; i++){
           if(::SymbolInfoSessionTrade(symb, d, i, this.TradeTimeFrom[i][d], this.TradeTimeTo[i][d])){ this.TradeSessions[d] = i+1; out+=(string)(i+1)+": "+StringSubstr((string)this.TradeTimeFrom[i][d],11,5)+"-"+StringSubstr((string)this.TradeTimeTo[i][d],11,5)+", "; };//считать сессию и уст. число сессий по инструменту //
        }
        //if(out!=""){Print("Day: ",d," Trade sessions: ",StringSubstr(out,0, StringLen(out)-2)); }
      }
      this.NextTradeStop = this.NextTradeStart = 0;//время конца текущей торг. сессии
   }
   
   void LoadFromInputs(string &s[]){//s=["00:15-17:45,17:55-23:55","00:00-24:00",...] 
      for(ENUM_DAY_OF_WEEK d=0; d<7; d++){// получение времени откр/закр рынка и сохраниение в массивы по дням недели https://www.mql5.com/ru/forum/1111/page1803#comment_4092783
        this.TradeSessions[d] = 0;
        string result[], result2[];// массив для получения строк
        int sessions=StringSplit(s[(int)d],StringGetCharacter(",",0),result);//--- разобьем строку на подстроки
        string out="";
        for (int i = 0; i<sessions; i++){
           int start_end=StringSplit(result[i],StringGetCharacter("-",0),result2);//--- разобьем строку на подстроки
           if(start_end==2){
              this.TradeTimeFrom[i][d] = StringToTime("1970.01.01 "+result2[0]);
              this.TradeTimeTo  [i][d] = StringToTime("1970.01.01 "+result2[1]);
              this.TradeSessions[d] = i+1;
              out+=(string)(i+1)+": "+StringSubstr((string)this.TradeTimeFrom[i][d],11,5)+"-"+StringSubstr((string)this.TradeTimeTo[i][d],11,5)+", ";
           };//считать сессию и уст. число сессий по инструменту //
        }
        if(out!=""){Print("Day: ",d," Trade sessions: ",StringSubstr(out,0, StringLen(out)-2)); }
      }
      this.NextTradeStop = this.NextTradeStart = 0;//время конца текущей торг. сессии
   }
   
   
   bool isSessionTrade( datetime time ){//расчет откытого для торговли рынка, по заранее определенным временам открытия и закрытия торговли   https://www.mql5.com/ru/forum/1111/page1803#comment_4092783
      if(time < this.NextTradeStop  ) { return true; }
      if(time < this.NextTradeStart ) { return false; }
      int DayOfWeek = TimeDayOfWeek(time); //current DayOfWeek.
      datetime Sec = TimeSec(time); //current second in day
      
      this.NextTradeStart=(datetime)((TimeDay(time) + 1) * 86400);//по умолчанию старт на начало следущего дня, ниже переопределим
      for (int i = 0; i < this.TradeSessions[DayOfWeek]; i++){//перебор сессий в этом дне недели
         if( Sec <  this.TradeTimeFrom[i][DayOfWeek]) {
            this.NextTradeStart=(datetime)(TimeDay(time) * 86400) + this.TradeTimeFrom[i][DayOfWeek]; //время начала следущей сессии (начало этого дня + время сессии) 
            //Print("new Start ",this.NextTradeStart); 
            break;
         } 
      }
      
      for (int i = 0; i < this.TradeSessions[DayOfWeek]; i++){//перебор сессий в этом дне недели
         if(( Sec >= this.TradeTimeFrom[i][DayOfWeek] ) && ( Sec < this.TradeTimeTo[i][DayOfWeek] )){ 
            this.NextTradeStop = (datetime)(TimeDay(time) * 86400) + this.TradeTimeTo[i][DayOfWeek]; //время конца текущей сессии, до него можно не проверять следущую = (начало этого дня + время сессии) 
            //Print("new Stop ",this.NextTradeStop);
            return true; 
         }
      }
      return false;
   }
   int TimeDay      ( datetime time ){return((int)( time / 86400));}//current Day from on 1 Jan 1971
   int TimeDayOfWeek( datetime time ){return((int)((time / 86400 + THURSDAY) % 7));}//current DayOfWeek. 86400 sec in day.  7 days in week.  THURSDAY on 1 Jan 1971
   int TimeHour     ( datetime time ){return((int)((time / 3600) % 24));}//current hour in day. 3600 sec in hour
   int TimeSec      ( datetime time ){return((int)( time % 86400));}//current second in day. 86400 sec in day
};
