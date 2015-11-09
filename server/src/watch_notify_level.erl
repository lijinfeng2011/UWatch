-module(watch_notify_level).
-compile(export_all).

set_i(Item,Level) -> watch_db:set_notify_level(Item,Level).
get_i(Item) ->
    case watch_db:get_notify_level(Item) of
        [ M ] -> M;
        _ -> 2
    end.

del(Item) -> watch_db:del_notify_level(Item).

list() -> lists:map( fun(X) -> {I,L} =X, I++":"++ integer_to_list(L) end,watch_db:list_notify_level()).

set_s(Item,Level) -> set_i(Item,list_to_integer(Level)).
get_s(Item) -> integer_to_list(get_i(Item)).

get_max_i( ItemList ) ->
    lists:max( lists:map( fun(X) -> get_i(X) end,ItemList )).
get_max_s( ItemList ) -> integer_to_list( get_max_i( ItemList ) ).
