-module(watch_mesg).
-export([start/0]).


start() ->
  Pid = spawn( fun() -> manage() end ),
  register( mesg_manager, Pid ).


manage() ->
  receive
    { "mesg", NAME, MESG } -> io:fwrite( "mesg:~p#~p~n", [ NAME, MESG ] )
  end,
  manage().
