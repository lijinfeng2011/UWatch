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
    AlarmList2 = lists:map( 
        fun(X) -> 
            PubIndex = watch_item:getindex(X),
            PriIndex = watch_user:getindex(User,X),
            X ++ ":"++ watch_db:get_stat(X) ++":"++ integer_to_list( PubIndex - PriIndex ) 
        end, 
    AlarmList),
    Info = string:join( AlarmList2, "@" ),
    case httpc:request(post,{"http://127.0.0.1:7788/watch_alarm",
      [],"application/x-www-form-urlencoded", lists:concat(["user=" ,User ,"&info=",Info])},[],[]) of
    {ok, {_,_,Body}}-> Body, Stat = "ok";  
    {error, Reason}->io:format("error cause ~p~n",[Reason]), Stat = "fail"
    end,
    notify_stored ! { User ++ ":" ++ Info ++ ":" ++ Stat }.

