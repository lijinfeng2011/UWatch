-module(watch_cronos).
-compile(export_all).

start() -> 
  spawn( fun() -> mon() end ),
  spawn( fun() -> chk() end ).

add( Name ) -> watch_db:add_cronos( Name ).
del( Name ) -> watch_db:del_cronos( Name ).
show( Name ) -> watch_db:show_cronos( Name ).
setstart( Name,Start ) -> watch_db:set_cronos_start( Name,Start).
setkeep( Name,Keep ) -> watch_db:set_cronos_keep( Name,Keep).

setu1( Name,U1 ) -> 
    case string:tokens( U1, ":" ) of
        ["clear"] -> watch_db:set_cronos_u1(Name,{});
        [C|L] -> watch_db:set_cronos_u1(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu2( Name,U2 ) -> 
    case string:tokens( U2, ":" ) of
        ["clear"] -> watch_db:set_cronos_u2(Name,{});
        [C|L] -> watch_db:set_cronos_u2(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu3( Name,U3 ) -> 
    case string:tokens( U3, ":" ) of
        ["clear"] -> watch_db:set_cronos_u3(Name,{});
        [C|L] -> watch_db:set_cronos_u3(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu4( Name,U4 ) -> 
    case string:tokens( U4, ":" ) of
        ["clear"] -> watch_db:set_cronos_u4(Name,{});
        [C|L] -> watch_db:set_cronos_u4(Name,{list_to_integer(C),L});
        _ -> false
    end.
setu5( Name,U5 ) -> 
    case string:tokens( U5, ":" ) of
        ["clear"] -> watch_db:set_cronos_u5(Name,{});
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

getnow2(Time,Start,Keep,User,Mark) -> 
    case User of
        {_,L} -> { Mark, search_user_from_u(Start,Keep,L,Time) };
        _ -> {}
    end.

list() -> watch_db:list_cronos().

mon() ->
    lists:map( 
        fun(X) -> 
            CRONOS = list_to_atom( "cronos#"++ X ),
            case whereis( CRONOS ) =:= undefined of
                true -> 
                    Pid = spawn(fun() -> stored(X,queue:new(),[],[]) end),
                    register( CRONOS, Pid );
                false -> false
            end
        end,
    list()),
    timer:sleep( 5000 ),
    mon().

chk() ->
    Time = watch_misc:seconds(),
    lists:map( 
        fun(X) -> 
            CRONOS = list_to_atom( "cronos#"++ X ),
            case whereis( CRONOS ) =:= undefined of
                true -> true;
                false -> 
                  try
                    CRONOS ! { notice, Time }
                  catch
                    error:badarg -> io:format( "[ERROR]cronos chk notice user ~p fail.~n", [X] )
                  end
            end
        end,
    list()),
    timer:sleep( 120000 ),
    mon().

stored(Name,Q, AllUser, CronosList ) ->
    receive 
        { notify, List } ->
            case queue:len( Q ) > 100 of
                true -> {_,TmpQ} = queue:out(Q), NewQ = queue:in( List, TmpQ);
                false -> NewQ = queue:in( List, Q)
            end,
            UserList = search_user(Name,NewQ,List),
            io:format("[INFO] cronos L ~p: ~p~n", [Name,UserList]),
            io:format("[INFO] cronos Q ~p: ~p~n", [Name,queue:to_list(NewQ)]),

            lists:map( 
                 fun(X) -> 
                     {User,AlarmList} = X,
                     UserStored = list_to_atom( "user_list#" ++ User ),
                     try
                         UserStored ! { notify, AlarmList }
                     catch
                         error:badarg -> io:format( "[ERROR]cronos notify user ~p fail.~n", [X] )
                     end
                 end
            ,UserList ),
            NewAllUser = AllUser, NewCronosList = CronosList;
          
        { notice,Time } ->
            NewQ = Q,
            case watch_db:get_cronos(Name) of
                [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->
                   NewAllUser = lists:sort( sets:to_list(sets:from_list(
                       lists:concat( lists:map( fun(X) -> get_user(X) end, [ U1,U2,U3,U4,U5 ] ) )
                   ))),
                   NewCronosList = lists:filter( fun(X) -> X /= {} end , 
                    lists:map(
                       fun(X) -> 
                           {Mark,U} = X,
                           getnow2(Time,Start,Keep,U,Mark)
                       end,
                    [{"u1",U1}, {"u2",U2},{"u3",U3},{"u4",U4},{"u5",U5}] )),
                    io:format( "cronos XXXX:~p  ~p  ~p~n", [ Name, NewAllUser, NewCronosList ] ),

                    case {AllUser, CronosList} =:= { NewAllUser, NewCronosList } of
                       true -> true;
                       false ->
                           
                           watch_cronos_notice:write_to_db(Name,NewAllUser,NewCronosList),
                           CronosLevel = string:join( 
                               lists:map( fun(X) -> {M,U} = X, M++":"++ U end, NewCronosList )

                           , "@@@" ),
                           NoticeInfo = "Cronos:" ++ Name ++ "@@@" ++ CronosLevel,
                           lists:map( 
                               fun(X) -> 
                                   USER = list_to_atom( "user_list#" ++ X ),
                                   try 
                                       USER ! { notice, NoticeInfo },
                                       io:format( "[INFO] notice cronos to ~p => ~p~n", [Name, USER]  )
                                   catch
                                       error:badarg -> io:format( "[ERROR] notice cronos to ~p => ~p fail.~n", [Name, USER] )
                                   end
                               end, 
                           NewAllUser)
                   end;
                _ -> NewAllUser = AllUser, NewCronosList = CronosList
            end

    end,
    stored(Name,NewQ,NewAllUser, NewCronosList).

get_user( U ) ->
    case U of
        {_,L} -> L;
        _ -> []
    end.


search_user(Name,Q,AlarmList) ->
    sets:to_list(sets:from_list( search_user_list(Name,Q,AlarmList) )).
search_user_list(Name,Q,AlarmList) ->
    Time = watch_misc:seconds(),
    case watch_db:get_cronos(Name) of
        [{Name,Start,Keep,U1,U2,U3,U4,U5}|_] ->
            search_user_from_u(Q,Start,Keep,U1,Time,AlarmList) ++
            search_user_from_u(Q,Start,Keep,U2,Time,AlarmList) ++
            search_user_from_u(Q,Start,Keep,U3,Time,AlarmList) ++
            search_user_from_u(Q,Start,Keep,U4,Time,AlarmList) ++
            search_user_from_u(Q,Start,Keep,U5,Time,AlarmList);
        _ -> []
    end.

search_user_from_u(Q,Start,Keep,U,Time,AlarmList) ->
    case U of
        {C,L} ->
            List = cronos_alarm(Q,C,AlarmList),
            case length(List) > 0  of
                true -> 
                    [ { search_user_from_u(Start,Keep,L,Time), List} ];
                false -> []
            end;
        _ -> []
    end.

search_user_from_u(Start,Keep,List,Time) ->
    ID = ( trunc( ( Time - Start ) div Keep) rem length(List) ) +1,
    io:format( "cronos time:~p start:~p keep:~p len:~p~n",
        [ integer_to_list(Time), integer_to_list(Start),
          integer_to_list(Keep), integer_to_list(length(List))
        ]),
    io:format( "cronos id:~p~n", [integer_to_list(ID)]),
    lists:nth(ID,List).

cronos_alarm(Q,Count,AlarmList) ->
  THS = Count / 2,
  List = queue_out(Q,Count),

  lists:filter(
      fun(X) -> 
          MATCH = lists:filter( fun(XX) -> XX == X end, List),
          length( MATCH ) > THS
      end
  ,AlarmList).

queue_out(Q,Count) -> queue_out(Q,Count,[]).
queue_out(Q,Count,E) ->
  case queue:out(Q) of
    {{value,V},Q2} ->
        case Count == 1 of
            true  -> V++E;
            false -> queue_out(Q2,Count-1,E++V)
        end;
    _ -> E
  end.
