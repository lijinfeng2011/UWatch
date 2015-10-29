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
    inets:start(),
    ssl:start(),
    [UserInfo] = watch_user:getinfo(User),
    Token = watch_token:add(User),
    case watch_detail:getstat( User ) of
        [ "on" ] -> 
            lists:map(
                fun(X) ->
                    PubIndex = watch_item:getindex(X),
                    PriIndex = watch_user:getindex(User,X),
                    ItemCountInfo = X ++ ":"++ watch_db:get_stat(X) ++":"++ integer_to_list( PubIndex - PriIndex ),
                Info = ItemCountInfo ++ string:join( watch_user:mesg(User,X,"curr", "head", "all"), ":" ),
                send( User, Token, UserInfo, Info, "1" )    
                end,
            AlarmList);
        _ ->
            AlarmList2 = lists:map( 
                fun(X) -> 
                    PubIndex = watch_item:getindex(X),
                    PriIndex = watch_user:getindex(User,X),
                    X ++ ":"++ watch_db:get_stat(X) ++":"++ integer_to_list( PubIndex - PriIndex ) 
                end, 
            AlarmList),
            Info = string:join( AlarmList2, "@" ),
            send( User, Token, UserInfo, Info, "0" )
    end.

send( User, Token, UserInfo, Info, Detail ) ->
    MesgNotify = lists:concat(
        ["user=" ,User ,"&token=",Token,"&userinfo=",UserInfo, "&detail", Detail,"&info=",Info]
    ),
    io:format("notify:~p~n", [MesgNotify]),
    case httpc:request(post,{"http://127.0.0.1:7788/watch_alarm",
      [],"application/x-www-form-urlencoded", MesgNotify },[],[]
      ) of
      {ok, {_,_,Body}}-> Body, Stat = "ok";
      {error, Reason}->io:format("error cause ~p~n",[Reason]), Stat = "fail"
    end,
    notify_stored ! { User ++ ":" ++ Info ++ ":" ++ Stat }.

setstat(User,Stat) -> watch_db:set_notify(User,Stat).
getstat(User) -> watch_db:get_notify(User).
liststat() -> lists:map( fun(X) -> {N,S} =X, N++":"++S end,watch_db:list_notify()).
