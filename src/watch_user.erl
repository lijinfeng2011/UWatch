-module(watch_user).
-export([start/0]).


start() ->
  Pid = spawn( fun() -> manage( queue:new()) end ),
  register( user_manager, Pid ).


manage( Q ) ->
  receive
    { "add", NAME } ->
       case queue:member( NAME, Q ) of
           true  -> NewQ = Q;
           false -> NewQ = queue:in( NAME, Q ), 
                    { H,M,S} = time(),
                    Pid = spawn(fun() -> stored(NAME,queue:new(),M) end),
                    register( list_to_atom( "user_list#"++ NAME ), Pid )
       end
  end,
  io:fwrite( "user list len:~p~n", [ queue:len( NewQ ) ] ),
  manage( NewQ ).

stored( NAME, Queue, TIME ) ->
  receive
    { Data } -> 
       {H,M,S} = time(),
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
    {H,M,S} = time(),
    case M == TIME of
      false ->
        Mesg = string:join(queue:to_list( Queue ), "#-cut-#" ),
        mesg_manager ! { "mesg", NAME, Mesg },
        NewTIME = M, NewQueue = queue:new();
      true ->
          NewTIME = TIME, NewQueue = Queue
    end
    
  end,
  io:fwrite( "user ~p stored len:~p~n", [ NAME, queue:len( NewQueue ) ] ),
  stored( NAME, NewQueue, NewTIME ).
