-module(watch_waiter).
-export([start/1]).

-define(TCP_OPTIONS, [ binary,{active,false},{packet,2} ]).
%-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port) ->

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
        handle_ctrl(Socket);
    {ok, "data"} -> 
        gen_tcp:send( Socket, "data modle" ),
        handle_item(Socket);
    {ok, Data} ->
        gen_tcp:send( Socket, "unkown" ),
        register_client(Socket);
    {error, closed} ->
      io:format( "register fail" )
  end.


handle_item( Socket ) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
       io:format( "data:~p ~n", [ Data ] ),
      DATA = string:tokens( Data, "#" ),
      case length(DATA) > 1 of
          true ->
              [ LISTNAME | D ] = DATA,
              NAME = list_to_atom( "item_list#"++ LISTNAME ),
              try
                  NAME ! { "data", string:join(D, "#") }
              catch
                  error:badarg -> item_manager ! { "add", LISTNAME }
              end,
              handle_item( Socket );
          false -> io:fwrite( "err data~n" ), handle_item( Socket )
      end;
    {error, closed} -> gen_tcp:close( Socket )
  end.

handle_ctrl(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      CTRL = string:tokens( Data, "#" ),
      case length(CTRL) of
        2 ->
            case list_to_tuple( CTRL ) of
              { "relate", "list" } ->
                relate_manager ! {"list", Socket };
              Other -> io:format( "commaaaaaaaaaand undef~n" )
            end;

        3 ->
            case list_to_tuple( CTRL ) of
              { "datalist", "add", CNAME } ->
                item_manager ! {"add", CNAME };
              Other -> io:format( "command undef~n" )
            end;
        4 ->
            case list_to_tuple( CTRL ) of
              { "relate", "del", CNAME, CUSER } ->
                relate_manager ! {"del", CNAME, CUSER };
              { "relate", "add", CNAME, CUSER } ->
                relate_manager ! {"add", CNAME, CUSER };
              Other -> io:format( "command undef~n" )
            end;
        Etrue -> io:format( "error command~n" )
      end,
      handle_ctrl( Socket );
    {error, closed} ->
      gen_tcp:close( Socket )
  end.

