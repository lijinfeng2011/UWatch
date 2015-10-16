-module(watch_relate).
-export([add/2,del/2,list/0,list4user/1,list4user_itemnameonly/1]).

add( ITEM, USER ) ->
  watch_db:add_relate(ITEM, USER),
  watch_item:add(ITEM).

del( ITEM, USER ) -> watch_db:del_relate(ITEM, USER).

list() -> watch_db:list_relate().

list4user(USER) ->
  L = watch_follow:list(USER),
  List = lists:map(
    fun(X) ->
       lists:map( fun(XX) -> {X,XX}end,watch_db:list_relate(X))
    end,
    lists:append([L,[USER]])
  ),
 
  lists:map(
    fun(X) -> 
        {Owner,Item} = X,
        PubIndex = watch_item:getindex(Item),
        PriIndex = watch_user:getindex(USER,Item),
        Owner ++ ":" ++ Item ++ ":" ++ integer_to_list( PubIndex - PriIndex )
    end, 
    lists:append(List)
  ).

list4user_itemnameonly(USER) ->
  L = watch_follow:list(USER),
  List = lists:map(
    fun(X) ->
       lists:map( fun(XX) -> XX end,watch_db:list_relate(X))
    end,
    lists:append([L,[USER]])
  ),
  sets:to_list(sets:from_list(lists:append(List))).
