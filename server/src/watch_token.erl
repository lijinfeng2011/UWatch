-module(watch_token).
-export([add/1,add/3,add/2,del/3,list/0,start/0,clean/0,search/1,random_token/0]).

start() -> spawn(fun() -> clean() end ).

add(USER) -> TOKEN = random_token(),add(TOKEN,USER),TOKEN.
add(TOKEN,USER) -> add(TOKEN,USER,900).
add(TOKEN,USER,TIME) -> watch_db:add_token(TOKEN,USER,TIME).
del(TOKEN,USER,TIME) -> watch_db:del_token(TOKEN,USER,TIME).

search(TOKEN) -> watch_db:search_token(TOKEN).

list() -> watch_db:list_token().

clean() ->
  NOW = watch_misc:seconds(),
  lists:map(
    fun(X) ->
      {TOKEN,USER,TIME} = X,
      case TIME < NOW of
          true ->  watch_token:del(TOKEN,USER,TIME);
          false -> false
      end
    end
  ,watch_db:list_token()
  ),
  timer:sleep(5000),
  clean().

random_token() -> watch_misc:random().
