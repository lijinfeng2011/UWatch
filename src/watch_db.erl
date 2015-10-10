-module(watch_db).
-compile(export_all).

-include_lib("stdlib/include/qlc.hrl").

-record(item,{name,index}).
-record(user,{name,passwd,info}).
-record(relate,{item,user}).
-record(follow,{owner,follower}).
-record(userindex,{name,index}).
-record(stat,{name,stat}). %% item 的状态 1/1/_
-record(last,{name,time}). %% item 最后出现错误的时间 和user最后处理的错误时间
-record(alarm,{name,seed,main}). 

start() ->
    mnesia:start(),
    mnesia:wait_for_tables([item,user,relate,follow,userindex,stat,last,alarm],20000).

init() ->
    NodeList = [node()],
    io:format("~p~n", NodeList ),
    mnesia:create_schema(NodeList),
    mnesia:start(),
    mnesia:create_table(item,[{attributes,record_info(fields,item)},{disc_copies, NodeList} ]),
    mnesia:create_table(user,[{attributes,record_info(fields,user)},{disc_copies, NodeList} ]),
    mnesia:create_table(relate,[{attributes,record_info(fields,relate)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(follow,[{attributes,record_info(fields,follow)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(userindex,[{attributes,record_info(fields,userindex)},{disc_copies, NodeList} ]),
    mnesia:create_table(stat,[{attributes,record_info(fields,stat)},{disc_copies, NodeList} ]),
    mnesia:create_table(last,[{attributes,record_info(fields,last)},{disc_copies, NodeList} ]),
    mnesia:create_table(alarm,[{attributes,record_info(fields,alarm)},{disc_copies, NodeList} ]),
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

del_item(Name) ->
    F = fun() -> mnesia:delete({item,Name}) end,
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

get_user_passwd(NAME) ->
    do(qlc:q([ X#user.passwd || X <- mnesia:table(user), X#user.name == NAME ])).

del_user(Name) ->
    F = fun() -> mnesia:delete({user,Name}) end,
    mnesia:transaction(F).

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
    do(qlc:q([{X#relate.item, X#relate.user} || X <- mnesia:table(relate)])).

list_relate(User) ->
    do(qlc:q([X#relate.item || X <- mnesia:table(relate), X#relate.user == User])).


%%follow =======================================================
add_follow(Owner,Follower) ->
    Row = #follow{owner = Owner,follower = Follower},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_follow(Owner,Follower) ->
    F = fun() -> mnesia:delete_object( #follow{ owner = Owner,follower = Follower } ) end,
    mnesia:transaction(F).

update_follow(Owner,Follower) ->
    F = fun() ->
        mnesia:delete({follow, Owner}),
        Add = fun(Follow) -> mnesia:write( #follow{owner = Owner,follower = Follow} ) end,
        lists:foreach(Add, string:tokens(Follower, ":" ))
    end,
    mnesia:transaction(F).

list_follow() ->
    do(qlc:q([{X#follow.owner, X#follow.follower} || X <- mnesia:table(follow)])).

list_follow(USER) ->
    do(qlc:q([X#follow.follower || X <- mnesia:table(follow), X#follow.owner == USER])).


%% userindex ===================================================
get_userindex(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(userindex), X#userindex.name == Name ])),
    case length(List) == 1 of
      true -> [{_,_,I}] = List, I;
      false -> 0
    end.

set_userindex(Name,Index) ->
    F = fun() -> mnesia:write( #userindex{name = Name,index = Index} ) end,
    mnesia:transaction(F).

%% stat ========================================================
get_stat(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(item), X#item.name == Name ])),
    case length(List) == 1 of
      true -> [{_,_,I}] = List, I;
      false -> ""
    end.

set_stat(Name,Stat) ->
    Row = #stat{name = Name,stat = Stat},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

list_stat() ->
    do(qlc:q([ { X#stat.name, X#stat.stat } || X <- mnesia:table(stat)])).

%% last ========================================================
get_last(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(last), X#last.name == Name ])),
    case length(List) == 1 of
      true -> [{_,_,I}] = List, I;
      false -> 0
    end.

set_last(Name,Time) ->
    Row = #last{name = Name,time = Time},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

list_last() ->
    do(qlc:q([ { X#last.name, X#last.time } || X <- mnesia:table(last)])).


