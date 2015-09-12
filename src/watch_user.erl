-module(watch_user).
-export([start/0,add/2,del/1,list/0,auth/2,setindex/3,getindex/2,mesg/2]).

-define(USER_PATH, "../data/user/").

start() ->

  spawn( fun() -> refresh() end ).


add( USER, PASS ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
  case length( L2 ) > 0 of
    true -> true;
    false -> dets:insert(watch_dets, {user, USER, PASS })
  end.

del( USER ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {_,U,_} = X,U == USER end, L1),
  lists:foreach( fun(X) -> dets:delete_object(watch_dets, X) end, L2).

list() ->
  lists:map( fun(X) -> {_,U,_} = X, U end, dets:lookup( watch_dets, user )).

auth( USER, PASS ) ->
  L1 = dets:lookup( watch_dets, user ),
  L2 = lists:filter(fun(X) -> {user,USER,PASS} =:= X end, L1),
  case length( L2 ) > 0 of
    true -> "ok";
    false -> "fail"
  end.

setindex( USER, ITEM, VALUE ) ->
  User = list_to_atom( "user_index_ets_" ++ USER ),
  io:format( "set index ~p~p~p~n", [USER, ITEM, VALUE]),
  case dets:open_file( User,[{file, ?USER_PATH ++ USER ++"/index.dets" },{type,set},{auto_save,10}]) of
    {ok,_} -> dets:insert(User, {ITEM, VALUE });
    _ -> ok
  end.

%% get the item index from user
getindex( USER, ITEM ) ->
  User = list_to_atom( "user_index_ets_" ++ USER ),
  case dets:open_file( User,[{file, ?USER_PATH ++ USER ++"/index.dets" },{type,set},{auto_save,10}]) of
    { ok, _ } ->
      case catch dets:lookup( User,ITEM ) of
        { 'EXIT',_ } ->0;
        [{ITEM,V}] -> V;
        _ -> 0
      end;
    _ -> 0
  end.

mesg( USER, ITEM ) ->
  ID = getindex( USER,ITEM ),
  io:format( "iiidddd~p~n", [ID]),
  lists:map( 
    fun(X) ->
       case re:split(X,"[*]",[{return,list}]) of
         [[],Index|_] ->
           case catch list_to_integer(Index) of
             {'EXIT',_} -> "0" ++ X;
             I ->
               if 
                 I > ID -> setindex( USER,ITEM, I ), "1" ++ X;
                 true -> "0" ++ X
               end
           end;
         _ -> "0" ++ X
       end
    end,
  watch_item:disk_log( ITEM, "mesg" )).

refresh() ->
  lists:map(
      fun(X) -> {user,U,_} = X,
         USER = list_to_atom( "user_list#"++ U ),
         case whereis( USER ) =:= undefined of
           true ->
             file:make_dir( ?USER_PATH ++ U ),
             Pid = spawn(fun() -> stored(U,queue:new(),61) end),
             io:format("new ~p~n",[USER]),
             register( USER, Pid );
           false -> false
         end
      end,
      dets:lookup( watch_dets, user )
  ),
  timer:sleep( 60000 ),
  refresh().


stored( NAME, Queue, TIME ) ->
  receive
    { ITEM, Data } -> 
       io:format("user ~p get data ~p~n",[NAME, ITEM, Data]),
       TmpQueue = queue:in( { ITEM, Data }, Queue ),
       {_,M,_} = time(),
       case M == TIME of
           false -> 
             Mesg = binary_to_list(list_to_binary(queue:to_list( TmpQueue ))),
        try
            mesg_manager ! { "mesg", NAME, Mesg }
        catch
            error:badarg -> io:fwrite( "user:~p send:~p to mesg_manager fail~n", [ NAME, Mesg ] )
        end,
 
             NewTIME = M, NewQueue = queue:new();
           true -> NewTIME = TIME, NewQueue = TmpQueue
       end;
     true -> NewTIME = TIME, NewQueue = Queue
  after 3000 ->
    {_,M,_} = time(),
    case M == TIME of
      false ->
        Mesg = string:join(queue:to_list( Queue ), "#-cut-#" ),
        try
            mesg_manager ! { "mesg", NAME, Mesg }
        catch
            error:badarg -> io:fwrite( "user:~p send:~p to mesg_manager fail~n", [ NAME, Mesg ] )
        end,
 
        NewTIME = M, NewQueue = queue:new();
      true ->
          NewTIME = TIME, NewQueue = Queue
    end
  end,
  stored( NAME, NewQueue, NewTIME ).
