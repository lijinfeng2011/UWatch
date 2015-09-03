-module(watch).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port) ->
  watch_item:start(),
  watch_user:start(),
  watch_relate:start(),

  {ok, LSocket} = gen_tcp:listen( Port, ?TCP_OPTIONS ),
  io:format( "port:~w~n", [Port] ),
  do_accept(LSocket).

do_accept(LSocket) ->
  {ok, Socket} = gen_tcp:accept(LSocket),

  {ok, {IP_Address, Port}} = inet:peername(Socket),

  case watch_auth:check_ip( IP_Address ) of
    true -> 
      io:format("IP_Address:~p:~p~n", [ IP_Address, Port ] ),
      spawn(fun() -> register_client(Socket ) end),
      do_accept(LSocket);
   false ->
      io:format("IP_Address:~p deny~n", [ IP_Address ] ),
      gen_tcp:close( Socket ),
      do_accept( LSocket )
   end.


register_client(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, "ctrl"} -> 
        gen_tcp:send( Socket, "ctrl modle" ),
        watch_ctrl:handle(Socket);
    {ok, "data"} -> 
        gen_tcp:send( Socket, "data modle" ),
        watch_item:handle(Socket);
    {ok, Data} ->
        gen_tcp:send( Socket, "unkown" ),
        register_client(Socket);
    {error, closed} ->
      io:format( "register fail" )
  end.
