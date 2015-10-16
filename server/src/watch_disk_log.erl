-module(watch_disk_log).
-export([open/3,open/4,write/2,close/1,read_log/1]).

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

read(Fd) ->
    case wrap_log_reader:chunk(Fd) of
      {_, eof} -> [];
      {Fd1, Msg1}-> lists:append( [ Msg1, read(Fd1) ] );
      _ -> []
    end.

read_log( PATH ) ->
    case wrap_log_reader:open(PATH) of 
        { ok, Fd } -> List = read( Fd ), wrap_log_reader:close(Fd), {error,List};
        _ -> { error, [] }
    end.
