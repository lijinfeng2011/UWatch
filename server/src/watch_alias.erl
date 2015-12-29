-module(watch_alias).
-compile(export_all).

addalias(Item,Aname) -> watch_db:add_alias(Item,Aname).
getalias(Item) -> case watch_db:get_alias(Item) of [ M ] -> M; _ -> "" end.

delalias(Item) -> watch_db:del_alias(Item).
listalias() -> lists:map(fun(X)->{Item, Aname} = X, Item++":"++Aname end,watch_db:list_alias()).
