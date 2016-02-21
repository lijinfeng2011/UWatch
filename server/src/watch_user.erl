-module(watch_user).
-compile(export_all).

-define(INTERVAL, 60).
-define(DEFAULT_MAX_MESG, 10000).

start() ->
  spawn( fun() -> refresh() end ).

add(User,Passwd) ->
  case length(watch_db:get_user(User)) == 1 of
    true -> true;
    false -> watch_db:set_user(User,Passwd,"")
  end.

del(User) -> watch_db:del_user(User).
set_table(Table) -> 
    case string:tokens(Table, ":" )  of
        [User,Passwd|Info] ->
            watch_db:set_user(User,Passwd,string:join(Info,":"));
        _ -> "fail"
    end.

list() -> watch_db:list_user().
list_info() -> lists:map( fun(X) -> string:join(tuple_to_list(X),":") end, watch_db:list_user_info()).

list_table() -> lists:map( fun(X) -> string:join(tuple_to_list(X),":") end, watch_db:list_user_table()).

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

changepwd(User, NewPwd) ->
  case watch_db:set_user_passwd(User, NewPwd) of
    { error } -> "set failed";
     _        -> "success"
  end.

setindex( User, Item, Index ) -> watch_db:set_userindex( User ++ "##" ++ Item, Index ).
getindex( User, Item )        -> watch_db:get_userindex( User ++ "##" ++ Item ).

setindex4notify( User, Item, Index ) -> watch_db:set_userindex4notify( User ++ "##" ++ Item, Index ).
getindex4notify( User, Item )        -> watch_db:get_userindex4notify( User ++ "##" ++ Item ).

setinfo( User, Info )  -> watch_db:set_user_info( User, Info ).
getinfo( User )        -> 
  case watch_db:get_user_info( User ) of
    [I] -> I;
    _ -> ""
  end.

getnamebyphone( Phone ) -> watch_db:get_name_by_phone( Phone ).

getinterval( User ) ->
  [Info] = watch_db:get_user_info(User),
  InfoList = string:tokens(Info,":"),
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

mesg( User, Item, From, Type, Limit ) -> mesg( User, Item, From, Type, Limit, "_" ).

mesg( User, Item, From, Type, Limit, IndexType ) ->
  case IndexType of
    "notify" ->  UserId = getindex4notify( User,Item );
    _ -> UserId = getindex( User,Item )
  end,

  case From of
    "curr" -> FromId = UserId;
    _ -> FromId = list_to_integer(From)
  end,

  case Limit of
    "all" -> LIMIT = ?DEFAULT_MAX_MESG;
    L -> LIMIT = list_to_integer(L)
  end,

  Mesg = watch_item:disk_log( Item, "mesg" ),

  case length(Mesg) > 0 of
      true ->
          M = lists:reverse(Mesg),
          case Type of
            "tail" -> mesg_grep(tail,M,FromId,LIMIT);
            _ -> OutMesg = mesg_grep(head,M,FromId,LIMIT), 
        
                 [ New|_] = M,
                 case re:split(New,"[*]",[{return,list}]) of
                     [[],Index|_] ->
                         case catch list_to_integer(Index) of
                             {'EXIT',_} -> NewId = 0;
                             I -> NewId = I
                         end;
                     _ -> NewId = 0
                 end,
                 case NewId > UserId of
                   true ->
                        case IndexType of
                            "notify" -> setindex4notify( User,Item, NewId );
                             _ -> setindex( User,Item, NewId )
                        end;
                   false -> false
                 end,
                 OutMesg
          end;
      false -> []
  end.
 
mesg_grep(Type,Mesg,FromId,Limit) -> mesg_grep(Type,Mesg,FromId,Limit,[]).
mesg_grep(Type,Mesg,FromId,Limit,Out) ->
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
                      {'EXIT',_} -> mesg_grep(Type,NewMesg,Limit,Out);
                      I ->
                         case Type of 
                             tail ->
                                 case I < FromId of
                                     true -> mesg_grep(Type,NewMesg,FromId,Limit,Out++[M]);
                                     false -> mesg_grep(Type,NewMesg,FromId,Limit,Out)
                                 end;
                             _ ->
                                 case I > FromId of
                                     true -> mesg_grep(Type,NewMesg,FromId,Limit,Out++[M]);
                                     false -> mesg_grep(Type,NewMesg,FromId,Limit,Out)
                                 end
                         end
                   end;
                _ -> mesg_grep(Type,NewMesg,FromId,Limit,Out)
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
             Pid = spawn(fun() -> stored(X,[]) end),
             watch_log:info("start user:~p~n",[USER]),
             register( USER, Pid );
           false -> USER ! { check, Time }
         end
         %watch_log:info("user refresh:~p~n", [X])
      end,
      watch_db:list_user()
  ),
  timer:sleep( 5000 ),
  refresh().


stored(NAME,SList) ->
  receive
    { check, Time } -> 
        UserMsec = watch_db:get_last("user#"++NAME),
        UserInterval = watch_user:getinterval(NAME),
     
        case UserMsec + UserInterval * 1000 < Time of
            true ->
                case watch_notify:getstat( NAME ) of 
                    "off" -> watch_log:info( "user ~p off~n",[NAME]),false;
                     _    -> 
                           ItemList = sets:to_list(sets:from_list(
                                          SList++watch_relate:list4user_itemnameonly(NAME))),
                           AlarmList = lists:filter(
                               fun(X) ->
                                   TmpTime = watch_db:get_last("item#"++X),
                                   UserMsec<TmpTime
                               end, 
                           ItemList),

                           %% to cronos
                           watch_log:debug( 
                               "user:~p  UserMsec:~p UserInterval:~p Time:~p AlarmList:~p~n",
                                [NAME,UserMsec,UserInterval,Time,AlarmList]),
                           Cronos = list_to_atom("cronos#"++NAME),
                           try
                               Cronos ! { notify, AlarmList }
                           catch
                               error:badarg -> false
                           end,

                           case length( AlarmList ) > 0 of
                               true ->
                                   watch_notify:notify( NAME,AlarmList),
                                   
                                   %% forward AlarmList
                                   watch_notify:forward( [NAME],[],NAME,notify,AlarmList);

                              false -> false
                           end
                end,
                watch_db:set_last("user#"++NAME, Time),
                stored(NAME,[]);
            false -> stored(NAME,SList)
        end;
        
    { notify, Item } -> stored(NAME,SList++Item);
    { notice, Mesg } -> watch_notify:notice(NAME,Mesg),stored(NAME,SList)
        
  end.
