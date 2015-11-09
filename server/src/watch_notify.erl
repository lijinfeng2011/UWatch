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
          case watch_disk_log:open( ?NOTIFY_PATH, ?NOTIFY_DATA_SIZE, ?NOTIFY_DATA_COUNT) of

            {ok, NotifyLog} -> 
               Pid = spawn(  fun() -> stored( NotifyLog ) end ),
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
      disk_log:log( Log, TIME ++ ":" ++ Data )
  end,
  stored(Log).

notify( User, AlarmList ) ->
    UserInfo = watch_user:getinfo(User),
    Method = watch_method:getmethod( User ),
    Token = watch_token:add(User),
    case watch_detail:getstat( User ) of
        [ "on" ] -> 
            lists:map(
                fun(X) ->
                    PubIndex = watch_item:getindex(X),
                    PriIndex = watch_user:getindex(User,X),
                    COUNT = PubIndex - PriIndex,
                    case COUNT > 0 of
                        true ->
                            ItemCountInfo = X ++ "@@@"++ watch_db:get_stat(X) ++"@@@"++ integer_to_list( COUNT ),
                            Info = string:join( [ ItemCountInfo|watch_user:mesg(User,X,"curr", "head", "all")], "@@@" ),
                            send( User, Token, UserInfo, Info, Method, "1", watch_notify_level:get_s(X) );
                        false -> false
                    end
                end,
            AlarmList);
        _ ->
            AlarmList2 = lists:map( 
                fun(X) -> 
                    PubIndex = watch_item:getindex(X),
                    PriIndex = watch_user:getindex(User,X),
                    Count = PubIndex - PriIndex,
                    { X ++ ":"++ watch_db:get_stat(X) ++":"++ integer_to_list( Count ), Count }
                end, 
            AlarmList),

            NotifyItem = lists:filter( fun(X) -> {_,C} = X, C > 0 end, AlarmList2 ),
            AlarmList3 = lists:map( fun(X) -> {N,_} = X, N end, NotifyItem),
            case length( AlarmList3 ) > 0 of
                true -> 
                    Info = string:join( AlarmList3, "@@@" ),
                    MaxLevel =  watch_notify_level:get_max_s( NotifyItem ),
                    send( User, Token, UserInfo, Info, Method, "0", MaxLevel );
                false -> false
            end
    end.

notify( User ) ->
    UserInfo = watch_user:getinfo(User),
    Method = watch_method:getmethod( User ),
    Token = watch_token:add(User),
    io:format( "[INFO] test notify for: ~p~n", [User] ),
    case watch_detail:getstat( User ) of
        [ "on" ] -> Stat = "1";
        _ -> Stat = "0"
    end,
    send( User, Token, UserInfo, "uwatch test 测试", Method, Stat, "2" ).

send( User, Token, UserInfo, Info, Method, Detail, Level ) ->
    inets:start(),
    ssl:start(),
    MesgNotify = lists:concat(
        ["user=" ,User ,"&method=",Method,"&token=",Token, "&level=",Level,
         "&userinfo=",UserInfo, "&detail=", Detail,"&info=",Info]
    ),
    io:format("[INFO] notify send:~p~n", [MesgNotify]),
    case httpc:request(post,{"http://127.0.0.1:7788/watch_alarm",
      [],"application/x-www-form-urlencoded", MesgNotify },[],[]
      ) of
      {ok, {_,_,Body}}-> Body, Stat = "ok";
      {error, Reason}->io:format("[ERROR] send fail cause ~p~n",[Reason]), Stat = "fail"
    end,
    notify_stored ! { User ++ ":" ++ Info ++ ":" ++ Stat }.

setstat(User,Stat) -> watch_db:set_notify(User,Stat).
getstat(User) -> watch_db:get_notify(User).
liststat() -> lists:map( fun(X) -> {N,S} =X, N++":"++S end, watch_db:list_notify()).
