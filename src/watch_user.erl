-module(watch_user).
-export([start/0]).

start() ->
  Pid = spawn( fun() -> manage() end ),
  register( user_manager, Pid ),

  spawn( fun() -> refresh() end ).

manage() ->
  receive
    { "add", USER, SOCK } ->
         dets:insert(watch_dets, {user, USER }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
    { "del", USER, SOCK } ->
         dets:delete_object(watch_dets, {user, USER }),
         gen_tcp:send( SOCK, "ok" ), gen_tcp:close( SOCK );
    { "list", SOCK } ->
         lists:map(
             fun(X) -> {user,U} = X, gen_tcp:send( SOCK, U ++ "\n" ) end,
             dets:lookup( watch_dets, user )
         ),
         gen_tcp:close( SOCK );
    _ -> true
  end,
  manage().

refresh() ->
  io:fwrite( "refresh~n" ),
  lists:map(
      fun(X) -> {user,I} = X,
         USER = list_to_atom( "user_list#"++ I ),
         case whereis( USER ) =:= undefined of
           true ->
             { _,M,_} = time(),
             Pid = spawn(fun() -> stored(USER,queue:new(),M) end),
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
    { Data } -> 
       {_,M,_} = time(),
       TmpQueue = queue:in( Data, Queue ),
       case M == TIME of
           false -> 
             Mesg = binary_to_list(list_to_binary(queue:to_list( TmpQueue ))),
             mesg_manager ! { "mesg", NAME, Mesg },
             NewTIME = M, NewQueue = queue:new();
           true ->
             NewTIME = TIME, NewQueue = TmpQueue

       end
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
