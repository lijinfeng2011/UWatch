-module(watch_item).
-compile(export_all).
%-export([start/0,disk_log/2,add/1,del/1,list/0,setindex/2,getindex/1]).

-define(ITEM_PATH,"../data/item/").
-define(STAT_TIME,[1,5,15]).
-define(ITEM_DATA_SIZE,65536).
-define(ITEM_DATA_COUNT,65536).

start() -> 
  spawn( fun() -> mon() end ),
  spawn( fun() -> cut() end ).

disk_log( ITEM, TYPE ) ->
  {_,L} = watch_disk_log:read_log( ?ITEM_PATH ++ ITEM ++ "/" ++ TYPE ), L.

add( ITEM ) -> 
   watch_db:set_item( ITEM, watch_db:get_item( ITEM )).
del( ITEM ) -> watch_db:del_item( ITEM ).

list() -> watch_db:list_item().
  
setindex( ITEM, VALUE ) -> watch_db:set_item(ITEM, VALUE).
getindex( ITEM ) -> watch_db:get_item(ITEM).

mon() ->
  lists:map( 
      fun(X) ->
         io:format("start item:~p~n",[X]),
         ITEM = list_to_atom( "item_list#"++ X ), 
         case whereis( ITEM ) =:= undefined of
           true -> 
             file:make_dir( ?ITEM_PATH ++ X ),
             case watch_disk_log:open( ?ITEM_PATH ++ X ++ "/mesg", ?ITEM_DATA_SIZE, ?ITEM_DATA_COUNT) of
               {ok, MLog} ->
                  case watch_disk_log:open( ?ITEM_PATH ++ X ++ "/count", ?ITEM_DATA_SIZE, ?ITEM_DATA_COUNT) of
                    {ok, CLog} ->
                      Index = watch_db:get_item(X) + 1,
                      Pid = spawn(fun() -> stored(X,MLog, CLog,queue:new(),Index,queue:new()) end),
                      register( ITEM, Pid );
                     _ -> io:format( "err~n" ), watch_disk_log:close(MLog)
                  end;
               _ -> io:format( "err~n" )
             end;
           false -> false
         end
      end,
      watch_db:list_item()
  ),
  timer:sleep( 5000 ),
  mon().


cut() ->
  timer:sleep( 60000 ),
  {{Y,M,D},{H,Mi,_}} = calendar:local_time(),
  TIME = lists:concat( [ Y,"-",M,"-",D,"-",H,"-",Mi ] ),
  lists:map( 
      fun(X) ->
         ITEM = list_to_atom( "item_list#"++ X ), 
         case whereis( ITEM ) =:= undefined of
           true -> true;
           false -> ITEM ! { cut,TIME }
         end
      end,
      watch_db:list_item()
  ),
  cut().

stored(NAME,MLog,CLog,Q,Index,Stat) ->
  receive
    { "data", Data } ->
        NewQ = queue:in(Data,Q),
        watch_disk_log:write(MLog,"*"++integer_to_list(Index)++"*"++Data),
        NewIndex = Index +1,
        NewStat = Stat;
    { cut,TIME } -> 
        NewQ = queue:new(),
        disk_log:log( CLog, TIME ++ ":" ++ integer_to_list(queue:len(Q)) ),
        NewIndex = Index,
        setindex(NAME,Index),
        TmpStat = queue:in(queue:len(Q),Stat),
        case queue:len(TmpStat) > 15 of
            true -> {_,NewStat} = queue:out(TmpStat);
            false -> NewStat = TmpStat
        end,
        watch_db:set_stat(NAME,queue_to_stat(NewStat));
      true -> NewQ = Q, NewIndex = Index,NewStat = Stat
  end,
  stored(NAME,MLog,CLog,NewQ,NewIndex,NewStat).

queue_to_stat(Q) ->
   string:join(lists:map(fun(X) ->queue_avg(Q,X) end, ?STAT_TIME),"/").

queue_avg(Q,Count) ->
  case queue_sum(Q,Count) of
    error -> "_";
    V -> integer_to_list( round( V/Count ) )
  end.

queue_sum(Q,Count) -> queue_sum(Q,Count,0).
queue_sum(Q,Count,E) ->
  case queue:out(Q) of
    {{value,V},Q2} ->
        case Count == 1 of
            true -> V+E;
            false -> queue_sum(Q2,Count-1,E+V)
        end;
    _ -> error
  end.
