-module(watch_stat).
-export([list/0]).


list() -> 
  lists:map(
    fun(X) -> {Name,Stat} = X, Name ++ ":" ++ Stat end, 
    watch_db:list_stat()
  ).
