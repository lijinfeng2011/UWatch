-module(watch_db).
-compile(export_all).

-include_lib("stdlib/include/qlc.hrl").

-record(item,{name,index}).
-record(user,{name,passwd,info}).
-record(relate,{item,user}).
-record(follow,{owner,follower}).
-record(userindex,{name,index}).
-record(userindex4notify,{name,index}).
-record(stat,{name,stat}). %% item 的状态 1/1/_
-record(last,{name,time}). %% item 最后出现错误的时间 和user最后处理的错误时间
-record(alarm,{name,seed,main}). 
-record(filter,{name,cont,user,time}). 
-record(token,{token,user,time}). 
-record(notify,{name,stat}). 
-record(detail3,{name,stat}). 
-record(admin,{name,stat}). 
-record(broken,{name,stat}). 
-record(method,{user,value}). 
-record(notify_level,{item,level}). 
-record(remark,{item,aname}). 
-record(cronos,{name,start=0,keep=0,u1={},u2={},u3={},u4={},u5={}}). 

start() ->
    mnesia:start(),
    mnesia:wait_for_tables(
        [item,user,relate,follow,userindex,userindex4notify,stat,last,alarm,filter,token,notify,detail3,admin,broken,method,notify_level,remark,cronos]
    ,20000).

init() ->
    NodeList = [node()],
    io:format("[INFO] mnesia Node ~p~n", NodeList ),
    mnesia:create_schema(NodeList),
    mnesia:start(),
    mnesia:create_table(item,[{attributes,record_info(fields,item)},{disc_copies, NodeList} ]),
    mnesia:create_table(user,[{attributes,record_info(fields,user)},{disc_copies, NodeList} ]),
    mnesia:create_table(relate,[{attributes,record_info(fields,relate)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(follow,[{attributes,record_info(fields,follow)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(userindex,[{attributes,record_info(fields,userindex)},{disc_copies, NodeList} ]),
    mnesia:create_table(userindex4notify,[{attributes,record_info(fields,userindex4notify)},{disc_copies, NodeList} ]),
    mnesia:create_table(stat,[{attributes,record_info(fields,stat)},{disc_copies, NodeList} ]),
    mnesia:create_table(last,[{attributes,record_info(fields,last)},{disc_copies, NodeList} ]),
    mnesia:create_table(alarm,[{attributes,record_info(fields,alarm)},{disc_copies, NodeList} ]),
    mnesia:create_table(filter,[{attributes,record_info(fields,filter)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(token,[{attributes,record_info(fields,token)},{disc_copies, NodeList} ]),
    mnesia:create_table(notify,[{attributes,record_info(fields,notify)},{disc_copies, NodeList} ]),
    mnesia:create_table(detail3,[{attributes,record_info(fields,detail3)},{disc_copies, NodeList} ]),
    mnesia:create_table(admin,[{attributes,record_info(fields,admin)},{disc_copies, NodeList},{type,bag} ]),
    mnesia:create_table(broken,[{attributes,record_info(fields,broken)},{disc_copies, NodeList} ]),

    mnesia:create_table(method,[{attributes,record_info(fields,method)},{disc_copies, NodeList} ]),
    mnesia:create_table(notify_level,[{attributes,record_info(fields,notify_level)},{disc_copies, NodeList} ]),
    mnesia:create_table(remark,[{attributes,record_info(fields,remark)},{disc_copies, NodeList} ]),
    mnesia:create_table(cronos,[{attributes,record_info(fields,cronos)},{disc_copies, NodeList} ]),

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
list_user_info() ->
    do(qlc:q([{X#user.name,X#user.info} || X <- mnesia:table(user)])).

list_user_table() ->
    do(qlc:q([{X#user.name,X#user.passwd,X#user.info} || X <- mnesia:table(user)])).


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

del4user_follow(Owner) ->
    F = fun() -> mnesia:delete({follow, Owner}) end,
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

%% userindex4notify ===================================================
get_userindex4notify(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(userindex4notify), X#userindex4notify.name == Name ])),
    case length(List) == 1 of
      true -> [{_,_,I}] = List, I;
      false -> 0
    end.

set_userindex4notify(Name,Index) ->
    F = fun() -> mnesia:write( #userindex4notify{name = Name,index = Index} ) end,
    mnesia:transaction(F).

%% stat ========================================================
get_stat(Name) ->
    List = do(qlc:q([X || X <- mnesia:table(stat), X#item.name == Name ])),
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


%% filter ======================================================
add_filter(Name,Cont,User,Time) ->
    T = Time + watch_misc:seconds(),
    Row = #filter{name = Name,cont = Cont,user = User, time = T},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).
del_filter(Name,Cont,User,Time) ->
    F = fun() -> mnesia:delete_object( #filter{ name = Name, cont = Cont,user = User, time = Time } ) end,
    mnesia:transaction(F).

list_filter() ->
    do(qlc:q([{X#filter.name, X#filter.cont} || X <- mnesia:table(filter)])).

list_filter(Name) ->
    do(qlc:q([X#filter.cont || X <- mnesia:table(filter), X#filter.name == Name])).

list_filter_table() ->
    do(qlc:q([{X#filter.name, X#filter.cont, X#filter.user, X#filter.time } || X <- mnesia:table(filter)])).

%% token ======================================================
add_token(Token,User,Time) ->
    T = Time + watch_misc:seconds(),
    Row = #token{token = Token,user = User, time = T},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).
del_token(Token,User,Time) ->
    F = fun() -> mnesia:delete_object( #token{ token = Token, user = User, time = Time } ) end,
    mnesia:transaction(F).

list_token() ->
    do(qlc:q([{X#token.token, X#token.user,X#token.time} || X <- mnesia:table(token)])).

search_token(Token) ->
    do(qlc:q([ X#token.user || X <- mnesia:table(token), X#token.token == Token ])).

%% notify ======================================================
set_notify(Name,Stat) ->
    Row = #notify{name = Name,stat = Stat},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

get_notify(NAME) ->
    do(qlc:q([ X#notify.stat || X <- mnesia:table(notify), X#notify.name == NAME ])).


list_notify() ->
    do(qlc:q([{X#notify.name, X#notify.stat} || X <- mnesia:table(notify)])).

%% detail ======================================================
set_detail(Name,Stat) ->
    Row = #detail3{name = Name,stat = Stat},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

get_detail(NAME) ->
    do(qlc:q([ X#detail3.stat || X <- mnesia:table(detail3), X#detail3.name == NAME ])).


list_detail() ->
    do(qlc:q([{X#detail3.name, X#detail3.stat} || X <- mnesia:table(detail3)])).


%% admin ======================================================
add_admin(Name) ->
    Row = #admin{name = Name,stat = 1 },
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_admin(Name) ->
    F = fun() -> mnesia:delete_object( #admin{ name = Name,stat = 1 } ) end,
    mnesia:transaction(F).

get_admin(NAME) ->
    do(qlc:q([ X#admin.name || X <- mnesia:table(admin), X#admin.name == NAME ])).

list_admin() ->
    lists:map( fun(X) -> {N} = X, N end, do(qlc:q([{X#admin.name} || X <- mnesia:table(admin)]) )).


%% broken ======================================================
add_broken(Name) ->
    Row = #broken{name = Name,stat = 1 },
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_broken(Name) ->
    F = fun() -> mnesia:delete_object( #broken{ name = Name,stat = 1 } ) end,
    mnesia:transaction(F).

list_broken() ->
    lists:map( fun(X) -> {N} = X, N end, do(qlc:q([{X#broken.name} || X <- mnesia:table(broken)]) )).

%% method ========================================================
get_method(User) ->
    do(qlc:q([ X#method.value || X <- mnesia:table(method), X#method.user == User ])).

add_method(User,Value) ->
    Row = #method{user = User,value = Value},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_method(User) ->
    F = fun() -> mnesia:delete({method,User}) end,
    mnesia:transaction(F).

list_method() ->
    do(qlc:q([{X#method.user,X#method.value} || X <- mnesia:table(method)])).

%% notify_level ========================================================
get_notify_level(Item) ->
    do(qlc:q([ X#notify_level.level || X <- mnesia:table(notify_level), X#notify_level.item == Item ])).

set_notify_level(Item,Level) ->
    Row = #notify_level{item = Item,level = Level},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_notify_level(Item) ->
    F = fun() -> mnesia:delete({notify_level,Item}) end,
    mnesia:transaction(F).

list_notify_level() ->
    do(qlc:q([{X#notify_level.item,X#notify_level.level} || X <- mnesia:table(notify_level)])).

%% alias ========================================================
add_alias(Item,Aname) ->
    Row = #remark{item = Item,aname = Aname},
    F = fun() -> mnesia:write(Row) end,
    mnesia:transaction(F).

del_alias(Item) ->
    F = fun() -> mnesia:delete({remark,Item}) end,
    mnesia:transaction(F).

get_alias(Item) ->
    do(qlc:q([ X#remark.aname || X <- mnesia:table(remark), X#remark.item == Item ])).

list_alias() ->
    do(qlc:q([{X#remark.item,X#remark.aname} || X <- mnesia:table(remark)])).

%% cronos ========================================================
add_cronos(Name) ->
    F = fun() -> mnesia:write( #cronos{ name = Name} ) end,
    mnesia:transaction(F).

del_cronos(Name) ->
    F = fun() -> mnesia:delete({cronos,Name}) end,
    mnesia:transaction(F).

set_cronos_start(Name,Start) ->
    case get_cronos( Name ) of
        [{Name,_,Keep,U1,U2,U3,U4,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = list_to_integer(Start),
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.
set_cronos_keep(Name,Keep) ->
    case get_cronos( Name ) of
        [{Name,Start,_,U1,U2,U3,U4,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = list_to_integer(Keep), u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.

set_cronos_u1(Name,U1) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,_,U2,U3,U4,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.
set_cronos_u2(Name,U2) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,U1,_,U3,U4,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.
set_cronos_u3(Name,U3) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,U1,U2,_,U4,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.
  
  
set_cronos_u4(Name,U4) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,U1,U2,U3,_,U5}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.

set_cronos_u5(Name,U5) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,U1,U2,U3,U4,_}|_] -> 
                   NewRow = #cronos{ name=Name,start = Start,
                                     keep = Keep, u1=U1,u2=U2,u3=U3,u4=U4,u5=U5},
                   mnesia:transaction( fun() -> mnesia:write(NewRow) end) ;
        _ -> false
    end.
  
 
    
list_cronos() ->
    do(qlc:q([X#cronos.name || X <- mnesia:table(cronos)])).

get_cronos( Name ) ->
    do(qlc:q([
        { X#cronos.name, X#cronos.start, X#cronos.keep,
          X#cronos.u1, X#cronos.u2, X#cronos.u3, X#cronos.u4, X#cronos.u5
        } || X <- mnesia:table(cronos), X#cronos.name == Name ])).
show_cronos( Name ) ->
    case get_cronos( Name ) of
        [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->

               [ "name=" ++ Name,
                 "start=" ++  integer_to_list( Start ),
                 "keep=" ++  integer_to_list( Keep ) ,
                 "u1=" ++ get_user_info_cronos( U1 ),
                 "u2=" ++ get_user_info_cronos( U2 ),
                 "u3=" ++ get_user_info_cronos( U3 ),
                 "u4=" ++ get_user_info_cronos( U4 ),
                 "u5=" ++ get_user_info_cronos( U5 )
               ];
        _ -> []
    end.

get_user_info_cronos( U ) ->
    case U of
        {C,L} -> string:join( [ integer_to_list(C)|L], ":" );
        _ -> ""
    end.
