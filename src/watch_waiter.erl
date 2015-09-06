-module(watch_waiter).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port) ->
  Pid = spawn( fun() -> manage() end ),
  register( waiter_manager, Pid ),

  {ok, LSocket} = gen_tcp:listen( Port, ?TCP_OPTIONS ),
  io:format( "port:~w~n", [Port] ),
  do_accept(LSocket).

do_accept(LSocket) ->
  {ok, Socket} = gen_tcp:accept(LSocket),

  {ok, {IP_Address, Port}} = inet:peername(Socket),
  case watch_auth:check_ip( IP_Address ) of
    true -> 
      spawn(fun() -> handle_client(Socket ) end);
    false ->
      io:format("[WARM] IP_Address:~p deny~n", [ IP_Address ] ),
      gen_tcp:send( Socket, "deny" ),
      gen_tcp:close( Socket )
   end,
   do_accept(LSocket).


handle_client(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, "data"} -> 
        gen_tcp:send( Socket, "data modle" ),
        handle_item(Socket);
    {ok, Data} ->
        case string:tokens( Data, " /" ) of

%%%%%%%%%%%%%%%%%%%%  relate %%%%%%%%%%%%%%%%%%%%%%%%%%
            [ "GET", "relate", "add", ITEM, USER| _] ->
               relate_manager ! {"add", ITEM, USER, Socket };
            [ "GET", "relate", "del", ITEM, USER| _] ->
               relate_manager ! {"del", ITEM, USER, Socket };
            [ "GET", "relate", "list" | _ ] ->
               relate_manager ! {"list", Socket };
            [ "GET", "relate", "refresh" | _ ] ->
               relate_manager ! {"refresh", Socket };

%%%%%%%%%%%%%%%%%%%%  item %%%%%%%%%%%%%%%%%%%%%%%%%%
            [ "GET", "item", "add", ITEM| _] ->
               item_manager ! {"add", ITEM, Socket };
            [ "GET", "item", "del", ITEM| _] ->
               item_manager ! {"del", ITEM, Socket };
            [ "GET", "item", "list" | _ ] ->
               item_manager ! {"list", Socket };
            [ "GET", "item", "refresh" | _ ] ->
               item_manager ! {"refresh", Socket };

%%%%%%%%%%%%%%%%%%%%  user %%%%%%%%%%%%%%%%%%%%%%%%%%
            [ "GET", "user", "add", USER| _] ->
               user_manager ! {"add", USER, Socket };
            [ "GET", "user", "del", USER| _] ->
               user_manager ! {"del", USER, Socket };
            [ "GET", "user", "list" | _ ] ->
               user_manager ! {"list", Socket };


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            [ "GET", "datalist", "add", ITEM, USER| _] ->
               item_manager ! {"add", ITEM, USER },
               gen_tcp:send( Socket, "ok" ),
               gen_tcp:close( Socket );
            _ -> 
               gen_tcp:send( Socket, "undefinition" ),
               gen_tcp:close( Socket )
        end;
    {error, closed} ->
      io:format( "register fail" )
  end.


handle_item( Socket ) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
       lists:map( fun(X) -> waiter_manager ! {X} end, string:tokens( Data, "\n" ) ),
       handle_item( Socket );
    {error, closed} -> io:format( "close" ), gen_tcp:close( Socket )
  end.

manage() ->
  receive
    { Data } ->
      DATA = string:tokens( Data, "#" ),
      case length(DATA) > 2 of
          true ->
              [ MARK, LISTNAME | D ] = DATA,
              case MARK == "@@" of
                 true ->
                  NAME = list_to_atom( "item_list#"++ LISTNAME ),
                  try
                      NAME ! { "data", string:join(D, "#") }
                  catch
                      error:badarg -> item_manager ! { "add", LISTNAME }
                  end;
                  false -> false
              end;
          false -> false
      end
  end,
  manage().
