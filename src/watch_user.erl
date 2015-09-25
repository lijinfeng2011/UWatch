-module(watch_user).
-export([start/0,add/2,del/1,list/0,auth/2,setindex/3,getindex/2,setinfo/2,getinfo/1,mesg/2,getinterval/1]).

-define(INTERVAL, 60).

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

setinfo( User, Info )  -> watch_db:set_user_info( User, Info ).
getinfo( User )        -> watch_db:get_user_info( User ).

getinterval( User ) ->
  [Info] = watch_db:get_user_info(User),
  InfoList = string:tokens(Info,"#"),
  case catch lists:nth(4,InfoList ) of
    {'EXIT',_} -> ?INTERVAL;
    V -> 
      case catch list_to_integer(V) of
          {'EXIT',_} -> ?INTERVAL;
          VV -> VV
      end
  end.

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
  Time = watch_misc:milliseconds(),
  lists:map(
      fun(X) ->
         USER = list_to_atom( "user_list#"++ X ),
         case whereis( USER ) =:= undefined of
           true ->
             Pid = spawn(fun() -> stored(X) end),
             io:format("new ~p~n",[USER]),
             register( USER, Pid );
           false -> USER ! { check, Time }
         end
      end,
      watch_db:list_user()
  ),
  timer:sleep( 5000 ),
  refresh().


stored(NAME) ->
  receive
    { check, Time } -> 
        UserMsec = watch_db:get_last("user#"++NAME),
        UserInterval = watch_user:getinterval(NAME),
     
        case UserMsec + UserInterval > Time of
            true ->
                ItemList = watch_relate:list4user_itemnameonly(NAME),
                AlarmList = lists:filter(
                               fun(X) ->
                                  TmpTime = watch_db:get_last("item#"++X),
                                  (UserMsec< TmpTime) and ( TmpTime<Time)
                               end, 
                            ItemList ),

               case length(AlarmList) > 0 of
                   true -> watch_notify:notify( NAME,AlarmList );
                   false -> false      
               end,
               watch_db:set_last("user#"++NAME, Time);
            false -> fase
        end
        
  end,
  stored(NAME).
