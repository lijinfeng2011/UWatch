-module(watch_db).
-compile(export_all).

-include_lib("stdlib/include/qlc.hrl").

-record(item,{name,index}).
-record(user,{name,passwd,info}).
-record(relate,{item,user}).
-record(follow,{owner,follower}).

start() ->
    mnesia:start(),
    mnesia:wait_for_tables([item,user,relate],20000).

init() ->
    NodeList = [node()],
    io:format("~p~n", NodeList ),
    mnesia:create_schema(NodeList),
    mnesia:start(),
    mnesia:create_table(item,[{attributes,record_info(fields,item)},{disc_copies, NodeList} ]),
    mnesia:create_table(user,[{attributes,record_info(fields,user)},{disc_copies, NodeList} ]),
    mnesia:create_table(relate,[{attributes,record_info(fields,relate)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(follow,[{attributes,record_info(fields,follow)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:stop().

%% do =============================================================

do(Q) ->
    F = fun() -> qlc:e(Q) end,
    {atomic,Val} = mnesia:transaction(F),
    Val.

%% item ===================================================
get_item() ->
    do(qlc:q([X || X <- mnesia:table(item)])).

get_item(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(item), X#item.name == Name ])),
    case lists:flatlength(List) == 1 of
      true -> [{_,_,I}] = List, I;
      false -> 0
    end.

set_item(Name,Index) ->
    Row = #item{name = Name,index = Index},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

list_item() ->
    do(qlc:q([X#item.name || X <- mnesia:table(item)])).

%% user =====================================================
set_user(Name,Passwd,Info) ->
    Row = #user{name = Name,passwd = Passwd, info = Info},
    F = fun() ->
            mnesia:write(Row)
    end,
    mnesia:transaction(F).

set_user_passwd(Name,Passwd) ->
    List = get_user(Name),
    case lists:flatlength(List) == 1 of
         true -> [{_,N,_,I}] = List, set_user(N,Passwd,I);
         false -> { error }
    end.

set_user_info(Name,Info) ->
    List = get_user(Name),
    case lists:flatlength(List) == 1 of
         true -> [{_,N,P,_}] = List, set_user(N,P,Info);
         false -> { error }
    end.

get_user() ->
    do(qlc:q([X || X <- mnesia:table(user)])).

get_user(NAME) ->
    do(qlc:q([X || X <- mnesia:table(user), X#user.name == NAME ])).

get_user_info(NAME) ->
    do(qlc:q([ X#user.info || X <- mnesia:table(user), X#user.name == NAME ])).

list_user() ->
    do(qlc:q([X#user.name || X <- mnesia:table(user)])).

%% relate  ====================================================
add_relate(Item,User) ->
    Row = #relate{item = Item,user = User},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).
del_relate(Item,User) ->
    F = fun() -> mnesia:delete_object( #relate{ item = Item, user = User } ) end,
    mnesia:transaction(F).

list_relate() ->
    do(qlc:q([X || X <- mnesia:table(relate)])).

%%follow =======================================================
add_follow(Owner,Follower) ->
    Row = #follow{owner = Owner,follower = Follower},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).
del_follow(Owner,Follower) ->
    F = fun() -> mnesia:delete_object( #follow{ owner = Owner,follower = Follower } ) end,
    mnesia:transaction(F).
list_follow() ->
    do(qlc:q([X || X <- mnesia:table(follow)])).
