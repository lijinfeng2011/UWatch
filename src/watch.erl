-module(watch).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).
-define(CONFIG_ALLOW, "../allow_ip").

start(Port) ->

  PidList = spawn( fun() -> manage_list( queue:new()) end ),
  register( list_manager, PidList ),

  PidRelate = spawn( fun() -> manage_relate( queue:new()) end ),
  register( relate_manager, PidRelate ),

  PidRelateRefresh = spawn( fun() -> manage_relate_refresh() end ),
  register( relate_manager_refresh, PidRelateRefresh ),



  {ok, LSocket} = gen_tcp:listen( Port, ?TCP_OPTIONS ),
  ID = 1,
  io:format( "listen:~w~n", [Port] ),
  do_accept(LSocket, ID).

do_accept(LSocket,ID) ->
  {ok, Socket} = gen_tcp:accept(LSocket),

  {ok, {IP_Address, Port}} = inet:peername(Socket),

  case watch_auth:check_ip( IP_Address ) of
    true -> 
      io:format("IP_Address:~p:~p~n", [ IP_Address, Port ] ),
      spawn(fun() -> register_client(Socket, ID ) end),
      NewID = ID + 1,
      do_accept(LSocket,NewID);
   false ->
      io:format("IP_Address:~p deny~n", [ IP_Address ] ),
      gen_tcp:close( Socket ),
      do_accept( LSocket, ID )
   end.



register_client(Socket,ID) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, "ctrl"} -> 
        gen_tcp:send( Socket, "into ctrl" ),
        handle_ctrl(Socket,ID);
    {ok, "data"} -> 
        gen_tcp:send( Socket, "into data" ),
        handle_data(Socket,ID);
    {ok, Data} ->
        gen_tcp:send( Socket, "unkown" ),
        register_client(Socket,ID);
    {error, closed} ->
      io:format( "register client fail~n" )
  end.

handle_ctrl(Socket,ID) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
%      gen_tcp:send( Socket, lists:concat([ "i get u mesg into data:", Data, "\n"]) ),
%      CTRL = list_to_tuple( string:tokens( Data, "#" ) ),
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
              { "datalist", TYPE, CNAME } ->
                list_manager ! {TYPE, CNAME };
              Other -> io:format( "command undef~n" )
            end;
        4 ->
            case list_to_tuple( CTRL ) of 
              { "relate", "del", CNAME, CUSER } ->
                relate_manager ! {"del", CNAME, CUSER };
              Other -> io:format( "commaaaaaaaaaand undef~n" )
            end;
        5 ->
            case list_to_tuple( CTRL ) of 
              { "relate", "add", CNAME, CUSER, CTIME } ->
                relate_manager ! {"add", CNAME, CUSER, CTIME };
              Other -> io:format( "command undef~n" )
            end;
        Etrue -> io:format( "error command~n" )
      end,
      handle_ctrl( Socket, ID );
    {error, closed} ->
      gen_tcp:close( Socket )
  end.

handle_data(Socket,ID) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      DATA = string:tokens( Data, "#" ),
      case length(DATA) > 1 of
          true ->
              [LISTNAME| D ] = DATA,
              NAME = list_to_atom( "data_list_"++ LISTNAME ),
              try
                  NAME ! {lists:concat([ D, "#" ]) }
              catch
                  error:badarg -> io:fwrite( "eraaaar data~n" ),
                                 list_manager ! {"add", LISTNAME }
              end,
              handle_data( Socket, ID );
          false -> io:fwrite( "err data~n" ), handle_data( Socket, ID )
      end;
    {error, closed} ->
      gen_tcp:close( Socket )
  end.


manage_list( QList ) ->
  receive
    { "add", NAME } ->
       case queue:member( NAME, QList ) of
           true  -> NewQList = QList;
           false -> NewQList = queue:in( NAME, QList ), 
                    Pid = spawn(fun() -> data_stored(queue:new()) end),
                    QNAME = list_to_atom( "data_list_"++ NAME ),
                    register( QNAME, Pid )
       end,
       io:fwrite( "add data list~n" )
  end,
  io:fwrite( "datalist len:~p~n", [ queue:len( NewQList ) ] ),
  manage_list( NewQList ).

data_stored( DataQueue ) ->
  receive
    { Data } -> NewDataQueue = queue:in( Data, DataQueue )
  end,
  io:fwrite( "data len:~p~n", [ queue:len( NewDataQueue ) ] ),
  data_stored( NewDataQueue ).

manage_relate_refresh( ) ->
  receive
    { Q } ->
 
       io:fwrite( "unkown the cQQQQQQQQQQommand~n" );
    Other ->
       io:fwrite( "unkown the command~n" )
  end,
  manage_relate_refresh().


manage_relate( QList ) ->
  receive
    { "add", NAME, USER, TIME } ->
       Fun = fun(X) ->  { A,B,C} = X,{A,B} /= {NAME,USER} end,
       TMPList = queue:filter(Fun,QList),
       NewQList = queue:in( {NAME,USER,TIME}, TMPList ),
       relate_manager_refresh ! { NewQList };
    { "del", NAME, USER } ->
       Fun = fun(X) ->  { A,B,C} = X,{A,B} /= {NAME,USER} end,
       NewQList = queue:filter(Fun,QList),
       relate_manager_refresh ! { NewQList };
    { "list", SOCK } ->
       Fun = fun(X) ->
           { A,B,C} = X,
           gen_tcp:send( SOCK, A ++ "#" ++ B ++ "#" ++ C ++"\n"),
           A == A
       end,
       queue:filter(Fun,QList),
       NewQList = QList;
 
    Other ->
       NewQList = QList,
       io:fwrite( "unkown the command~n" )
  end,
  io:fwrite( "datalist len:~p~n", [ queue:len( NewQList ) ] ),
  manage_relate( NewQList ).


