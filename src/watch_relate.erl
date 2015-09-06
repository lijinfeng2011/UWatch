-module(watch_relate).
-export([start/0]).

start() ->
  Pid = spawn( fun() -> manage() end ),
  register( relate_manager, Pid ).

manage() ->
  receive
    { "add", ITEM, USER, SOCK } ->
         dets:insert(watch_dets, {relate, ITEM, USER }),
         dets:insert(watch_dets, {item, ITEM }),
         dets:insert(watch_dets, {user, USER }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK ),
         item_manager ! {"refreshrelate", ITEM };
    { "del", ITEM, USER, SOCK } ->
         dets:delete_object(watch_dets, {relate, ITEM, USER }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK ),
         item_manager ! {"refreshrelate", ITEM };
    { "list", SOCK } ->
         lists:map( 
             fun(X) -> {relate,I,U} = X, gen_tcp:send( SOCK, I ++ ":" ++ U ++ "\n" ) end, 
             dets:lookup( watch_dets, relate )
         ),
         gen_tcp:close( SOCK );
    _ -> true
  end,
  manage().
