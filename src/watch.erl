-module(watch).
-export([start/1]).

start(Port) ->
  watch_item:start(),
  watch_user:start(),
  watch_relate:start(),
  watch_waiter:start(Port),
  watch_mesg:start(),
  watch_stat:start().

