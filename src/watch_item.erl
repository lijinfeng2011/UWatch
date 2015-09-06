-module(watch_item).
-export([start/0]).

start() ->
  Pid = spawn( fun() -> manage() end ),
  register( item_manager, Pid ),
 
  spawn( fun() -> refresh() end ).

manage() ->
  receive
    { "add", ITEM, SOCK } ->
         dets:insert(watch_dets, {item, ITEM }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
    { "del", ITEM, SOCK } ->
         dets:delete_object(watch_dets, {item, ITEM }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
    { "list", SOCK } ->
         lists:map(
             fun(X) -> {item,I} = X, gen_tcp:send( SOCK, I ++ "\n" ) end,
             dets:lookup( watch_dets, item )
         ),
         gen_tcp:close( SOCK );
    _ -> true

  end,
  manage().

refresh() ->
  lists:map( 
      fun(X) -> {item,I} = X,
         ITEM = list_to_atom( "item_list#"++ I ), 
         case whereis( ITEM ) =:= undefined of
           true -> 
             { _,M,_} = time(),
             Pid = spawn(fun() -> stored(ITEM,queue:new(),M) end),
             register( ITEM, Pid );
           false -> false
         end
      end,
      dets:lookup( watch_dets, item )
  ),
  timer:sleep( 60000 ),
  refresh().

stored( NAME, WatchQ, TIME ) ->
  receive
    { "data", Data } ->
        NewWatchQ = WatchQ,
        queue:filter( fun(X) -> X ! { Data }, true end ,NewWatchQ),
        {_,M,_} = time(),
        case M == TIME of
          false ->
            List = dets:lookup( watch_dets, item );
          true -> true
        end
  end,
  stored( NAME, NewWatchQ, TIME ).
