-module(watch_user).
-export([start/0,add/2,del/1,list/0,auth/2,setindex/3,getindex/2,setinfo/2,getinfo/1,mesg/2,mesg/5,getinterval/1,changepwd/3]).

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

changepwd(User, OldPwd, NewPwd) ->
  case auth(User, OldPwd) of
    "ok" ->
      case watch_db:set_user_passwd(User, NewPwd) of
        { error } -> "set failed";
         _        -> "success"
      end;
    "fail" -> "auth failed"
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

mesg( User, Item, From, Type, Limit ) ->
  UserId = getindex( User,Item ),
  case From of
    "new" -> FromId = UserId;
    _ -> FromId = list_to_integer(From)
  end,

  LIMIT = list_to_integer(Limit),
  Mesg = watch_item:disk_log( Item, "mesg" ),

  case Type of
    "tail" -> M = lists:reverse(Mesg), mesg_tail(M,FromId,LIMIT);
    _ -> {NewId,OutMesg} = mesg_head(Mesg,FromId,LIMIT), 
         case NewId > UserId of
           true -> setindex( User,Item, NewId );
           false -> false
         end,
         OutMesg
  end.
  
mesg_head(Mesg,FromId,Limit) -> mesg_head(Mesg,FromId,Limit, 0, []).

mesg_head(Mesg,FromId,Limit,Id,Out) ->
  case length(Out) >= Limit of
    true -> { Id, Out };
    false ->
       case length(Mesg) == 0 of
         true -> { Id, Out };
         false ->
           [M|NewMesg] = Mesg,
           case re:split(M,"[*]",[{return,list}]) of
             [[],Index|_] ->
                 case catch list_to_integer(Index) of
                     {'EXIT',_} -> mesg_head(NewMesg,FromId,Limit,Id,Out);
                     I ->
                       case I > FromId of
                           true -> mesg_head(NewMesg,FromId,Limit,I,Out++[M]);
                           false -> mesg_head(NewMesg,FromId,Limit,Id,Out)
                       end
                 end;
                 
             _ -> mesg_head(NewMesg,FromId,Limit,Id,Out)
           end
       end
  end.
mesg_tail(Mesg,FromId,Limit) -> mesg_tail(Mesg,FromId,Limit,[]).
mesg_tail(Mesg,FromId,Limit,Out) ->
  case length(Out) >= Limit of
    true -> Out;
    false ->
      case length(Mesg) == 0 of
          true -> Out;
          false ->
              [M|NewMesg] = Mesg,
              case re:split(M,"[*]",[{return,list}]) of
                [[],Index|_] ->
                   case catch list_to_integer(Index) of
                      {'EXIT',_} -> mesg_tail(NewMesg,Limit,Out);
                      I ->
                         case I < FromId of
                             true -> mesg_tail(NewMesg,FromId,Limit,[M]++Out);
                             false -> mesg_tail(NewMesg,FromId,Limit,Out)
                         end
                   end;
                _ -> mesg_tail(NewMesg,FromId,Limit,Out)
              end
      end
  end.

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
        io:format( "user~pcheck~p:~p:~p~n",[NAME, UserMsec, UserInterval, Time]),
     
        case UserMsec + UserInterval < Time of
            true ->
                ItemList = watch_relate:list4user_itemnameonly(NAME),
                AlarmList = lists:filter(
                               fun(X) ->
                                  TmpTime = watch_db:get_last("item#"++X),
                                  (UserMsec< TmpTime) and ( TmpTime<Time)
                               end, 
                            ItemList ),

               case length(AlarmList) > 0 of
                   true -> watch_notify:notify( NAME,AlarmList ),
                           watch_db:set_last("user#"++NAME, Time);
                   false -> false      
               end;
            false -> fase
        end
        
  end,
  stored(NAME).
