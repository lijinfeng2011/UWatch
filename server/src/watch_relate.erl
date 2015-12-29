-module(watch_relate).
-export([add/2,del/2,list/0,list4user/1,list4userdetail/1,list4user_itemnameonly/1]).

add( ITEM, USER ) ->
  watch_db:add_relate(ITEM, USER),
  watch_item:add(ITEM),
  PubIndex = watch_item:getindex(ITEM),
  watch_user:setindex4notify( USER, ITEM, PubIndex ),
  watch_user:setindex( USER, ITEM, PubIndex ).

del( ITEM, USER ) -> watch_db:del_relate(ITEM, USER).

list() -> watch_db:list_relate().

list4user(USER) ->
  Self = lists:map( fun(XX) -> {"myself_"++USER,XX}end,watch_db:list_relate(USER)),
  Follow = lists:append( lists:map(
    fun(X) ->
       lists:map( fun(XX) -> {"myself_"++USER,XX}end,watch_db:list_relate(X))
    end,
    watch_follow:list(USER)
  )),

  Myself = sets:to_list(sets:from_list( lists:append([Self,Follow]) )),
  
  Oncall = lists:append(lists:map(
      fun(X) ->
          {Level,U} = X,
          lists:map( fun(XX) -> {"oncall_"++Level++"_"++U,XX}end,watch_db:list_relate(U))
      end,
  watch_cronos_notice:get_oncall(USER))),  %% [ { "u1", "cronos_base" }, { "", cronos_search } ]
 
  lists:map(
    fun(X) -> 
        {Owner,Item} = X,
        PubIndex = watch_item:getindex(Item),
        PriIndex = watch_user:getindex(USER,Item),
        Owner ++ ":" ++ Item ++ ":" ++ integer_to_list( PubIndex - PriIndex )
    end, 
    lists:append([Myself,Oncall])
  ).

list4userdetail(USER) ->
  Self = lists:map( fun(XX) -> {"myself_"++USER,XX}end,watch_db:list_relate(USER)),
  Follow = lists:append( lists:map(
    fun(X) ->
       lists:map( fun(XX) -> {"follow_"++X,XX}end,watch_db:list_relate(X))
    end,
    watch_follow:list(USER)
  )),

  Oncall = lists:append(lists:map(
      fun(X) ->
          {Level,U} = X,
          lists:map( fun(XX) -> {"oncall_"++Level++"_"++U,XX}end,watch_db:list_relate(U))
      end,
  watch_cronos_notice:get_oncall(USER))),  %% [ { "u1", "cronos_base" }, { "", cronos_search } ]
 
  lists:map(
    fun(X) -> 
        {Owner,Item} = X,
        PubIndex = watch_item:getindex(Item),
        PriIndex = watch_user:getindex(USER,Item),
        Owner ++ ":" ++ Item ++ ":" ++ integer_to_list( PubIndex - PriIndex )
    end, 
    lists:append([Self,Follow,Oncall])
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
