-module(watch_detail).
-compile(export_all).

setstat(User,Stat) -> watch_db:set_detail(User,Stat).
getstat(User) -> case watch_db:get_detail(User) of [T] -> T; S -> S end.
liststat() -> lists:map( fun(X) -> {N,S} =X, N++":"++S end,watch_db:list_detail()).
