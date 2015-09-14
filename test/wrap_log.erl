-module(wrap_log).
-export([open/4, test/0]).

-define(NICE(Reason),lists:flatten(atom_to_list(?MODULE)++": "++Reason)).

%%----------------------------------------------------------------------
%% Function:    open/4
%% Description: Open a disk log file.
%% Control which format the disk log will be in. The external file 
%% format is used as default since that format was used by older 
%% implementations of inets.
%%
%% When the internal disk log format is used, we will do some extra 
%% controls. If the files are valid, try to repair them and if 
%% thats not possible, truncate.
%%----------------------------------------------------------------------

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

%%----------------------------------------------------------------------
%% Actually writes the entry to the disk_log. If the log is an 
%% internal disk_log write it with log otherwise with blog.
%%----------------------------------------------------------------------  
write(Log, Entry) ->
    disk_log:log(Log, Entry).

%% Close the log file
close(Log) ->
    disk_log:close(Log).

test_write() ->
	{ok, Fd} = open("test.log", 256, 3),
	ok = write(Fd, "haha"),
	ok = write(Fd, "good"),
	ok = write(Fd, "erlang"),
	ok = write(Fd, "----"),
	close(Fd).
	
do_test_read(Fd, Count) ->
	case wrap_log_reader:chunk(Fd) of
	{Fd1, eof} ->
		{Fd1, Count};
	{Fd1, Msg1}->
		[io:format("~p~n", [X]) || X <- Msg1],
		do_test_read(Fd1, Count+length(Msg1));
	_ ->
		{Fd, error}
	end.
	
test_read() ->
	{ok, Fd} = wrap_log_reader:open("test.log"),
	{Fd2, Count} = do_test_read(Fd, 0),
	io:format("Size: ~p~n", [Count]),
	wrap_log_reader:close(Fd2).
	
test() ->
	test_write(),
	test_read().
