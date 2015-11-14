-module(watch_cronos).
-compile(export_all).

start() -> 
  spawn( fun() -> mon() end ).

add( Name ) -> watch_db:add_cronos( Name ).
show( Name ) -> watch_db:show_cronos( Name ).
setstart( Name,Start ) -> watch_db:set_cronos_start( Name,Start).
setkeep( Name,Keep ) -> watch_db:set_cronos_keep( Name,Keep).

setu1( Name,U1 ) -> 
    case string:tokens( U1, ":" ) of
        [C|L] -> watch_db:set_cronos_u1(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu2( Name,U2 ) -> 
    case string:tokens( U2, ":" ) of
        [C|L] -> watch_db:set_cronos_u2(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu3( Name,U3 ) -> 
    case string:tokens( U3, ":" ) of
        [C|L] -> watch_db:set_cronos_u3(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu4( Name,U4 ) -> 
    case string:tokens( U4, ":" ) of
        [C|L] -> watch_db:set_cronos_u4(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu5( Name,U5 ) -> 
    case string:tokens( U5, ":" ) of
        [C|L] -> watch_db:set_cronos_u5(Name,{list_to_integer(C),L});
        _ -> false
    end.


getcal(Name) ->
    case watch_db:get_cronos(Name) of
        [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->
            getcal(Start,Keep,U1,"u1") ++
            getcal(Start,Keep,U2,"u2") ++
            getcal(Start,Keep,U3,"u3") ++
            getcal(Start,Keep,U4,"u4") ++
            getcal(Start,Keep,U5,"u5");
        _ -> []
    end.

getcal(Start,Keep,User,Mark) -> 
    case User of
        {_,List} -> getcal(Start,Keep,List,Mark,0,999,[]);
        _ -> []
    end.

getcal(Start,Keep,List,Mark,Index,Count,R) ->
    case Index > Count of
        true -> R;
        false ->
           Id = Index rem length(List),
           RR = R ++ [ integer_to_list( Start+Keep*Index )++":" ++Mark ++":" ++ lists:nth(Id+1,List)],
           getcal(Start,Keep,List,Mark,Index+1,Count,RR)
    end.

getnow(Name) ->
    Time = watch_misc:seconds(),
    case watch_db:get_cronos(Name) of
        [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->
            getnow(Time,Start,Keep,U1,"u1") ++
            getnow(Time,Start,Keep,U2,"u2") ++
            getnow(Time,Start,Keep,U3,"u3") ++
            getnow(Time,Start,Keep,U4,"u4") ++
            getnow(Time,Start,Keep,U5,"u5");
        _ -> []
    end.

getnow(Time,Start,Keep,User,Mark) -> 
    case User of
        {_,L} -> [ Mark ++":"++ search_user_from_u(Start,Keep,L,Time) ];
        _ -> []
    end.

list() -> watch_db:list_cronos().

mon() ->
    lists:map( 
        fun(X) -> 
            CRONOS = list_to_atom( "cronos#"++ X ),
            case whereis( CRONOS ) =:= undefined of
                true -> 
                    Pid = spawn(fun() -> stored(X,queue:new()) end),
                    register( CRONOS, Pid );
                false -> false
            end
        end,
    list()),
    timer:sleep( 5000 ),
    mon().

stored(Name,Q) ->
    receive 
        { notify, List } ->
            case queue:len( Q ) > 100 of
                true -> {_,TmpQ} = queue:out(Q), NewQ = queue:in( length(List), TmpQ);
                false -> NewQ = queue:in( length(List), Q)
            end,
            UserList = search_user(Name,NewQ),
            io:format("[INFO] cronos ~p: ~p~n", [Name,UserList]),

            lists:map( 
                 fun(X) -> 

                     UserStored = list_to_atom( "user_list#" ++X),
                     try
                         UserStored ! { notify, List }
                     catch
                         error:badarg -> io:format( "[ERROR]cronos notify user ~p fail.~n", [X] )
                     end
                 end
            ,UserList )

    end,
    timer:sleep( 5000 ),
    stored(Name,Q).
%

search_user(Name,Q) ->
    sets:to_list(sets:from_list( search_user_list(Name,Q) )).
search_user_list(Name,Q) ->
    Time = watch_misc:seconds(),
    case watch_db:get_cronos(Name) of
        [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->
            search_user_from_u(Q,Start,Keep,U1,Time) ++
            search_user_from_u(Q,Start,Keep,U2,Time) ++
            search_user_from_u(Q,Start,Keep,U3,Time) ++
            search_user_from_u(Q,Start,Keep,U4,Time) ++
            search_user_from_u(Q,Start,Keep,U5,Time);
        _ -> []
    end.


search_user_from_u(Q,Start,Keep,U,Time) ->
    case U of
        {C,L} ->
            case cronos_alarm(Q,C) of
                true -> 
                    [ search_user_from_u(Start,Keep,L,Time) ];
                false -> []
            end;
        _ -> []
    end.

search_user_from_u(Start,Keep,List,Time) ->
    ID = ( trunc( ( Time - Start ) div Keep) rem length(List) ) +1,
    io:format("cronos time:~p start:~p keep:~p len:~p~n", [ integer_to_list(Time), integer_to_list(Start),integer_to_list(Keep), integer_to_list(length(List)) ]),
    io:format( "cronos id:~p~n", [integer_to_list(ID)]),
    lists:nth(ID,List).
    

cronos_alarm(Q,Count) ->
  case queue_count(Q,Count) of
    error -> false;
    VV -> VV * 2 > Count
  end.

queue_count(Q,Count) -> queue_count(Q,Count,0).
queue_count(Q,Count,E) ->
  case queue:out(Q) of
    {{value,V},Q2} ->
        case V > 0 of
           true -> VV = 1;
           false -> VV = 0
        end,
        case Count == 1 of
            true -> VV+E;
            false -> queue_count(Q2,Count-1,E+VV)
        end;
    _ -> error
  end.
