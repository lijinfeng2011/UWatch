-module(watch_detail).
-compile(export_all).

setstat(User,Stat) -> watch_db:set_detail(User,Stat).
getstat(User) -> watch_db:get_detail(User).
liststat() -> lists:map( fun(X) -> {N,S} =X, N++":"++S end,watch_db:list_detail()).
