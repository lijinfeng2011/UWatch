-module(watch_api).
-export([call/1]).

call(List) -> string:join(api(List),"\n").

api(List) ->
  case List of
    ["relate","add",ITEM,USER] -> lists:foreach( fun(X) -> watch_relate:add(X,USER) end,string:tokens( ITEM, ":" ) ), ["ok"];
    ["relate","del",ITEM,USER] -> lists:foreach( fun(X) -> watch_relate:del(X,USER) end,string:tokens( ITEM, ":" ) ),["ok"];
    ["relate","list"] -> lists:map( fun(X) -> {I,U} = X, I++ ":" ++ U end,watch_relate:list());
    ["relate","list4user",USER]  ->  watch_relate:list4user(USER);

    ["item","add",ITEM]     -> watch_item:add(ITEM), ["ok"];
    ["item","del",ITEM]     -> watch_item:del(ITEM), ["ok"];
    ["item","list"]         -> watch_item:list();
    ["item","mesg",ITEM]    ->  watch_item:disk_log(ITEM, "mesg" );
    ["item","count",ITEM]   ->  watch_item:disk_log(ITEM, "count" );

    ["user","add",USER,PASS]     -> watch_user:add(USER, PASS ), ["ok"];
    ["user","del", USER]         -> watch_user:del(USER), ["ok"];
    ["user","list"]              -> watch_user:list();
    ["user","mesg",USER,ITEM]    -> watch_user:mesg(USER,ITEM);
    ["user","mesg",USER,ITEM,From,Type, Limit]    ->  watch_user:mesg(USER,ITEM,From, Type, Limit);
    ["user","getinfo",USER]      ->  [ watch_user:getinfo(USER) ];
    ["user","setinfo",USER,INFO] -> watch_user:setinfo(USER,INFO),  ["ok"];
    ["user","getindex",USER,ITEM]->  [integer_to_list( watch_user:getindex(USER,ITEM)) ];
    ["user","setindex",USER,ITEM,ID]  -> watch_user:setindex(USER,ITEM,list_to_integer(ID)),["ok"];
    ["user","auth",USER,PASS]         -> [watch_user:auth(USER,PASS)];
    ["user","changepwd",USER,OLD,NEW] -> [watch_user:changepwd(USER,OLD,NEW)];


    ["follow","add",Owner,Follower] ->lists:foreach(fun(X) -> watch_follow:add(X,Follower) end,string:tokens( Owner, ":" )), ["ok"];
    ["follow","del",Owner,Follower] ->lists:foreach(fun(X) -> watch_follow:del(X,Follower) end,string:tokens( Owner, ":" )), ["ok"];
    ["follow","update",Owner,Follower] -> watch_follow:update(Owner, Follower), ["ok"];
    ["follow","del4user",Owner] -> watch_follow:del4user(Owner), ["ok"];
    ["follow","list"] ->  watch_follow:list();
    ["follow","list4user",USER] ->  watch_follow:list(USER),["ok"];

    ["stat","list"] ->  watch_stat:list();
    ["last","list"] ->  watch_last:list();

    ["filter","add",USER,TIME,NAME,CONT] -> 
        T = list_to_integer(TIME),
        lists:foreach( fun(X) -> watch_filter:add(NAME,X,USER,T) end,string:tokens( CONT, ":" ) ),["ok"];
    ["filter","del",NAME,CONT] -> lists:foreach( fun(X) -> watch_filter:del(NAME,X) end,string:tokens( CONT, ":" ) ),["ok"];
    ["filter","list"] ->lists:map( fun(X) -> {N,C} = X, N++ ":" ++ C end,watch_filter:list());
    ["filter","list4name",NAME]  -> watch_filter:list4name(NAME);
    ["filter","table"] -> lists:map( fun(X) -> {N,C,U,T} = X, N++ ":" ++ C++":"++U++":"++integer_to_list(T) end,watch_filter:table());
    ["token","search",TOKEN] -> [ watch_token:search(TOKEN) ];
    ["token","list"] -> lists:map( fun(X) -> {Token,U,T} = X, Token++ ":" ++ U ++":"++integer_to_list(T) end,watch_token:list());
    _ -> [ "undefined"] 
  end.
