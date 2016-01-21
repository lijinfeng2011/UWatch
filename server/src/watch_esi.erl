-module(watch_esi).
-export([start/0,data_record/2,data_record/1]).

start() ->
    inets:start(),
    inets:start(httpd, [{port, 9998},{bind_address, {127,0,0,1}}, {server_name, "localhost"}, {document_root, "/tmp/"}, {modules,[mod_esi]},{server_root, "/tmp/"}, {erl_script_alias, {"/esi", [watch_esi, io]}}]).

data_record(_ENV,Input) ->
    data_record(Input).
data_record(Input) ->
    Data = httpd:parse_query(Input),
    case Data of
       [{"item",Item},{"node",Node}|MESG] ->
           M = lists:filter( fun(X) -> {A,_} = X, A == "mesg" end, MESG ),
           case length(M) > 0 of 
               true ->
                   Stat = lists:map
                   (
                       fun(X) ->
                           {"mesg",Mesg} = X,
                           watch_accept_data:record( Item,Node,Mesg )
                       end, M
                   ),
                   case lists:member("fail",Stat) of
                       true -> "fail";
                       false -> "ok"
                   end;
               false -> "false"
           end;
       _ -> "fail"
end.
