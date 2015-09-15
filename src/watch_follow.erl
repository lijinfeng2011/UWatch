-module(watch_follow).
-export([add/2,del/2,list/0,list/1]).

add(Owner,Follower) -> watch_db:add_follow(Owner,Follower).
del(Owner,Follower) -> watch_db:del_follow(Owner,Follower).


list() -> lists:map( fun(X) -> {I,U} = X, I++ ":" ++ U end, watch_db:list_follow()).
list(Follower) -> watch_db:list_follow(Follower).
