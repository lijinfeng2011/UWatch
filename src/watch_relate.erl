-module(watch_relate).
%-export([start/0,add/2,del/2,list/0]).
-export([add/2,del/2,list/0,list4user/1]).

%start() ->
%  Pid = spawn( fun() -> manage() end ),
%  register( relate_manager, Pid ).


add( ITEM, USER ) ->
  dets:insert(watch_dets, {relate, ITEM, USER }),
  dets:insert(watch_dets, {item, ITEM }).

del( ITEM, USER ) ->
  dets:delete_object(watch_dets, {relate, ITEM, USER }).

list() ->
  lists:map( fun(X) -> {_,I,U} = X, { I, U } end,dets:lookup( watch_dets, relate )).

%list4user(USER) ->
%  lists:map( fun(X) -> {_,I,_} = X, I end, lists:filter( fun(X) -> {_,_,U} = X, U == USER end,dets:lookup( watch_dets, relate ) )).

list4user(USER) ->
  lists:map(
    fun(X) -> {_,I,_} = X,
        PubIndex = watch_item:getindex(I),
        PriIndex = watch_user:getindex(USER,I),
%        PubIndex =1,
%        PriIndex =3,
        I ++ ":" ++ integer_to_list( PubIndex - PriIndex )
    end, 
    lists:filter( 
      fun(X) -> {_,_,U} = X, U == USER end,dets:lookup( watch_dets, relate )
    )
  ).
  
%manage() ->
%  receive
%    { "add", ITEM, USER, SOCK } ->
%         dets:insert(watch_dets, {relate, ITEM, USER }),
%         dets:insert(watch_dets, {item, ITEM }),
%         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK ),
%         item_manager ! {"refreshrelate", ITEM };
%    { "del", ITEM, USER, SOCK } ->
%         dets:delete_object(watch_dets, {relate, ITEM, USER }),
%         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK ),
%         item_manager ! {"refreshrelate", ITEM };
%    { "list", SOCK } ->
%         lists:map( 
%             fun(X) -> {relate,I,U} = X, gen_tcp:send( SOCK, I ++ ":" ++ U ++ "\n" ) end, 
%             dets:lookup( watch_dets, relate )
%         ),
%         gen_tcp:close( SOCK );
%    _ -> true
%  end,
%  manage().
