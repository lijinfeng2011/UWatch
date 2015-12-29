-module(watch_accept).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port) ->
  Pid = spawn(fun() -> manage([]) end),
  register(accept_manager,Pid),

  P = spawn(fun() -> filter() end),
  register(accept_filter,P),

  {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
  watch_log:info("server listen: ~w~n", [Port]),
  do_accept(LSocket).

do_accept(LSocket) ->
  case gen_tcp:accept(LSocket) of
      {ok, Socket} ->
          case inet:peername(Socket) of 
              {ok, {Address,_}} -> IP_Address = Address;
              _ -> IP_Address = '0.0.0.0'
          end,
          case watch_auth:check_ip( IP_Address ) of
            true -> 
              watch_log:info("accept:~p~n", [ IP_Address ] ),
              
              spawn(fun() -> handle_client(Socket) end);
            false ->
              watch_log:warn("deny: ~p~n", [ IP_Address ] ),
              gen_tcp:send( Socket, "deny" ),
              gen_tcp:close( Socket )
       end;
       {error, Reason} -> watch_log:error( "accept fail ~p~n", Reason )
   end,
   do_accept(LSocket).

handle_client(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, "data"} -> 
        gen_tcp:send( Socket, "data modle" ),
        handle_item(Socket);
    {ok, Data} ->
         watch_log:info( "[API] ~p~n", [ Data ] ),
         [_,DATA|_] = string:tokens( Data, " " ),
         gen_tcp:send( Socket, watch_api:call( string:tokens( DATA, "/" ) )),
         gen_tcp:close( Socket );
    {error, closed} ->
      watch_log:error( "register fail" )
  end.

handle_item( Socket ) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
       lists:map( fun(X) -> accept_manager ! { data, X} end, string:tokens( Data, "\n" ) ),
       handle_item( Socket );
    {error, closed} -> watch_log:info( "close~n" ), gen_tcp:close( Socket )
  end.

filter() ->
  Filter = watch_filter:list4name("main"),
  Broken = watch_broken:listbroken(),
  L = sets:to_list(sets:from_list(lists:append(Filter,Broken))),
  try
    accept_manager ! { filter, L }
  catch
    error:badarg -> watch_log:error( "send filter to main fail~n" )
  end,
  timer:sleep(5000),
  filter().

manage(Filter) ->
  receive
    { filter, List } -> 
        watch_log:info( "main filter is change~n" ),
        manage( List );
    { data, Data } ->
      DATA = string:tokens(Data,"#"),
      case length(DATA) > 2 of
          true ->
              [ MARK, ITEM | D ] = DATA,
              case MARK == "@@" of
                 true ->
                  DD = string:join(D,"#"),
                  MATCH = lists:filter(fun(X) -> re:run(DD, X) /= nomatch end, Filter),
                  case length( MATCH ) > 0 of
                    true -> watch_log:info("main filter:~p~n",[DD] );
                    false ->
                      NAME = list_to_atom( "item_list#"++ ITEM ),
                      try
                         NAME ! { "data", DD }
                      catch
                         error:badarg -> watch_item:add(ITEM)
                      end
                  end;
                  false -> false
              end;
          false -> false
      end,
      manage(Filter)
  end.
