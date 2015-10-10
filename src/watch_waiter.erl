-module(watch_waiter).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port) ->
  Pid = spawn(fun() -> manage() end),
  register(waiter_manager,Pid),

  {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
  io:format("port:~w~n", [Port]),
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
              io:format("[WARM] wolcome:~p~n", [ IP_Address ] ),
              spawn(fun() -> handle_client(Socket) end);
            false ->
              io:format("[WARM] IP_Address:~p deny~n", [ IP_Address ] ),
              gen_tcp:send( Socket, "deny" ),
              gen_tcp:close( Socket )
       end;
       {error, Reason} -> io:format( "~p~n", Reason )
   end,
   do_accept(LSocket).

handle_client(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, "data"} -> 
        gen_tcp:send( Socket, "data modle" ),
        handle_item(Socket);
    {ok, Data} -> 
         [_,DATA|_] = string:tokens( Data, " " ),
        case string:tokens( DATA, "/" ) of
            ["relate","add",ITEM,USER] -> 
              lists:foreach( fun(X) -> watch_relate:add(X,USER) end,string:tokens( ITEM, ":" ) ), ok( Socket );
            ["relate","del",ITEM,USER] ->
              lists:foreach( fun(X) -> watch_relate:del(X,USER) end,string:tokens( ITEM, ":" ) ), ok( Socket );
            ["relate","list"] ->
               ok( Socket, lists:map( fun(X) -> {I,U} = X, I++ ":" ++ U end,watch_relate:list()));
            ["relate","list4user",USER]  ->
               ok( Socket, watch_relate:list4user(USER) );

            ["item","add",ITEM]     -> watch_item:add(ITEM), ok( Socket );
            ["item","del",ITEM]     -> watch_item:del(ITEM), ok( Socket );
            ["item","list"]         -> ok( Socket, watch_item:list() );
            ["item","mesg",ITEM]    -> ok( Socket, watch_item:disk_log(ITEM, "mesg" ) );
            ["item","count",ITEM]   -> ok( Socket, watch_item:disk_log(ITEM, "count" ) );

            ["user","add",USER,PASS]     -> watch_user:add(USER, PASS ),ok( Socket );
            ["user","del", USER]         -> watch_user:del(USER), ok( Socket );
            ["user","list"]              -> ok( Socket, watch_user:list() );
            ["user","mesg",USER,ITEM]    -> ok( Socket, watch_user:mesg(USER,ITEM) );
            ["user","getinfo",USER]      -> ok( Socket, [ watch_user:getinfo(USER) ] );
            ["user","setinfo",USER,INFO] -> watch_user:setinfo(USER,INFO), ok( Socket );
            ["user","auth",USER,PASS]    -> 
               gen_tcp:send( Socket, watch_user:auth(USER,PASS) ), gen_tcp:close( Socket );

            ["follow","add",Owner,Follower] -> 
              lists:foreach( 
                fun(X) -> watch_follow:add(X,Follower) end,string:tokens( Owner, ":" )),
                ok( Socket );
            ["follow","del",Owner,Follower] -> 
              lists:foreach( 
                fun(X) -> watch_follow:del(X,Follower) end,string:tokens( Owner, ":" )),
                ok( Socket );
            ["follow","update",Owner,Follower] -> watch_follow:update(Owner, Follower), ok( Socket );
            ["follow","del4user",Owner] -> watch_follow:del4user(Owner), ok( Socket );
            ["follow","list"] -> ok( Socket, watch_follow:list() );
            ["follow","list4user",USER] -> ok( Socket, watch_follow:list(USER) );

            ["stat","list"] -> ok( Socket, watch_stat:list() );
            ["last","list"] -> ok( Socket, watch_last:list() );

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
    {error, closed} -> io:format( "close~n" ), gen_tcp:close( Socket )
  end.

manage() ->
  receive
    { Data } ->
      DATA = string:tokens(Data,"#"),
      case length(DATA) > 2 of
          true ->
              [ MARK, ITEM | D ] = DATA,
              case MARK == "@@" of
                 true ->
                  NAME = list_to_atom( "item_list#"++ ITEM ),
                  try
                      NAME ! { "data", string:join(D,"#") }
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
