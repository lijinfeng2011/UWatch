-module(test_mnesia).
-compile(export_all).

-include_lib("stdlib/include/qlc.hrl").

%% 定义记录结构
-record(shop,{item,quantity,cost}).
-record(cost,{name,price}).
-record(design,{id,plan}).

start() ->
    mnesia:start(),
    %% 等待表的加载
    mnesia:wait_for_tables([shop,cost,design],20000).

%% 初始化mnesia表结构
init() ->
    mnesia:create_schema([node()]),
    mnesia:start(),
    %% 表创建 mnesia:create_talbe(TableName,[Args])
    %% {type,Type}  set,ordered_set,bag 表类型
    %% {ram_copies,NodeList} NodeList每个节点都有内存备份　默认为这个{ram_copies,[node()]}
    %% {disc_copies,NodeList} NodeList每个节点都有内存备份和磁盘备份 
    %% {disc_only_copies,NodeList} NodeList每个节点有磁盘备份 
    %% {attributes,AtomList} 要保存的列名称 一般和record有关　record_info(fields,RecordName)
    mnesia:create_table(shop,[{attributes,record_info(fields,shop)}]), %% 创建shop表
    mnesia:create_table(cost,[{attributes,record_info(fields,cost)}]),
    mnesia:create_table(design,[{attributes,record_info(fields,design)}]),
    mnesia:stop().

%% 加载测试数据
reset_tables() ->
    mnesia:clear_table(shop),
    mnesia:clear_table(cost),
    F = fun() ->
            lists:foreach(fun mnesia:write/1,example_tables())
    end,
    mnesia:transaction(F).


%% 测试数据
example_tables() ->
    [
        %% shop table
        {shop,apple,20,2.3},
        {shop,orange,100,3.8},
        {shop,pear,200,3.6},
        {shop,banana,420,4.5},
        {shop,potato,2456,1.2},
        %% cost table
        {cost,apple,1.5},
        {cost,orange,2.4},
        {cost,pear,2.2},
        {cost,banana,1.6},
        {cost,potato,0.6}
    ].

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
