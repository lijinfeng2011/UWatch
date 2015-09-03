-module(watch_item).
-export([start/0,handle/1]).

start() ->
  Pid = spawn( fun() -> manage( queue:new() ) end ),
  register( item_manager, Pid ).


handle( Socket ) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      DATA = string:tokens( Data, "#" ),
      case length(DATA) > 1 of
          true ->
              [ LISTNAME | D ] = DATA,
              NAME = list_to_atom( "item_list#"++ LISTNAME ),
              try
                  NAME ! {lists:concat([ D, "#" ]) }
              catch
                  error:badarg -> item_manager ! { "add", LISTNAME }
              end,
              handle( Socket );
          false -> io:fwrite( "err data~n" ), handle( Socket )
      end;
    {error, closed} -> gen_tcp:close( Socket )
  end.


manage( QList ) ->
  receive
    { "add", NAME } ->
       case queue:member( NAME, QList ) of
           true  -> NewQList = QList;
           false -> NewQList = queue:in( NAME, QList ), 
                    Pid = spawn(fun() -> stored(NAME,queue:new()) end),
                    QNAME = list_to_atom( "item_list#"++ NAME ),
                    register( QNAME, Pid )
       end
  end,
  io:fwrite( "item queue len:~p~n", [ queue:len( NewQList ) ] ),
  manage( NewQList ).

stored( NAME, Queue ) ->
  receive
    { Data } -> NewQueue = queue:in( Data, Queue )
  end,
  io:fwrite( "item ~p len:~p~n", [ NAME, queue:len( NewQueue ) ] ),
  stored( NAME, NewQueue ).

