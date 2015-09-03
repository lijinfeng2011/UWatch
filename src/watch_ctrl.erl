-module(watch_ctrl).
-export([handle/1]).


handle(Socket) ->
  case gen_tcp:recv(Socket, 0) of
    {ok, Data} ->
      CTRL = string:tokens( Data, "#" ),
      case length(CTRL) of
        2 ->
            case list_to_tuple( CTRL ) of 
              { "relate", "list" } ->
                relate_manager ! {"list", Socket };
              Other -> io:format( "commaaaaaaaaaand undef~n" )
            end;
 
        3 ->
            case list_to_tuple( CTRL ) of 
              { "datalist", "add", CNAME } ->
                item_manager ! {"add", CNAME };
              Other -> io:format( "command undef~n" )
            end;
        4 ->
            case list_to_tuple( CTRL ) of 
              { "relate", "del", CNAME, CUSER } ->
                relate_manager ! {"del", CNAME, CUSER };
              { "relate", "add", CNAME, CUSER } ->
                relate_manager ! {"add", CNAME, CUSER };
              Other -> io:format( "command undef~n" )
            end;
        Etrue -> io:format( "error command~n" )
      end,
      handle( Socket );
    {error, closed} ->
      gen_tcp:close( Socket )
  end.


