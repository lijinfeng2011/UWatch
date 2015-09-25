-module(watch_misc).
-compile(export_all).

milliseconds() ->
 {MegaSecs, Secs, MicroSecs} = erlang:now(),
 1000000000 * MegaSecs + Secs * 1000 + MicroSecs div 1000.
