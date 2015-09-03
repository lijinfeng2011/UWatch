-module(watch_user).
-export([start/0]).


start() ->
  Pid = spawn( fun() -> manage( queue:new()) end ),
  register( user_manager, Pid ).


manage( QList ) ->
  receive
    { "add", NAME } ->
       case queue:member( NAME, QList ) of
           true  -> NewQList = QList;
           false -> NewQList = queue:in( NAME, QList ), 
                    Pid = spawn(fun() -> stored(NAME,queue:new()) end),
                    QNAME = list_to_atom( "user_list#"++ NAME ),
                    register( QNAME, Pid )
       end,
       io:fwrite( "add data list~n" )
  end,
  io:fwrite( "datalist len:~p~n", [ queue:len( NewQList ) ] ),
  manage( NewQList ).

stored( NAME, Queue ) ->
  receive
    { Data } -> NewQueue = queue:in( Data, Queue )
  end,
  io:fwrite( "user ~p stored len:~p~n", [ NAME, queue:len( NewQueue ) ] ),
  stored( NAME, NewQueue ).
