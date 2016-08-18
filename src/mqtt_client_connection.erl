%%
%% Copyright (C) 2015-2016 by krasnop@bellsouth.net (Alexei Krasnopolski)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License. 
%%

%% @since 2015-12-25
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_connection.


-module(mqtt_client_connection).
-behaviour(gen_server).
%%
%% Include files
%%
-include("mqtt_client.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([	
	wait_pong/0
]).

-ifdef(TEST).
-export([	
	is_match/2
]).
-endif.

-import(mqtt_client_output, [packet/2]).
-import(mqtt_client_input, [input_parser/1]).

open_socket(Host, Port, _Options) ->
  case 
    try
      gen_tcp:connect(
        Host, 
        Port, 
        [
          binary, %% @todo check and add options from Argument _Options
          {active, true}, 
          {packet, 0}, 
          {recbuf, ?BUFFER_SIZE}, 
          {sndbuf, ?BUFFER_SIZE}, 
          {send_timeout, ?SEND_TIMEOUT}
        ], 
        ?CONN_TIMEOUT
      )
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, Socket} -> Socket;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="open_connection/1 [0]", message = Reason}
  end.  


%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, State}
			| {ok, State, Timeout}
			| {ok, State, hibernate}
			| {stop, Reason :: term()}
			| ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
init({Host, Port, Options}) ->
%	io:format(user, " >>> init connection ~p:~p ~p~n", [Host, Port, Options]),
	%% @todo check input parameters
	case R = open_socket(Host, Port, Options) of
		#mqtt_client_error{} -> {stop, R};
		_ -> {ok, #connection_state{socket = R}}
	end.

%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_call({connect, Conn_config}, {_, Ref} = From, State) ->
%	io:format(user, " >>> connect request ~p, ~p~n", [Conn_config, State]),
  case gen_tcp:send(State#connection_state.socket, packet(connect, Conn_config)) of
    ok -> 
			New_processes = (State#connection_state.processes)#{connect => {From, Conn_config}},
			{reply, {ok, Ref}, State#connection_state{processes = New_processes}};
    {error, Reason} -> {reply, {error, Reason}, State}
  end;

handle_call(status, _From, State) ->	
	{reply, [{session_present, State#connection_state.session_present}, {subscriptions, State#connection_state.subscriptions}], State};

handle_call({publish, #publish{qos = 0} = Params, Payload}, _From, State) ->
%	io:format(user, " >>> publish request ~p, ~p, ~p~n", [Params, Payload, State]),
	gen_tcp:send(State#connection_state.socket, packet(publish, {Params, Payload})),
	{reply, {ok}, State};

handle_call({publish, #publish{qos = QoS} = Params, Payload}, {_, Ref} = From, State) when (QoS =:= 1) orelse (QoS =:= 2) ->
%	io:format(user, " >>> publish request ~p, ~p, ~p~n", [Params, Payload, State]),
	Packet_Id = State#connection_state.packet_id,
	Packet = packet(publish, {Params, Payload, Packet_Id}),
%	io:format(user, " >>> [~p] publish packet ~p~n", [Params#publish.qos, Packet]),
	case gen_tcp:send(State#connection_state.socket, Packet) of
		ok -> 
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Params}},
		{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({subscribe, Subscriptions}, {_, Ref} = From, State) ->
%	io:format(user, " >>> subscribe request ~p, ~p, ~p, ~p~n", [Topic, QoS, Callback, State]),
	Packet_Id = State#connection_state.packet_id,
	case gen_tcp:send(State#connection_state.socket, packet(subscribe, {Subscriptions, Packet_Id})) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Subscriptions}},
			{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({unsubscribe, Topics}, {_, Ref} = From, State) ->
%	io:format(user, " >>> unsubscribe request ~p, ~p~n", [Topic, State]),
	Packet_Id = State#connection_state.packet_id,
	case gen_tcp:send(State#connection_state.socket, packet(unsubscribe, {Topics, Packet_Id})) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Topics}},
			{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({disconnect}, _From, State) ->
%	io:format(user, " >>> disconnect request ~p~n", [State]),
	case gen_tcp:send(State#connection_state.socket, packet(disconnect, false)) of
    ok -> {reply, ok, State};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({ping, Callback}, _From, State) ->
%	io:format(user, " >>> ping request ~p~n", [State]),
  case gen_tcp:send(State#connection_state.socket, packet(pingreq, false)) of
    ok ->
			Pid = spawn_link(?MODULE, wait_pong, []),
			New_processes = (State#connection_state.processes)#{ping => {Pid, Callback}},
			{reply, ok, State#connection_state{
																				processes = New_processes, 
																				ping_count = State#connection_state.ping_count + 1}
			};
    {error, Reason} -> {reply, {error, Reason}, State}
  end.

%% handle_cast/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
-spec handle_cast(Request :: term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_cast(_Msg, State) ->
    {noreply, State}.

%% handle_info/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_info(Info, State) ->
	Socket = State#connection_state.socket,
	case Info of
		{tcp, Socket, Binary} ->
			New_State = socket_stream_process(State,<<(State#connection_state.tail)/binary, Binary/binary>>),
			{noreply, New_State};
		{tcp_closed, Socket} ->
			io:format(user, " >>> handle_info tcp_closed for socket: ~p and PID: ~p.~nState:~p~n", [Socket, self(), State]),
			{stop, tcp_closed, State};
%			{noreply, State};
		_ ->
			io:format(user, " >>> handle_info unknown message: ~p state:~p~n", [Info, State]),
			{noreply, State}
	end.

	
%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(_Reason, _State) ->
		ok.

%% code_change/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(_OldVsn, State, _Extra) ->
		{ok, State}.

%% ====================================================================
%% Internal functions
%% ====================================================================

socket_stream_process(State, <<>>) -> 
%	io:format(user, " --<- socket_stream_process message: state:~p Bin: Empty~n", [State]),
	State;
socket_stream_process(State, Binary) ->
%	io:format(user, " ->-- socket_stream_process message: state:~p Bin: ~p~n", [State, Binary]),
	case input_parser(Binary) of
		{connectack, SP, Msg, Tail} ->
			case maps:get(connect, State#connection_state.processes, undefined) of
				{{Pid, Ref}, _Conn_Config} ->
					Pid ! {connectack, Ref, Msg},
					socket_stream_process(
						State#connection_state{processes = maps:remove(connect, State#connection_state.processes), 
																		session_present = SP},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pingresp, Tail} -> 
			case maps:get(ping, State#connection_state.processes, undefined) of
				{Pid, {M, F}} ->
					Pid ! {pong, State},
					spawn(M, F, [pong]);
				_ -> true
			end,
			socket_stream_process(
				State#connection_state{processes = maps:remove(ping, State#connection_state.processes), 
																ping_count = State#connection_state.ping_count - 1},
				Tail);
		{suback, Packet_Id, Return_code, Tail} when is_integer(Return_code) ->
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{{Pid, Ref}, {Topic, QoS, Callback}} ->
					Pid ! {suback, Ref, Return_code},
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, State#connection_state.processes),
							subscriptions = (State#connection_state.subscriptions)#{Topic => {QoS, Callback}}},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{suback, Packet_Id, Return_codes, Tail} when is_list(Return_codes)->
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{{Pid, Ref}, Subscriptions} when is_list(Subscriptions) ->
					Fun = fun ({Topic, QoS, Callback}, Subs_Map) ->
									Subs_Map#{Topic => {QoS, Callback}}
								end,
					New_Subscribsions = lists:foldl(Fun, State#connection_state.subscriptions, Subscriptions),
					Pid ! {suback, Ref, Return_codes},
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, State#connection_state.processes),
							subscriptions = New_Subscribsions},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{unsuback, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info unsuback: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{{Pid, Ref}, Topics} ->
					Pid ! {unsuback, Ref},
					Fun = fun (Topic, Subs_Map) ->
									maps:remove(Topic, Subs_Map)
								end,
					New_Subscribsions = lists:foldl(Fun, State#connection_state.subscriptions, Topics),
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, State#connection_state.processes),
							subscriptions = New_Subscribsions}, 
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{publish, QoS, Packet_Id, Topic, Payload, Tail} ->
			case get_topic_attributes(State, Topic) of
        [] ->
          true;
				List ->
					[case Callback of
						 {M, F} -> spawn(M, F, [{Topic, Payload}]);
						 {F} -> spawn(fun() -> apply(F, [{Topic, Payload}]) end)
						end
							 || {_QoS, Callback} <- List]
			end,
			case QoS of
				1 ->
					case gen_tcp:send(State#connection_state.socket, packet(puback, Packet_Id)) of
						ok -> true;
						{error, _Reason} -> true
					end,
					socket_stream_process(State, Tail);
				2 ->
					New_processes = (State#connection_state.processes)#{Packet_Id => {undefined, #publish{topic = Topic, qos = QoS, acknowleged = pubrec}}},
					case gen_tcp:send(State#connection_state.socket, packet(pubrec, Packet_Id)) of
						ok -> true;
						{error, _Reason} -> true
					end,
					socket_stream_process(
						State#connection_state{processes = New_processes},
						Tail);
				_ -> socket_stream_process(State, Tail)
			end;
		{puback, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info puback: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{{Pid, Ref}, _Params} ->
					Pid ! {puback, Ref},
					socket_stream_process(
						State#connection_state{processes = maps:remove(Packet_Id, State#connection_state.processes)},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrec, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info pubrec: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{From, Params} ->
					New_processes = (State#connection_state.processes)#{Packet_Id => {From, Params#publish{acknowleged = pubrec}}},
					case gen_tcp:send(State#connection_state.socket, packet(pubrel, Packet_Id)) of
						ok -> true;
						{error, _Reason} -> true
					end,
					socket_stream_process(
						State#connection_state{
																	processes = New_processes},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrel, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info pubrel: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{_From, _Params} ->
					New_processes = maps:remove(Packet_Id, State#connection_state.processes),
					case gen_tcp:send(State#connection_state.socket, packet(pubcomp, Packet_Id)) of
						ok -> true;
						{error, _Reason} -> true
					end,
					socket_stream_process(State#connection_state{processes = New_processes}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubcomp, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info pubcomp: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, State#connection_state.processes, undefined) of
				{{Pid, Ref}, _Params} ->
					Pid ! {pubcomp, Ref},
					socket_stream_process(
						State#connection_state{
																	processes = maps:remove(Packet_Id, State#connection_state.processes)}, 
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		_ ->
			io:format(user, " >>> handle_info unparsed message: ~p state:~p~n", [Binary, State]),
			State#connection_state{tail = Binary}
	end.

next(Packet_Id) ->
	if Packet_Id == 16#FFFF -> 0; 
		 true -> Packet_Id + 1 
	end.

wait_pong() ->
	receive
		{_Pong, _State} -> ok %%io:format(user, " >>> received pong response '~p'~n", [_Pong])
	end.

get_topic_attributes(State, Topic) ->
	case maps:get(Topic, State#connection_state.subscriptions, undefined) of
		undefined ->
			[TopicVal || {TopicKey, TopicVal} <- maps:to_list(State#connection_state.subscriptions), is_match(Topic, TopicKey)];
		Value ->
			[Value]
	end.

is_match(Topic, RegexpFilter) ->
  R1 = re:replace(RegexpFilter, "\\+", "([^/]*)", [global, {return, list}]),
%	io:format(user, " after + replacement: ~p ~n", [R1]),
  R2 = re:replace(R1, "#", "(.*)", [global, {return, list}]),
%	io:format(user, " after # replacement: ~p ~n", [R2]),
	
	{ok, Pattern} = re:compile(R2),
	case re:run(Topic, Pattern, [global, {capture, [1], list}]) of
		{match, _R} -> 
%			io:format(user, " match: ~p ~n", [_R]),
			true;
		_E ->
%			io:format(user, " NO match: ~p ~n", [_E]),
			false
	end.