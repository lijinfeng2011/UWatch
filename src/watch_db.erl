-module(test_mnesia).
-compile(export_all).


-record(item,{id,plan}).

start() ->
    mnesia:start(),
    mnesia:wait_for_tables([item],20000).

init() ->
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia:create_table(item,[{attributes,record_info(fields,item)}]),
    mnesia:stop().

%%== 查询 =============================================================

do(Q) ->
    F = fun() -> qlc:e(Q) end,
    {atomic,Val} = mnesia:transaction(F),
    Val.

%% SELECT * FROM shop
%% 选取所有列
demo(select_shop) ->
    do(qlc:q([X || X <- mnesia:table(shop)]));

%% SELECT  item,quantity FROM shop
%% 选取指定列
demo(select_some) ->
    do(qlc:q([{X#shop.item, X#shop.quantity} || X <- mnesia:table(shop)]));

%% SELECT * FROM shop WHERE shop.quantity < 250
%% 选取指定条件的数据
demo(where) ->
    do(qlc:q([X || X <- mnesia:table(shop),
                X#shop.quantity < 250
            ]));

%% 关联查询
%% SELECT shop.* FROM shop,cost wHERE shop.item = cost.name AND cost.price < 2 AND shop.quantity < 250
demo(join) ->
    do(qlc:q([X || X <- mnesia:table(shop),
                   X#shop.quantity < 250,
                   Y <- mnesia:table(cost),
                   X#shop.item =:= Y#cost.name,
                   Y#cost.price < 2
            ])).

%% == 数据操作 ===============================================

%% 增加一行
add_shop_item(Name,Quantity,Cost) ->
    Row = #shop{item = Name,quantity = Quantity, cost = Cost},
    F = fun() ->
            mnesia:write(Row)
    end,
    mnesia:transaction(F).

%% 删除一行
remove_shop_item(Item) ->
    Oid = {shop,Item},
    F = fun() ->
            mnesia:delete(Oid)
    end,
    mnesia:transaction(F).

%% 取消一个事务
former(Nwant) ->
    F = fun() ->
            %% find the num of apples
            [Apple] = mnesia:read({shop,apple}),
            Napples = Apple#shop.quantity,
            %% update the database
            NewApple = Apple#shop{quantity = Napples + 2 * Nwant},
            mnesia:write(NewApple),
            %% find the num of oranges
            [Orange] = mnesia:read({shop,orange}),
            Noranges = Orange#shop.quantity,
            if 
                Noranges >= Nwant ->
                    %% update the database
                    Num = Noranges - Nwant,
                    NewOrange = Orange#shop{quantity = Num},
                    mnesia:write(NewOrange);
                true ->
                    %% no enough oranges 取消事务
                    mnesia:abort(oranges)
            end
    end,
    mnesia:transaction(F).

%% 保存复杂数据
add_plans() ->
    D1 = #design{
        id = {joe,1},
        plan = {circle,10}
    },
    D2 = #design{
        id = fred,
        plan = {rectangle,[10,5]}
    },
    F = fun() ->
            mnesia:write(D1),
            mnesia:write(D2)
    end,
    mnesia:transaction(F).

%% 获复杂数据
get_plans(PlanId) ->
    F = fun() -> mnesia:read({design,PlanId}) end,
    mnesia:transaction(F).
