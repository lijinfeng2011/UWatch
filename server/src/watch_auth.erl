-module(watch_auth).
-export([check_ip/1]).

-define(CONFIG_ALLOW, "../allow_ip").

check_ip( IP ) ->
  case file:consult( ?CONFIG_ALLOW ) of
    { ok, IPLIST } ->
      lists:member(IP, IPLIST);
    { error } ->
      watch_log:error("load config fail.~n" ),
      false
  end.
