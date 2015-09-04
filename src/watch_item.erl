-module(watch_item).
-export([start/0]).

start() ->
  Pid = spawn( fun() -> manage( queue:new() ) end ),
  register( item_manager, Pid ).

manage( QList ) ->
  receive
    { "add", NAME } ->
       case queue:member( NAME, QList ) of
           true  -> NewQList = QList;
           false -> NewQList = queue:in( NAME, QList ), 
                    Pid = spawn(fun() -> stored(NAME,queue:new()) end),
                    QNAME = list_to_atom( "item_list#"++ NAME ),
                    register( QNAME, Pid )
       end;
     { "watch", WatchQ } ->
        WATCH = fun(X) ->
            QNAME = list_to_atom( "item_list#"++ X ),
            QNAME ! { "watch", WatchQ },
        true end,
        queue:filter(WATCH,QList),
        NewQList = QList

  end,
  io:fwrite( "item queue len:~p~n", [ queue:len( NewQList ) ] ),
  manage( NewQList ).

stored( NAME, WatchQ ) ->
  receive
    { "watch", Q } ->
      L = lists:filter( fun(X) -> {N,U} = X, N == NAME end, queue:to_list( Q ) ),
      L2 = lists:map( fun(X) -> {N,U} = X, list_to_atom( "user_list#"++ U ) end, L ),
      NewWatchQ = queue:from_list( L2 );
       
    { "data", Data } ->
        NewWatchQ = WatchQ,
        WATCH = fun(X) ->
            io:fwrite( "send ~p to~p~n", [ Data, X ]),
            X ! { Data },
        true end,
        queue:filter(WATCH,NewWatchQ)
  end,
  stored( NAME, NewWatchQ ).

