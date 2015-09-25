-module(watch_notify).
-compile(export_all).

notify( User, AlarmList ) ->
    inets:start(),
    ssl:start(),
    Info = string:join( AlarmList, "@" ),
    case httpc:request(post,{"http://127.0.0.1:7788/watch_alarm",
      [],"application/x-www-form-urlencoded", lists:concat(["user=" ,User ,"&info=",Info])},[],[]) of
    {ok, {_,_,Body}}-> Body;  
    {error, Reason}->io:format("error cause ~p~n",[Reason])
end.

