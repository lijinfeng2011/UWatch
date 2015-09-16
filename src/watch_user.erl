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

setindex( User, Item, Index ) -> watch_db:set_userindex( User ++ "##" ++ Item, Index ).
getindex( User, Item )        -> watch_db:get_userindex( User ++ "##" ++ Item ).

mesg( User, Item ) ->
  Id = getindex( User,Item ),
  lists:map( 
    fun(X) ->
       case re:split(X,"[*]",[{return,list}]) of
         [[],Index|_] ->
           case catch list_to_integer(Index) of
             {'EXIT',_} -> "0" ++ X;
             I ->
               if 
                 I > Id -> setindex( User,Item, I ), "1" ++ X;
                 true -> "0" ++ X
               end
           end;
         _ -> "0" ++ X
       end
    end,
  watch_item:disk_log( Item, "mesg" )).

refresh() ->
  lists:map(
      fun(X) -> {user,U,_} = X,
         USER = list_to_atom( "user_list#"++ U ),
         case whereis( USER ) =:= undefined of
           true ->
             Pid = spawn(fun() -> stored(U) end),
             io:format("new ~p~n",[USER]),
             register( USER, Pid );
           false -> USER ! { check }
         end
      end,
      watch_db:list_user()
  ),
  timer:sleep( 60000 ),
  refresh().


stored( NAME ) ->
  receive
    { check } -> io:format( "user ~p~n",[NAME])
  end,
  stored( NAME ).
