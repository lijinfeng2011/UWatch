-module(watch_item).
-export([start/0,disk_log/2,add/1,del/1,list/0,setindex/2,getindex/1]).

-define(ITEM_PATH,"../data/item/").

start() -> spawn( fun() -> refresh() end ).

disk_log( ITEM, TYPE ) ->
  {_,L} = watch_disk_log:read_log( ?ITEM_PATH ++ ITEM ++ "/" ++ TYPE ), L.

add( ITEM ) ->
  dets:insert(watch_dets, {item, ITEM }).
del( ITEM ) ->
  dets:delete_object(watch_dets, {item, ITEM }).
list() ->
  lists:map( fun(X) -> {_,A} = X, A end,dets:lookup( watch_dets, item )).
  
setindex( ITEM, VALUE ) ->
  case dets:open_file( item_index_dets,[{file, "../data/item_index.dets" },{type,set},{auto_save,10}]) of
    {ok,_} -> dets:insert(item_index_dets, {ITEM, VALUE });
    _ -> ok
  end.

%% get the item index from user
getindex( ITEM ) ->
  case dets:open_file( item_index_dets,[{file, "../data/item_index.dets" },{type,set},{auto_save,10}]) of
    {ok, _} ->
      case catch dets:lookup( item_index_dets,ITEM ) of
        { 'EXIT',_ } ->0;
        [{ITEM,V}] -> V;
        _ -> 0
      end;
    _ -> 0
  end.

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
                      IL = dets:lookup( item_index_dets, I ),
                      case lists:flatlength( IL ) == 1 of
                        true -> [{_,INDEX}] = IL, Index = INDEX+1;
                        false -> Index = 1
                      end,
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
  timer:sleep( 3000 ),
  refresh().

stored(NAME,MLog,CLog,Q,Index) ->
  receive
    { "data", Data } ->
        io:format( "~p ~p ~n", [NAME,Index]),
        NewQ = queue:in( Data, Q ),
        watch_disk_log:write( MLog, "*" ++ integer_to_list( Index ) ++ "*"++ Data ),
        NewIndex = Index + 1;
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
