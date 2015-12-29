-module(watch_log).
-compile(export_all).

level(default)   -> 3;

level(debug)   -> 4;
level(info)    -> 3;
level(warn)    -> 2;
level(error)   -> 1;
level(none)    -> 0.

debug(Fmt)         -> log(default, debug,    Fmt).
debug(Fmt, Args)   -> log(default, debug,    Fmt, Args).
info(Fmt)          -> log(default, info,    Fmt).
info(Fmt, Args)    -> log(default, info,    Fmt, Args).
warn(Fmt)          -> log(default, warn, Fmt).
warn(Fmt, Args)    -> log(default, warn, Fmt, Args).
error(Fmt)         -> log(default, error,   Fmt).
error(Fmt, Args)   -> log(default, error,   Fmt, Args).

log(Category, Level, Fmt) -> log(Category, Level, Fmt, []).
log(Category, Level, Fmt, Args) when is_list(Args) ->
    case level(Level) =< level(Category) of
        false -> ok;
        true  ->   io:format( "[" ++ string:to_upper( atom_to_list(Level) ) ++ "] " ++ Fmt, Args )
    end.
