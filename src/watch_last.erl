-module(watch_last).
-export([list/0]).


list() -> 
  lists:map(
    fun(X) -> {Name,Time} = X, Name ++ ":" ++ integer_to_list(Time) end, 
    watch_db:list_last()
  ).
