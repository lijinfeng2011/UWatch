-module(watch_item).
-compile(export_all).
%-export([start/0,disk_log/2,add/1,del/1,list/0,setindex/2,getindex/1]).

-define(ITEM_PATH,"../data/item/").
-define(STAT_TIME,[1,5,15]).
-define(ITEM_DATA_SIZE,65536).
-define(ITEM_DATA_COUNT,3).
-define(ITEM_MAX_QCOUNT,100).

start() -> 
  spawn( fun() -> mon() end ),
  spawn( fun() -> cut() end ),
  spawn( fun() -> filter() end ).

disk_log( ITEM, TYPE ) ->
  {_,L} = watch_disk_log:read_log( ?ITEM_PATH ++ ITEM ++ "/" ++ TYPE ),
  case TYPE of
      "count" -> 
          C = length(L),
          case C < 1440  of
              true ->  L;
              false -> lists:nthtail(C-1440, L)
          end;
      _ -> L
  end.

add( ITEM ) -> 
   watch_db:set_item( ITEM, watch_db:get_item( ITEM )).
del( ITEM ) -> watch_db:del_item( ITEM ).

list() -> watch_db:list_item().
  
setindex( ITEM, VALUE ) -> watch_db:set_item(ITEM, VALUE).
getindex( ITEM ) -> watch_db:get_item(ITEM).

mon() ->
  lists:map( 
      fun(X) ->
         ITEM = list_to_atom( "item_list#"++ X ), 
         case whereis( ITEM ) =:= undefined of
           true -> 
             file:make_dir( ?ITEM_PATH ++ X ),
             case watch_disk_log:open( ?ITEM_PATH ++ X ++ "/mesg", ?ITEM_DATA_SIZE, ?ITEM_DATA_COUNT) of
               {ok, MLog} ->
                  case watch_disk_log:open( ?ITEM_PATH ++ X ++ "/count", ?ITEM_DATA_SIZE, ?ITEM_DATA_COUNT) of
                    {ok, CLog} ->
                      Index = watch_db:get_item(X),
                      Pid = spawn(fun() -> stored(X,MLog, CLog,queue:new(),Index,queue:new(),[]) end),
                      register( ITEM, Pid );
                     _ -> watch_log:error( "start item:~p fail~n", [X] ), watch_disk_log:close(MLog)
                  end;
               _ -> watch_log:error( "start item:~p fail~n", [X] )
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
  Msec = watch_misc:milliseconds(),
  TIME = lists:concat( [ Y,"-",M,"-",D,"-",H,"-",Mi ] ),
  lists:map( 
      fun(X) ->
         ITEM = list_to_atom( "item_list#"++ X ), 
         case whereis( ITEM ) =:= undefined of
           true -> true;
           false -> ITEM ! { cut,TIME, Msec }
         end
      end,
      watch_db:list_item()
  ),
  cut().

filter() ->
  FILTER = watch_filter:table(),
  ITEMLIST = sets:to_list(sets:from_list(lists:map(
    fun(X) -> {Name,_,_,_} = X,Name end
  ,FILTER))),

  lists:map(
    fun(X) -> ItemName = X, 
      Cont = lists:filter( fun(XX) -> {N,_,_,_} = XX, N =:= ItemName end, FILTER ),     
      FilterCont = sets:to_list(sets:from_list( lists:map( fun(XX) -> {_,C,_,_} = XX, C  end, Cont))),
      ITEM = list_to_atom( "item_list#"++ ItemName ),
      try
        ITEM ! { filter, FilterCont }
      catch
        error:badarg -> watch_log:error("send filter to item ~p fail~n", [ItemName] )
      end

    end
  ,ITEMLIST),
  timer:sleep(5000),
  filter().

stored(NAME,MLog,CLog,Q,Index,Stat,Filter) ->
  receive
    { filter, List } -> NewQ = Q, NewIndex = Index,NewStat = Stat, NewFilter = List;
    { "data", Data } ->
        MATCH = lists:filter(fun(X) -> re:run(Data, X) /= nomatch end, Filter),
        case length(MATCH) > 0 of
            true -> watch_log:info("~p filter:~p~n",[NAME,Data]), NewIndex = Index, NewQ = Q;
            false ->
                NewQ = queue:in(Data,Q),
                NewIndex = Index +1,
                setindex(NAME,NewIndex),
                watch_disk_log:write(MLog,"*"++integer_to_list(NewIndex)++"*"++Data)
        end,
        
        NewStat = Stat,
        NewFilter = Filter;
    { cut, TIME, Msec } -> 
        NewQ = queue:new(),
        disk_log:log( CLog, TIME ++ ":" ++ integer_to_list(queue:len(Q)) ),
        NewIndex = Index,NewFilter = Filter,
        TmpStat = queue:in(queue:len(Q),Stat),
        case queue:len(TmpStat) > ?ITEM_MAX_QCOUNT of
            true -> {_,NewStat} = queue:out(TmpStat);
            false -> NewStat = TmpStat
        end,
        watch_db:set_stat(NAME,queue_to_stat(NewStat)),
        %% case item_alarm(NAME,NewQ) of
        %% case item_alarm(NAME,NewStat) of
        case queue:len(Q) > 0 of
            true ->  watch_db:set_last("item#"++NAME,Msec);
            false -> false
        end;
      true -> NewQ = Q, NewIndex = Index,NewStat = Stat, NewFilter = Filter
  end,
  stored(NAME,MLog,CLog,NewQ,NewIndex,NewStat,NewFilter).

queue_to_stat(Q) ->
   string:join(lists:map(fun(X) ->queue_avg(Q,X) end, ?STAT_TIME),"/").

queue_avg(Q,Count) ->
  case queue_sum(Q,Count) of
    error -> "_";
%    V -> integer_to_list( round( V/Count ) )
    V ->  CC = round(V/Count*100), 
          integer_to_list( trunc(CC/100) ) ++ "." ++ integer_to_list( CC rem 100 )
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

get_item_alarm_conf(Item) -> {1,1}.

item_alarm(Item,Q) ->
  {A,B} = get_item_alarm_conf(Item),
  case queue_count(Q,B) of
    error -> V = 0;
    VV -> V = VV
  end,
  A >= V.


queue_count(Q,Count) -> queue_count(Q,Count,0).
queue_count(Q,Count,E) ->
  case queue:out(Q) of
    {{value,V},Q2} ->
        case V > 0 of
           true -> VV = 1;
           false -> VV = 0
        end,
        case Count == 1 of
            true -> VV+E;
            false -> queue_count(Q2,Count-1,E+VV)
        end;
    _ -> error
  end.


