-module(watch_relate).
-export([start/0]).

start() ->
  PidRelate = spawn( fun() -> manage( queue:new()) end ),
  register( relate_manager, PidRelate ),

  PidRelateRefresh = spawn( fun() -> manage_refresh() end ),
  register( relate_manager_refresh, PidRelateRefresh ).


manage( QList ) ->
  receive
    { "add", NAME, USER } ->
       Fun = fun(X) -> X /= {NAME,USER} end,
       TMPList = queue:filter(Fun,QList),
       NewQList = queue:in( {NAME,USER}, TMPList ),
       relate_manager_refresh ! { NewQList };
    { "del", NAME, USER } ->
       Fun = fun(X) ->  { A,B,C} = X,{A,B} /= {NAME,USER} end,
       NewQList = queue:filter(Fun,QList),
       relate_manager_refresh ! { NewQList };
    { "list", SOCK } ->
       Fun = fun(X) ->
           { A,B,C} = X,
           gen_tcp:send( SOCK, A ++ "#" ++ B ++ "#" ++ C ++"\n"),
           A == A
       end,
       queue:filter(Fun,QList),
       NewQList = QList;
 
    Other ->
       NewQList = QList,
       io:fwrite( "unkown the command~n" )
  end,
  io:fwrite( "datalist len:~p~n", [ queue:len( NewQList ) ] ),
  manage( NewQList ).

manage_refresh( ) ->
  receive
    { Q } ->
 
       io:fwrite( "unkown the cQQQQQQQQQQommand~n" );
    Other ->
       io:fwrite( "unkown the command~n" )
  end,
  manage_refresh().



