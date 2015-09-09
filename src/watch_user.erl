-module(watch_user).
-export([start/0,add/2,del/1,list/0,auth/2]).

start() ->
%  Pid = spawn( fun() -> manage() end ),
%  register( user_manager, Pid ),

  spawn( fun() -> refresh() end ).


add( USER, PASS ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
  case length( L2 ) > 0 of
    true -> true;
    false -> dets:insert(watch_dets, {user, USER, PASS })
  end.

del( USER ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
  lists:foreach( fun(X) -> dets:delete_object(watch_dets, X) end, L2).

list() ->
  lists:map( fun(X) -> {_,U,_} = X, U end, dets:lookup( watch_dets, user )).

auth( USER, PASS ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {user,USER,PASS} =:= X end, L1),
  case length( L2 ) > 0 of
    true -> "ok";
    false -> "fail"
  end.

%manage() ->
%  receive
%    { "add", USER, PASS, SOCK } ->
%         L1 = dets:lookup( watch_dets, user ),
%         L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
%         case length( L2 ) > 0 of
%           true -> true;
%           false -> dets:insert(watch_dets, {user, USER, PASS })
%         end,
%         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
%    { "del", USER, SOCK } ->
%         L1 = dets:lookup( watch_dets, user ),
%         L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
%         lists:foreach( fun(X) -> dets:delete_object(watch_dets, X) end, L2),
%         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
%    { "list", SOCK } ->
%         lists:map(
%             fun(X) -> {user,U,P} = X, gen_tcp:send( SOCK, U ++"\n" ) end,
%             dets:lookup( watch_dets, user )
%         ),
%         gen_tcp:close( SOCK );
%    { "auth", USER, PASS, SOCK } ->
%         L1 = dets:lookup( watch_dets, user ),
%         L2 = lists:filter(fun(X) -> {user,USER,PASS} =:= X end, L1),
%         case length( L2 ) > 0 of
%           true ->  gen_tcp:send( SOCK, "ok" );
%           false ->  gen_tcp:send( SOCK, "fail" )
%         end,
%         gen_tcp:close( SOCK );
% 
%    _ -> true
%  end,
%  manage().

refresh() ->
  lists:map(
      fun(X) -> {user,U,_} = X,
         USER = list_to_atom( "user_list#"++ U ),
         case whereis( USER ) =:= undefined of
           true ->
             Pid = spawn(fun() -> stored(U,queue:new(),61) end),
             io:format("new ~p~n",[USER]),
             register( USER, Pid );
           false -> false
         end
      end,
      dets:lookup( watch_dets, user )
  ),
  timer:sleep( 60000 ),
  refresh().


stored( NAME, Queue, TIME ) ->
  receive
    { ITEM, Data } -> 
       io:format("user ~p get data ~p~n",[NAME, ITEM, Data]),
       TmpQueue = queue:in( { ITEM, Data }, Queue ),
       {_,M,_} = time(),
       case M == TIME of
           false -> 
             Mesg = binary_to_list(list_to_binary(queue:to_list( TmpQueue ))),
        try
            mesg_manager ! { "mesg", NAME, Mesg }
        catch
            error:badarg -> io:fwrite( "user:~p send:~p to mesg_manager fail~n", [ NAME, Mesg ] )
        end,
 
             NewTIME = M, NewQueue = queue:new();
           true -> NewTIME = TIME, NewQueue = TmpQueue
       end;
     true -> NewTIME = TIME, NewQueue = Queue
  after 3000 ->
    {_,M,_} = time(),
    case M == TIME of
      false ->
        Mesg = string:join(queue:to_list( Queue ), "#-cut-#" ),
        try
            mesg_manager ! { "mesg", NAME, Mesg }
        catch
            error:badarg -> io:fwrite( "user:~p send:~p to mesg_manager fail~n", [ NAME, Mesg ] )
        end,
 
        NewTIME = M, NewQueue = queue:new();
      true ->
          NewTIME = TIME, NewQueue = Queue
    end
  end,
  stored( NAME, NewQueue, NewTIME ).
