-module(watch_item).
-export([start/0,disk_log/2,add/1,del/1,list/0,setindex/2,getindex/1]).

-define(ITEM_PATH,"../data/item/").

start() -> spawn( fun() -> refresh() end ).

disk_log( ITEM, TYPE ) ->
  {_,L} = watch_disk_log:read_log( ?ITEM_PATH ++ ITEM ++ "/" ++ TYPE ), L.

add( ITEM ) -> 
   watch_db:set_item( ITEM, watch_db:get_item( ITEM )).
del( ITEM ) -> watch_db:del_item( ITEM ).

list() -> watch_db:list_item().
  
setindex( ITEM, VALUE ) -> watch_db:set_item(ITEM, VALUE).
getindex( ITEM ) -> watch_db:get_item(ITEM).

refresh() ->
  {{Y,M,D},{H,Mi,_}} = calendar:local_time(),
  TIME = lists:concat( [ Y,"-",M,"-",D,"-",H,"-",Mi ] ),
  lists:map( 
      fun(X) -> {item,I} = X,
         ITEM = list_to_atom( "item_list#"++ I ), 
         case whereis( ITEM ) =:= undefined of
           true -> 
             file:make_dir( ?ITEM_PATH ++ I ),
             case watch_disk_log:open( ?ITEM_PATH ++ I ++ "/mesg", 65536, 3) of
               {ok, MLog} ->
                  case watch_disk_log:open( ?ITEM_PATH ++ I ++ "/count", 65536, 3) of
                    {ok, CLog} ->
                      Index = watch_db:get_item(I) + 1,
                      Pid = spawn(fun() -> stored(I,MLog, CLog,queue:new(),Index) end),
                      register( ITEM, Pid );
                     _ -> io:format( "err~n" ), watch_disk_log:close(MLog)
                  end;
               _ -> io:format( "err~n" )
             end;
           false -> ITEM ! { cut,TIME }
         end
      end,
      dets:lookup( watch_dets, item )
  ),
  timer:sleep( 60000 ),
  refresh().

stored(NAME,MLog,CLog,Q,Index) ->
  receive
    { "data", Data } ->
        NewQ = queue:in(Data,Q),
        watch_disk_log:write(MLog,"*"++integer_to_list(Index)++"*"++Data),
        NewIndex = Index +1;
    { cut,TIME } -> 
        Mesg = string:join(queue:to_list( Q ), "#-cut-#" ),
        List =lists:map(
          fun(X) -> {_,_,U} = X, list_to_atom( "user_list#"++ U ) end,
          lists:filter(
            fun(X) -> {_,N,_} = X,N == NAME end,dets:lookup( watch_dets, relate )
          )
        ),
        sets:filter(
          fun(X) -> 
              try X ! { Mesg }, io:format( "item ~p send msg to user ~p~n", [ NAME, X ])
              catch
                error:badarg -> io:fwrite( "~p send mesg to user ~p fail. ~n", [ NAME, X ] )
              end,
          true end,
        sets:from_list(List)),
        NewQ = queue:new(),
        disk_log:log( CLog, TIME ++ ":" ++ integer_to_list(queue:len(Q)) ),
        NewIndex = Index,
        setindex(NAME,Index);
      true -> NewQ = Q, NewIndex = Index
  end,
  stored(NAME,MLog,CLog,NewQ,NewIndex).
