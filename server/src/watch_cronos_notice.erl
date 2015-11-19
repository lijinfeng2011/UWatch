-module(watch_cronos_notice).
-compile(export_all).


write_to_db( Name,AllUser,CronosList ) -> watch_db:cronos_notice_store( Name,AllUser,CronosList ).
list() ->
    lists:map( fun(X) -> {A,B,C} = X, A++":"++B++":"++C end,watch_db:list_cronos_notice()).

get_oncall(USER) -> %% [ { "u1", "cronos_base" }, { "", cronos_search } ]
    watch_db:get_cronos_user_oncall(USER). %% [{level,cronos},{level,cronos2}]
