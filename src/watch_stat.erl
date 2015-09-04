-module(watch_stat).
-compile(export_all).
 
-export([start/0]).

 
start() ->
    start(8888).
start(Port) ->
    N = erlang:system_info(schedulers),
    listen(Port, N),
    io:format("httpd ready with ~b schedulers on port ~b~n", [N, Port]),
 
    register(?MODULE, self()),
    receive Any -> io:format("~p~n", [Any]) end.  %% to stop: ehttpd!stop.
 
listen(Port, N) ->
    Opts = [{active, false},
            binary,
            {backlog, 256},
            {packet, http_bin},
            {raw,6,9,<<1:32/native>>}, %defer accept
            %%{delay_send,true},
            %%{nodelay,true},
            {reuseaddr, true}],
 
    {ok, S} = gen_tcp:listen(Port, Opts),
    Spawn = fun(I) ->   
                    register(list_to_atom("acceptor_" ++ integer_to_list(I)),
                             spawn_opt(?MODULE, accept, [S, I], [link, {scheduler, I}]))
            end,
    lists:foreach(Spawn, lists:seq(1, N)).
 
accept(S, I) ->
    case gen_tcp:accept(S) of
        {ok, Socket} -> spawn_opt(?MODULE, loop, [Socket], [{scheduler, I}]);
        Error    -> erlang:error(Error)
    end,
    accept(S, I).
 
loop(S) ->

    Data =  "nodata!",

    Len = integer_to_list(length(Data)),
    case gen_tcp:recv(S, 0) of
        {ok, http_eoh} ->
            Response = list_to_binary( 
                "HTTP/1.1 200 OK\r\nContent-Length: "++ Len  ++"\r\n\r\n" ++Data
            ),
            gen_tcp:send(S, Response),
            gen_tcp:close(S),
            ok;
 
        {ok, _Data} ->
            loop(S);
 
        Error ->
            Error
    end.

