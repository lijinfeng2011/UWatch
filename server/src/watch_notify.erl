-module(watch_notify).
-compile(export_all).

-define(NOTIFY_PATH,"../data/notify/mesg").
-define(NOTIFY_DATA_SIZE,65536).
-define(NOTIFY_DATA_COUNT,3).

start() ->
  spawn( fun() -> mon() end ).

mon() ->
  case whereis( notify_stored ) =:= undefined of
      true ->
          case watch_disk_log:open(?NOTIFY_PATH, ?NOTIFY_DATA_SIZE, ?NOTIFY_DATA_COUNT) of

            {ok,Log} -> 
               Pid = spawn(fun() -> stored(Log) end),
               register( notify_stored, Pid );
            _ -> false

          end;
      false -> false
  end,
  timer:sleep( 30000 ),
  mon().


stored(Log) ->
  receive
    { Data } ->
      {{Y,M,D},{H,Mi,S}} = calendar:local_time(),
      TIME = lists:concat( [ Y,"-",M,"-",D,"-",H,"-",Mi, "-", S ] ),
      disk_log:log(Log, TIME ++ ":" ++ Data)
  end,
  stored(Log).

notify( User, List ) ->
    case watch_detail:getstat( User ) of
        "on" -> 
            %% detail modle
            Notice = lists:map(
                fun(X) ->
                    Mesg = watch_user:mesg(User,X,"curr", "head", "all","notify"),
                    Count = length( Mesg ),

                    case Count > 0 of
                        true ->

                            case Count > 19 of
                                true ->  Count_Mark = "more", NewMesg = lists:sublist( Mesg, 20 );
                                false -> Count_Mark = integer_to_list( Count ), NewMesg = Mesg
                            end,

                            Info = string:join([X,watch_db:get_stat(X), Count_Mark|NewMesg],"@@@"),
                            Level =  watch_notify_level:get_s(X),
                            {Info,Level,"1"};
                        false -> {}
                    end
                end,
            List),
            notice( User, Notice );
        _ ->
            ListStat = lists:map( 
                fun(X) -> 
                    Count = length(watch_user:mesg(User,X,"curr", "head", "all","notify")),
                    { X ++ ":"++ watch_db:get_stat(X) ++":"++ integer_to_list( Count ), Count , X }
                end, 
            List),

            NotifyItem = lists:filter(fun(X) -> {_,C,_} = X, C > 0 end, ListStat),
            AlarmList  = lists:map(   fun(X) -> {N,_,_} = X, N end, NotifyItem  ),

            case length( AlarmList ) > 0 of
                true -> 
                    MaxLevel =  watch_notify_level:get_max_s(lists:map( fun(X) -> {_,_,I} = X, I end, NotifyItem)),
                    notice(User, [{string:join( AlarmList, "@@@" ),MaxLevel,"0"}]);
                false -> false
            end
    end.

%% Do，Done, Type = notify or notice Mesg = ItemList or SendMesg
forward(Do,Done,Owner,Type,Mesg) -> forward(Do,Done,Owner,Type,Mesg, 0).
forward(Do,Done,Owner,Type,Mesg,C) ->
    case Do of
        [User|NewDo] ->
            case lists:member(User,Done) of
                true  -> forward(NewDo,Done,Owner,Type,Mesg);
                false ->
                    case Owner == User of
                        true -> skip;
                        false ->
                            USER = list_to_atom( "user_list#"++ User ),
                            try 
                                USER ! { Type, Mesg }
                            catch
                                error:badarg -> watch_log:error("forward mesg to ~p fail~n", [User] )
                            end
                    end,
                   
                    FORWARD = lists:append(
                        lists:map(
                            fun(X) ->
                                watch_log:debug( "watch_notify:forward1 ~p:~p~n", [User,X]),
                                case string:tokens(X,"-") of
                                    ["uwatch"|UWATCH] -> [string:join( UWATCH, "-" )];
                                     _ -> []
                                end
                            end,
                            string:tokens( watch_method:getmethod( User ), ":" ))),
                     
                     watch_log:debug( "watch_notify:forward2 ~p~n", [FORWARD]),
                     case C > 16 of
                         true -> false;
                         false -> forward(sets:to_list(sets:from_list(lists:append(NewDo,FORWARD))),[[User]++Done],Owner,Type,Mesg,C+1)
                     end
            end;
        _ -> false
    end.

notify( User ) -> notice( User, [ { "uwatch test 测试", "2", "1" } ] ).
%% User = username, Mesg = [ {Msg1,Level1,Detail1},{Msg2,Level2,Detail12} ... ],
%% Msg1 string, Level = "0"/"1"/"2", Detail1 = "0"/"1"
notice( User, Mesg ) ->
    UserInfo = watch_user:getinfo(User),
    Method = watch_method:getmethod( User ),
    Token = watch_token:add(User),

    lists:map( 
        fun(X) ->
             case X of
                 {M,L,D} -> send( User, Token, UserInfo, M, Method, D, L );
                 _ -> false
             end
        end,
    Mesg ).


send( User, Token, UserInfo, Info, Method, Detail, Level ) ->
    inets:start(),
    ssl:start(),
    watch_log:debug( "user=~p~n",     [User]     ),
    watch_log:debug( "method=~p~n",   [Method]   ),
    watch_log:debug( "token=~p~n",    [Token]    ),
    watch_log:debug( "level=~p~n",    [Level]    ),
    watch_log:debug( "userinfo=~p~n", [UserInfo] ),
    watch_log:debug( "etail=~p~n",    [Detail]   ),
    watch_log:debug( "info=~p~n",     [Info]     ),
    MesgNotify = lists:concat(
        ["user=",     User,     "&method=", Method, "&token=", Token, "&level=", Level,
         "&userinfo=",UserInfo, "&detail=", Detail, "&info=",  Info]
    ),
    watch_log:info("notify send:~p~n", [MesgNotify]),
    case httpc:request(post,{"http://127.0.0.1:7788/watch_alarm",
      [],"application/x-www-form-urlencoded", MesgNotify },[],[]
      ) of
      {ok, {_,_,Body}}-> Body, Stat = "ok";
      {error, Reason}->watch_log:error("send fail cause ~p~n",[Reason]), Stat = "fail"
    end,
    notify_stored ! { string:join( [ User, Info, Stat ], ":" ) }.

setstat(User,Stat) -> watch_db:set_notify(User,Stat).
getstat(User)      -> case watch_db:get_notify(User) of [T] -> T; S -> S end.
liststat()         -> lists:map(fun(X) -> {N,S}=X, N++":"++S end, watch_db:list_notify()).
