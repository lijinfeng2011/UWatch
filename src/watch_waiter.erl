-module(watch_waiter).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).
-define(ITEM_MESG_PATH, "../data/item/mesg/").

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
    {ok, "data\n"} -> 
        gen_tcp:send( Socket, "data modle" ),
        handle_item(Socket);
 
    {ok, Data} ->
%        io:format( "url~p~n", [ Data ] ),
        case string:tokens( Data, " /" ) of

            [ "GET", "relate", "add", ITEM, USER| _] -> 
              lists:foreach( fun(X) -> watch_relate:add(X,USER) end,string:tokens( ITEM, ":" ) ), ok( Socket );
            [ "GET", "relate", "del", ITEM, USER| _] ->
              lists:foreach( fun(X) -> watch_relate:del(X,USER) end,string:tokens( ITEM, ":" ) ), ok( Socket );
            [ "GET", "relate", "list" | _ ]  ->
               ok( Socket, lists:map( fun(X) -> {I,U} = X, I++ ":" ++ U end,watch_relate:list()));
            [ "GET", "relate", "list4user", USER | _ ]  ->
               ok( Socket, watch_relate:list4user(USER) );

            [ "GET", "item", "add", ITEM| _]     -> watch_item:add(ITEM), ok( Socket );
            [ "GET", "item", "del", ITEM| _]     -> watch_item:del(ITEM), ok( Socket );
            [ "GET", "item", "list" | _ ]        -> ok( Socket, watch_item:list() );
            [ "GET", "item", "mesg", ITEM | _ ]  -> ok( Socket, watch_item:disk_log(ITEM, "mesg" ) );
            [ "GET", "item", "count", ITEM | _ ] -> ok( Socket, watch_item:disk_log(ITEM, "count" ) );

            [ "GET", "user", "add", USER, PASS| _]  -> watch_user:add(USER, PASS ),ok( Socket );
            [ "GET", "user", "del", USER| _]        -> watch_user:del(USER), ok( Socket );
            [ "GET", "user", "list" | _ ]           -> ok( Socket, watch_user:list() );
            [ "GET", "user", "mesg", USER, ITEM | _ ]     -> ok( Socket, watch_user:mesg(USER,ITEM) );
            [ "GET", "user", "auth",USER, PASS| _ ] -> 
               gen_tcp:send( Socket, watch_user:auth(USER,PASS) ), gen_tcp:close( Socket );

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
              [ MARK, ITEM | D ] = DATA,
              case MARK == "@@" of
                 true ->
                  NAME = list_to_atom( "item_list#"++ ITEM ),
                  try
                      NAME ! { "data", string:join(D, "#") }
                  catch
                      error:badarg -> watch_item:add(ITEM)
                  end;
                  false -> false
              end;
          false -> false
      end
  end,
  manage().

ok( Socket ) ->
  gen_tcp:send( Socket, "ok" ), gen_tcp:close( Socket ).

ok( Socket, List ) ->
  lists:map( fun(X) -> gen_tcp:send( Socket, X ++"\n" ) end, List ),
  gen_tcp:close( Socket ).
