-module(watch_user).
-export([start/0,add/2,del/1,list/0,auth/2,setindex/3,getindex/2,mesg/2]).

start() ->
  spawn( fun() -> refresh() end ).

add(User,Passwd) ->
  case length(watch_db:get_user(User)) == 1 of
    true -> true;
    false -> watch_db:set_user(User,Passwd,"")
  end.

del(User) -> watch_db:del_user(User).
list() -> watch_db:list_user().

auth(User,Passwd) ->
  PASS = watch_db:get_user_passwd(User),
   case length(PASS) == 1 of
       true ->
           [P] = PASS,
           case P == Passwd of
               true -> "ok";
               false -> "fail"
           end;
       false -> "fail"
   end.

setindex( USER, ITEM, VALUE ) -> watch_db:set_userindex( USER ++ "##" ++ ITEM, VALUE ).
getindex( USER, ITEM ) -> watch_db:get_userindex( USER ++ "##" ++ ITEM ).

mesg( USER, ITEM ) ->
  ID = getindex( USER,ITEM ),
  lists:map( 
    fun(X) ->
       case re:split(X,"[*]",[{return,list}]) of
         [[],Index|_] ->
           case catch list_to_integer(Index) of
             {'EXIT',_} -> "0" ++ X;
             I ->
               if 
                 I > ID -> setindex( USER,ITEM, I ), "1" ++ X;
                 true -> "0" ++ X
               end
           end;
         _ -> "0" ++ X
       end
    end,
  watch_item:disk_log( ITEM, "mesg" )).

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
      watch_db:list_user()
  ),
  timer:sleep( 60000 ),
  refresh().


stored( NAME, Queue, TIME ) ->
  receive
    { ITEM, Data } -> 
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
