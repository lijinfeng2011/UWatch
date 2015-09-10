-module(watch_disk_log).
-export([open/4, test/0]).

-define(NICE(Reason),lists:flatten(atom_to_list(?MODULE)++": "++Reason)).

open(Filename, MaxBytes, MaxFiles) ->
    Opts = [{format, internal}, {repair, true}],
    open1(Filename, MaxBytes, MaxFiles, Opts).
    
open(Filename, MaxBytes, MaxFiles, truncate) ->
    Opts = [{format, internal}, {repair, truncate}],
    open1(Filename, MaxBytes, MaxFiles, Opts).

open1(Filename, MaxBytes, MaxFiles, Opts0) ->
    Opts1 = [{name, Filename}, {file, Filename}, {type, wrap}] ++ Opts0,
    case open2(Opts1, {MaxBytes, MaxFiles}) of
        {ok, LogDB} ->
            {ok, LogDB};
        {error, Reason} ->
            {error, 
             ?NICE("Can't create " ++ Filename ++ 
                   lists:flatten(io_lib:format(", ~p",[Reason])))};
        _ ->
            {error, ?NICE("Can't create "++Filename)}
    end.

open2(Opts, Size) ->
    case disk_log:open(Opts) of
        {error, {badarg, size}} ->
            %% File did not exist, add the size option and try again
            disk_log:open([{size, Size} | Opts]);
        Else ->
            Else
    end.

write(Log, Entry) ->
    disk_log:log(Log, Entry).

close(Log) ->
    disk_log:close(Log).

