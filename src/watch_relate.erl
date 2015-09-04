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
       Fun = fun(X) ->  X /= {NAME,USER} end,
       NewQList = queue:filter(Fun,QList),
       relate_manager_refresh ! { NewQList };
    { "list", SOCK } ->
       Fun = fun(X) ->
           { A,B} = X,
           gen_tcp:send( SOCK, A ++ "#" ++ B ++ "#" ++ "\n" ),
           true
       end,
       queue:filter(Fun,QList),
       NewQList = QList;
 
    Other ->
       NewQList = QList,
       io:fwrite( "unkown the command~n" )
  end,
  io:fwrite( "relate len:~p~n", [ queue:len( NewQList ) ] ),
  manage( NewQList ).

manage_refresh( ) ->
  receive
    { Q } ->
        TOITEM = fun(X) -> 
            { NAME,USER } = X,
            item_manager ! {"add", NAME},
            user_manager ! {"add", USER},
        true end,
        queue:filter(TOITEM,Q),

                                           
       item_manager ! {"watch", Q };
 
    Other ->
       io:fwrite( "unkown the command~n" )
  end,
  manage_refresh().
