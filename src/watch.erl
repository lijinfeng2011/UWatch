-module(watch).
-export([start/1]).

start(Port) ->
  watch_item:start(),
  watch_user:start(),
  watch_relate:start(),
  watch_mesg:start(),
  watch_waiter:start(Port).

