-module(watch_auth).
-export([check_ip/1]).

-define(CONFIG_ALLOW, "../allow_ip").

check_ip( IP ) ->
  case file:consult( ?CONFIG_ALLOW ) of
    { ok, IPLIST } ->
      lists:member(IP, IPLIST);
    { error } ->
      io:format("load config err.~n" ),
      false
  end.
