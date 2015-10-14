-module(watch_filter).
-export([add/2,del/2,list/0,list4name/1]).

add(NAME,CONT) -> watch_db:add_filter(NAME,CONT).
del(NAME,CONT) -> watch_db:del_filter(NAME, CONT).

list() -> watch_db:list_filter().

list4name(NAME) -> watch_db:list_filter( NAME ).
%  L = watch_filter:list(NAME),
%  List = lists:map(
%    fun(X) ->
%       lists:map( fun(XX) -> XX end,watch_db:list_filter(X))
%    end,
%    lists:append([L,[NAME]])
%  ),
%  sets:to_list(sets:from_list(lists:append(List))).
