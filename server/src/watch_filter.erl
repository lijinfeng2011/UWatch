-module(watch_filter).
-export([add/4,del/2,del/4,list/0,list4name/1,table/0,start/0,clean/0]).

start() -> spawn(fun() -> clean() end ).

add(NAME,CONT,USER,TIME) -> del(NAME,CONT),watch_db:add_filter(NAME,CONT,USER,TIME).
del(NAME,CONT,USER,TIME) -> watch_db:del_filter(NAME,CONT,USER,TIME).

del(Name,Cont) ->
  lists:map(
    fun(X) ->
      case X of
        {Name,Cont,USER,TIME} -> watch_filter:del(Name,Cont,USER,TIME);
        _ -> false
      end
    end
  ,table()).

list() -> watch_db:list_filter().

list4name(NAME) -> watch_db:list_filter( NAME ).

table() -> watch_db:list_filter_table().

clean() ->
  NOW = watch_misc:seconds(),
  lists:map(
    fun(X) ->
      {NAME,CONT,USER,TIME} = X,
      case TIME < NOW of
          true ->  watch_filter:del(NAME,CONT,USER,TIME);
          false -> false
      end
    end
  ,table()
  ),
  timer:sleep(5000),
  clean().
