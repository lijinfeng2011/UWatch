-module(watch_accept_data).
-export([record/2,input/2,record/3,input/3]).

record(Item,Node,Data) -> record(Item,Node ++"#" ++Data).
record(Item,Data) ->
  {{Y,M,D},{H,Mi,S}} = calendar:local_time(),
  TIME = lists:concat( [ Y,"-",M,"-",D," ",H,":",Mi, ":", S ] ),
  input(Item, TIME ++ " " ++ Data ).

input(Item,Node,Data) -> input(Item,Node ++"#" ++Data).
input(Item,Data) ->
    NAME = list_to_atom( "item_list#"++ Item ),
    try
       NAME ! { "data", Data }
    catch
       error:badarg -> watch_log:error( "input to item ~p fail.~n", [Item] )
    end.
