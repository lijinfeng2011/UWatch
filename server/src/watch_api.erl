-module(watch_api).
-export([call/1]).

call(List) -> 
    L = api(List),
    case length(L) > 0 of
        true -> string:join(L,"\n");
        false -> ""
    end.    

api(List) ->
  case List of
    ["relate","add",ITEM,USER] -> lists:foreach( fun(X) -> watch_relate:add(X,USER) end,string:tokens( ITEM, ":" ) ), ["ok"];
    ["relate","del",ITEM,USER] -> lists:foreach( fun(X) -> watch_relate:del(X,USER) end,string:tokens( ITEM, ":" ) ),["ok"];
    ["relate","list"] -> lists:map( fun(X) -> string:join(tuple_to_list(X),":") end,watch_relate:list());
    ["relate","list4user",USER]  ->  watch_relate:list4user(USER);
    ["relate","list4userdetail",USER]  ->  watch_relate:list4userdetail(USER);

    ["item","add",ITEM]     -> watch_item:add(ITEM), ["ok"];
    ["item","del",ITEM]     -> watch_item:del(ITEM), ["ok"];
    ["item","list"]         -> watch_item:list();
    ["item","listprefix"]         -> watch_item:listprefix();
    ["item","listsuffix",NAME]         -> watch_item:listsuffix(NAME);
    ["item","mesg",ITEM]    ->  watch_item:disk_log(ITEM, "mesg" );
    ["item","count",ITEM]   ->  watch_item:disk_log(ITEM, "count" );

    ["user","add",USER,PASS]     -> watch_user:add(USER, PASS ), ["ok"];
    ["user","del", USER]         -> watch_user:del(USER), ["ok"];
    ["user","list"]              -> watch_user:list();
    ["user","listinfo"]              -> watch_user:list_info();
    ["user","settable",TABLE]              -> watch_user:set_table(TABLE);
    ["user","listtable"]              -> watch_user:list_table();
    ["user","mesg",USER,ITEM]    -> watch_user:mesg(USER,ITEM);
    ["user","mesg",USER,ITEM,From,Type, Limit]    ->  watch_user:mesg(USER,ITEM,From, Type, Limit);
    ["user","getinfo",USER]      ->  [ watch_user:getinfo(USER) ];
    ["user","setinfo",USER,INFO] -> watch_user:setinfo(USER,INFO),  ["ok"];
    ["user","getindex",USER,ITEM]->  [integer_to_list( watch_user:getindex(USER,ITEM)) ];
    ["user","setindex",USER,ITEM,ID]  -> watch_user:setindex(USER,ITEM,list_to_integer(ID)),["ok"];
    ["user","auth",USER,PASS]         -> [watch_user:auth(USER,PASS)];
    ["user","changepwd",USER,OLD,NEW] -> [watch_user:changepwd(USER,OLD,NEW)];
    ["user","changepwd",USER,NEW] -> [watch_user:changepwd(USER,NEW)];


    ["follow","add",Owner,Follower] ->lists:foreach(fun(X) -> watch_follow:add(X,Follower) end,string:tokens( Owner, ":" )), ["ok"];
    ["follow","del",Owner,Follower] ->lists:foreach(fun(X) -> watch_follow:del(X,Follower) end,string:tokens( Owner, ":" )), ["ok"];
    ["follow","update",Owner,Follower] -> watch_follow:update(Owner, Follower), ["ok"];
    ["follow","del4user",Owner] -> watch_follow:del4user(Owner), ["ok"];
    ["follow","list"] ->  watch_follow:list();
    ["follow","list4user",USER] ->  watch_follow:list(USER);

    ["stat","list"] ->  watch_stat:list();
    ["last","list"] ->  watch_last:list();

    ["filter","add",USER,NAME,CONT] ->  
        lists:foreach( fun(X) -> watch_filter:add(NAME,X,USER,3600) end,string:tokens( CONT, ":" ) ),["ok"];
    ["filter","add",USER,TIME,NAME,CONT] -> 
        T = list_to_integer(TIME),
        lists:foreach( fun(X) -> watch_filter:add(NAME,X,USER,T) end,string:tokens( CONT, ":" ) ),["ok"];
    ["filter","del",NAME,CONT] -> lists:foreach( fun(X) -> watch_filter:del(NAME,X) end,string:tokens( CONT, ":" ) ),["ok"];
    ["filter","list"] ->lists:map( fun(X) -> {N,C} = X, N++ ":" ++ C end,watch_filter:list());
    ["filter","list4name",NAME]  -> watch_filter:list4name(NAME);
    ["filter","table"] -> lists:map( fun(X) -> {N,C,U,T} = X,string:join([N,C,U,integer_to_list(T)],":") end,watch_filter:table());
    ["token","search",TOKEN] -> [ watch_token:search(TOKEN) ];
    ["token","list"] -> lists:map( fun(X) -> {Token,U,T} = X, string:join([Token,U,integer_to_list(T)],":") end,watch_token:list());

    ["notify","setstat",USER,STAT] -> watch_notify:setstat(USER,STAT),  ["ok"];
    ["notify","getstat",USER] -> [ watch_notify:getstat(USER) ];
    ["notify","liststat"] ->  watch_notify:liststat();
    ["notify","test",USER] ->  watch_notify:notify( USER ), ["ok"];

    ["detail","setstat",USER,STAT] -> watch_detail:setstat(USER,STAT),  ["ok"];
    ["detail","getstat",USER] -> [ watch_detail:getstat(USER) ];
    ["detail","liststat"] ->  watch_detail:liststat();

    ["admin","add",USER] -> watch_admin:addadmin(USER),  ["ok"];
    ["admin","del",USER] -> watch_admin:deladmin(USER),  ["ok"];
    ["admin","get",USER] -> [ watch_admin:getadmin(USER) ];
    ["admin","list"] -> watch_admin:listadmin();

    ["broken","add",USER] -> watch_broken:addbroken(USER),  ["ok"];
    ["broken","del",USER] -> watch_broken:delbroken(USER),  ["ok"];
    ["broken","list"] -> watch_broken:listbroken();

    ["method","add",USER,METHOD] -> watch_method:addmethod(USER,METHOD),  ["ok"];
    ["method","del",USER] -> watch_method:delmethod(USER),  ["ok"];
    ["method","get",USER] -> [ watch_method:getmethod(USER) ];
    ["method","list"] -> watch_method:listmethod();

    ["notifylevel","set",ITEM,LEVEL] -> watch_notify_level:set_s(ITEM,LEVEL),  ["ok"];
    ["notifylevel","get",ITEM] -> [ watch_notify_level:get_s(ITEM) ];
    ["notifylevel","del",ITEM] -> watch_notify_level:del(ITEM), ["ok"];
    ["notifylevel","list"] -> watch_notify_level:list();

    ["alias","add",ITEM,ANAME] -> watch_alias:addalias(ITEM,ANAME), ["ok"];
    ["alias","del",ITEM] -> watch_alias:delalias(ITEM), ["ok"];
    ["alias","get",ITEM] -> [ watch_alias:getalias(ITEM) ];
    ["alias","list"] -> watch_alias:listalias();

    ["cronos","add",NAME] -> watch_cronos:add(NAME), ["ok"];
    ["cronos","del",NAME] -> watch_cronos:del(NAME), ["ok"];
    ["cronos","set","start",NAME,START] -> watch_cronos:setstart( NAME,START), ["ok"];
    ["cronos","set","keep",NAME,KEEP] -> watch_cronos:setkeep( NAME,KEEP), ["ok"];
    ["cronos","set","u1",NAME,U1] -> watch_cronos:setu1( NAME,U1), ["ok"];
    ["cronos","set","u2",NAME,U2] -> watch_cronos:setu2( NAME,U2), ["ok"];
    ["cronos","set","u3",NAME,U3] -> watch_cronos:setu3( NAME,U3), ["ok"];
    ["cronos","set","u4",NAME,U4] -> watch_cronos:setu4( NAME,U4), ["ok"];
    ["cronos","set","u5",NAME,U5] -> watch_cronos:setu5( NAME,U5), ["ok"];
    ["cronos","get","cal",NAME] -> watch_cronos:getcal(NAME);
    ["cronos","get","now",NAME] -> watch_cronos:getnow(NAME);
    ["cronos","list"] -> watch_cronos:list();
    ["cronos","show",NAME] -> watch_cronos:show(NAME);
    ["cronos","period",START,END] -> watch_cronos:getPeriod(START,END);

    ["cronos_notice","list"] -> watch_cronos_notice:list();

    ["data","record",ITEM, DATA] -> watch_accept_data:record( ITEM,DATA ),["ok"];
    ["data","input",ITEM, DATA] -> watch_accept_data:input( ITEM,DATA ),["ok"];

    ["data","record",ITEM, NODE, DATA] -> watch_accept_data:record( ITEM,NODE,DATA ),["ok"];
    ["data","input",ITEM, NODE, DATA] -> watch_accept_data:input( ITEM,NODE,DATA ),["ok"];

    _ -> [ "undefined"] 
  end.
