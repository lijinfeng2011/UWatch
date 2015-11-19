-module(watch_accept_data).
-export([record/2,input/2]).

record(Item,Data) ->
  {{Y,M,D},{H,Mi,S}} = calendar:local_time(),
  TIME = lists:concat( [ Y,"-",M,"-",D,"-",H,":",Mi, ":", S ] ),
  input(Item, TIME ++ " " ++ Data ).

input(Item,Data) ->
    NAME = list_to_atom( "item_list#"++ Item ),
    try
       NAME ! { "data", Data }
    catch
       error:badarg -> io:format( "[ERROR] input to item ~p fail.", [Item] )
    end.

