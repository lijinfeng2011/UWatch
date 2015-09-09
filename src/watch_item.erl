-module(watch_item).
-export([start/0,mesg/1,add/1,del/1,list/0]).

-define(ITEM_MESG_PATH, "../data/item/mesg/").
-define(ITEM_COUNT_PATH, "../data/item/count/").

start() ->
  spawn( fun() -> refresh() end ).


mesg( ITEM ) ->
  Index = getmaxindex( ?ITEM_MESG_PATH ++ ITEM ),
  Log = list_to_atom( "item_"++ ITEM ++ "_" ++ Index ),
  open_r( Log, ?ITEM_MESG_PATH ++ ITEM ++"/" ++ Index ),
  case disk_log:chunk(Log, start) of
    { _, L } -> L
  end.

count( ITEM ) ->
  Index = getmaxindex( ?ITEM_COUNT_PATH ++ ITEM ),
  Log = list_to_atom( "item_"++ ITEM ++ "_" ++ Index ),
  open_r( Log, ?ITEM_COUNT_PATH ++ ITEM ++"/" ++ Index ),
  case disk_log:chunk(Log, start) of
    { _, L } -> L
  end.

add( ITEM ) ->
  dets:insert(watch_dets, {item, ITEM }).
del( ITEM ) ->
  dets:delete_object(watch_dets, {item, ITEM }).
list() ->
  lists:map( fun(X) -> {_,A} = X, A end,dets:lookup( watch_dets, item )).
  
refresh() ->
  lists:map( 
      fun(X) -> {item,I} = X,
         ITEM = list_to_atom( "item_list#"++ I ), 
         case whereis( ITEM ) =:= undefined of
           true -> 
             file:make_dir( ?ITEM_MESG_PATH ++ I ),
             file:make_dir( ?ITEM_COUNT_PATH ++ I ),

             MIndex = getmaxindex( ?ITEM_MESG_PATH ++I ),
             MLog = list_to_atom( "item_m_"++ I ++ "_" ++ MIndex ),
             open_w( MLog, ?ITEM_MESG_PATH ++ I ++"/" ++ MIndex ),

             CIndex = getmaxindex( ?ITEM_COUNT_PATH ++I ),
             CLog = list_to_atom( "item_c_"++ I ++ "_" ++ CIndex ),
             open_w( MLog, ?ITEM_COUNT_PATH ++ I ++"/" ++ CIndex ),

             Pid = spawn(fun() -> stored(I,sets:new(),queue:new(),61,MLog,MIndex, queue:new(),CLog) end),
             register( ITEM, Pid ),
             io:format( "xxx~p~n", [ITEM] );
           false -> ITEM ! { cut }
         end
      end,
      dets:lookup( watch_dets, item )
  ),
  timer:sleep( 60000 ),
  refresh().

stored( NAME, WatchS, HistoryQ, TIME,Log,INDEX, Q, COUNTLog ) ->
  receive
    { "data", Data } ->
        NewQ = queue:in( Data, Q ),
        case disk_log:log(Log, Data) of
            {ok, _} ->   NewINDEX = INDEX, NewLog = Log;
            {error,{full,_}} -> 
                 NewINDEX = integer_to_list(list_to_integer( INDEX ) + 1 ),
                 NewLog = list_to_atom( "item_"++ NAME ++ "_" ++  NewINDEX),
                 disk_log:close(Log), 
                 open_w( Log, ?ITEM_MESG_PATH ++ NAME ++"/" ++ NewINDEX ),
                 disk_log:log(Log, Data);
            _ -> 
                 disk_log:close(Log),
                 open_w( Log, ?ITEM_MESG_PATH ++ NAME ++"/" ++ INDEX ),
                 NewINDEX = INDEX, NewLog = Log

        end,
        NewWatchS = WatchS, NewTIME = TIME, NewCOUNTLog = COUNTLog;
      { cut } -> NewTIME = TIME,
              NewHistoryQ = HistoryQ,  NewINDEX = INDEX, NewLog = Log, NewCOUNTLog = COUNTLog,
              Mesg = string:join(queue:to_list( Q ), "#-cut-#" ),
              sets:filter(
              fun(X) -> 
                  try X ! { Mesg }, io:format( "item ~p send msg to user ~p~n", [ NAME, X ])
                  
                  catch
                    error:badarg -> io:fwrite( "~p send mesg to user ~p fail. ~n", [ NAME, X ] )
                  end,
              true end,
              WatchS),
              NewQ = queue:new(),

              List = dets:lookup( watch_dets, relate ),
              MyL  = lists:filter(fun(X) -> {_,N,_} = X,N == NAME end, List),
              MyL2 =lists:map(fun(X) -> {_,_,U} = X, list_to_atom( "user_list#"++ U ) end, MyL ),
              NewWatchS = sets:from_list(MyL2),


              disk_log:log(COUNTLog, queue:len( Q ));
      true -> NewWatchS = WatchS, NewTIME = TIME,
              NewHistoryQ = HistoryQ,  NewINDEX = INDEX, NewLog = Log,
              NewQ = Q, NewCOUNTLog = COUNTLog
  end,
  stored( NAME, NewWatchS, HistoryQ, NewTIME,NewLog,NewINDEX, NewQ, NewCOUNTLog ).

open_w( H, PATH ) ->
  disk_log:open( [{name, H},{mode, read_write},{size, 32768},{file, PATH }]).

open_r( H, PATH ) ->
  disk_log:open( [{name, H},{mode, read_only},{file, PATH }]).

getmaxindex( PATH ) ->
  case file:list_dir( PATH ) of
    {ok,List} ->
      case length(List) > 1 of
        true -> lists:max( lists:map( fun(X) -> try list_to_integer(X) catch error:badarg -> 0 end end, List ) );
        false -> "0"
      end;
     _ -> "0"
  end.
