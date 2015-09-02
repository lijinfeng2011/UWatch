-module(nqueue).
-export([start/1]).

-define(TCP_OPTIONS, [ list, {packet, 0}, {active, false}, {reuseaddr, true}]).
-define(CONFIG_ALLOW, "../allow_ip").

start(Port) ->
  Pid = spawn( fun() -> manage_groups( queue:new()) end ),
  register( group_manager, Pid ),

  {ok, LSocket} = gen_tcp:listen( Port, ?TCP_OPTIONS ),
  ID = 1,
  io:format( "listen:~w~n", [Port] ),
  do_accept(LSocket, ID).

do_accept(LSocket,ID) ->
  {ok, Socket} = gen_tcp:accept(LSocket),

  {ok, {IP_Address, Port}} = inet:peername(Socket),

  case check_ip( IP_Address ) of
    true -> 
      io:format("IP_Address:~p:~p~n", [ IP_Address, Port ] ),
      spawn(fun() -> in_group(Socket, ID ) end),
      NewID = ID + 1,
      do_accept(LSocket,NewID);
   false ->
      io:format("IP_Address:~p deny~n", [ IP_Address ] ),
      gen_tcp:close( Socket ),
      do_accept( LSocket, ID )
   end.

check_ip( IP ) ->
  case file:consult( ?CONFIG_ALLOW ) of
    { ok, IPLIST } ->
      lists:member(IP, IPLIST);
    { error } ->
      io:format("load config err.~n" ),
      false
  end.

in_group(Socket,ID) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      GroupXX = string:substr(Data, 1, 12),
      Group = list_to_atom( "group_"++ GroupXX ),
      group_manager ! {connect, {ID, Group, Socket}};    
    {error, closed} ->
      io:format("init group to client fail~n" )
  end.

manage_groups( Qgroup ) ->
  receive
    { connect, { ID, Group, Socket } } ->
       case queue:member( Group, Qgroup ) of
           true  -> NewQgroup = Qgroup;
           false -> NewQgroup = queue:in( Group, Qgroup ), 
                    Pid = spawn(fun() -> manage_clients(Group,[],queue:new()) end),
                    register( Group, Pid)
       end,
      Group ! {connect, {ID, Socket}},
     spawn(fun() -> handle_client(Socket, ID, Group ) end),
      io:fwrite( "queue len: ~p~n", [ queue:len( NewQgroup ) ] )
  end,
  manage_groups( NewQgroup ).

handle_client(Socket,ID,Group) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      Group ! {data,  {ID, Data}},
      handle_client( Socket, ID, Group );
    {error, closed} ->
      Group ! {disconnect, { ID, Group, Socket }}
  end.

manage_clients( Gname, Sockets, Q ) ->
  receive
    {connect, Socket} ->
      io:fwrite( "Socket connected: ~w~n", [Socket] ),
      NewSockets = [Socket | Sockets],
      NewQ = Q;
    {disconnect, Socket} ->
      io:fwrite( "Socket disconnected: ~w~n", [Socket] ),
      NewSockets = lists:delete(Socket, Sockets),
      NewQ = Q;
    {data, {ID, Data}} ->
      NewSockets = Sockets,
      
      if Data == "+1" ->
           case queue:is_empty( Q ) of
               true  -> NewQ = queue:new();
               false -> { {value, Item }, NewQ } = queue:out( Q ),
                        send_data(Sockets, {ID,Item})
           end;
%         true ->  TmpQ = queue:from_list( string:tokens( Data, "\n" ) ),
%                  NewQ = queue:join( Q, TmpQ )
          true -> NewQ = queue:in( Data, Q )

      end,
      io:fwrite( "G:~p len:~p~n", [ Gname, queue:len( NewQ ) ] )
  end,
  manage_clients( Gname, NewSockets, NewQ ).

send_data(Sockets, {ID, Data}) ->
  SendData = fun(Socket) ->
    { I, S } = Socket,
    if  I == ID -> gen_tcp:send(S, lists:concat([ Data, "\n"]));
       true -> true
    end
  end,
  lists:foreach( SendData, Sockets ).
