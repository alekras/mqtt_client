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

-ifdef(TEST).
-export([	
	is_match/2
]).
-endif.

-import(mqtt_client_output, [packet/2]).
-import(mqtt_client_input, [input_parser/1]).

-ifdef(TEST).
-define(test_fragment, 
handle_call({publish, _}, _, #connection_state{test_flag = break_connection} = State) ->
%	io:format(user, " >>> publish request break_connection ~p~n", [State]),
	gen_tcp:close(State#connection_state.socket),
	{stop, normal, State};
).
-else.
-define(test_fragment, ).
-endif.

open_socket(Host, Port, Options) ->
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
          {send_timeout, ?SEND_TIMEOUT} | Options
        ], 
        ?CONN_TIMEOUT
      )
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, Socket} -> Socket;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="open_socket/3", message = Reason}
  end.  


%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
%% @private
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
	case R = open_socket(Host, Port, Options) of
		#mqtt_client_error{} -> {stop, R};
		_ -> {ok, #connection_state{socket = R}}
	end.

%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
%% @private
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
handle_call({connect, Conn_config}, From, State) ->
	handle_call({connect, Conn_config, undefined}, From, State);

handle_call({connect, Conn_config, Callback}, {_, Ref} = From, State) ->
%	io:format(user, " >>> connect request ~p, ~p~n", [Conn_config, State]),
	(State#connection_state.storage):start(),
	case gen_tcp:send(State#connection_state.socket, packet(connect, Conn_config)) of
    ok -> 
			New_Subsciptions =
			case Conn_config#connect.clean_session of
			 1 -> 
				 (State#connection_state.storage):cleanup(Conn_config#connect.client_id),
				 #{};
		    0 ->	 
					restore_session(State, Conn_config) %% @todo resend messages from stored session
	    end,
			New_processes = (State#connection_state.processes)#{connect => From},
			{reply, {ok, Ref}, State#connection_state{config = Conn_config, default_callback = Callback, processes = New_processes, subscriptions = New_Subsciptions}};
    {error, Reason} -> {reply, {error, Reason}, State}
  end;

handle_call(status, _From, State) ->	
	{reply, [{session_present, State#connection_state.session_present}, {subscriptions, State#connection_state.subscriptions}], State};

handle_call({set_test_flag, Flag}, _From, State) ->	
%	io:format(user, " >>> set_test_flag request ~p~n", [Flag]),
	{reply, ok, State#connection_state{test_flag = Flag}};

?test_fragment

handle_call({publish, #publish{qos = 0} = Params}, {_, Ref}, State) ->
%	io:format(user, " >>> publish request ~p, ~p, ~p~n", [Params, Payload, State]),
	gen_tcp:send(State#connection_state.socket, packet(publish, Params)),
	{reply, {ok, Ref}, State};

handle_call({publish, #publish{qos = QoS} = Params}, {_, Ref}, State) when ((QoS =:= 1) orelse (QoS =:= 2)) and (State#connection_state.test_flag =:= skip_send_publish) ->
%	io:format(user, " >>> publish request ~p, ~p, ~p~n", [Params, Payload, State]),
	Packet_Id = State#connection_state.packet_id,
%% store message before sending
  Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
	(State#connection_state.storage):save(#storage_publish{key = Prim_key, document = Params}),
  {reply, {ok, Ref}, State};

handle_call({publish, #publish{qos = QoS} = Params}, {_, Ref} = From, State) when (QoS =:= 1) orelse (QoS =:= 2) ->
%	io:format(user, " >>> publish request ~p, ~p, ~p~n", [Params, Payload, State]),
	Packet_Id = State#connection_state.packet_id,
	Packet = packet(publish, {Params, Packet_Id}),
%% store message before sending
  Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
	(State#connection_state.storage):save(#storage_publish{key = Prim_key, document = Params}),
	case gen_tcp:send(State#connection_state.socket, Packet) of
		ok -> 
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Params}},
		{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id, State), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
  end;

handle_call({republish, undefined, Packet_Id}, {_, Ref} = From, State) ->
%	io:format(user, " >>> re-publish request undefined, PI: ~p.~n", [Packet_Id]),
	Packet = packet(pubrel, Packet_Id),
	case gen_tcp:send(State#connection_state.socket, Packet) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, #publish{acknowleged = pubrec}}},
	    {reply, {ok, Ref}, State#connection_state{processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
  end;
handle_call({republish, #publish{topic = undefined, acknowleged = pubrec}, Packet_Id}, {_, Ref} = From, State) ->
%	io:format(user, " >>> re-publish request #publish{topic = undefined, acknowleged = pubrec}, PI: ~p.~n", [Packet_Id]),
	Packet = packet(pubrec, Packet_Id),
	case gen_tcp:send(State#connection_state.socket, Packet) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, #publish{acknowleged = pubrec}}},
	    {reply, {ok, Ref}, State#connection_state{processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
  end;
handle_call({republish, Params, Packet_Id}, {_, Ref} = From, State) ->
%	io:format(user, " >>> re-publish request ~p, PI: ~p.~n", [Params, Packet_Id]),
	Packet = packet(publish, {Params, Packet_Id}),
  case gen_tcp:send(State#connection_state.socket, Packet) of
    ok -> 
	    New_processes = (State#connection_state.processes)#{Packet_Id => {From, Params}},
	    {reply, {ok, Ref}, State#connection_state{processes = New_processes}};
    {error, Reason} -> {reply, {error, Reason}, State}
  end;

handle_call({subscribe, Subscriptions}, {_, Ref} = From, State) ->
%%	io:format(user, " >>> subscribe request ~p, ~p~n", [Subscriptions, State]),
	Packet_Id = State#connection_state.packet_id,
	case gen_tcp:send(State#connection_state.socket, packet(subscribe, {Subscriptions, Packet_Id})) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Subscriptions}},
			{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id, State), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({unsubscribe, Topics}, {_, Ref} = From, State) ->
%	io:format(user, " >>> unsubscribe request ~p, ~p~n", [Topic, State]),
	Packet_Id = State#connection_state.packet_id,
	case gen_tcp:send(State#connection_state.socket, packet(unsubscribe, {Topics, Packet_Id})) of
		ok ->
			New_processes = (State#connection_state.processes)#{Packet_Id => {From, Topics}},
			{reply, {ok, Ref}, State#connection_state{packet_id = next(Packet_Id, State), processes = New_processes}};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call(disconnect, _From, #connection_state{config = Config} = State) ->
	case gen_tcp:send(State#connection_state.socket, packet(disconnect, false)) of
    ok -> 
			lager:info("Client ~p is disconnected.", [Config#connect.client_id]),
			{stop, normal, State};
		{error, closed} -> {stop, normal, State};
		{error, Reason} -> {reply, {error, Reason}, State}
	end;

handle_call({ping, Callback}, _From, State) ->
%	io:format(user, " >>> ping request ~p~n", [State]),
  case gen_tcp:send(State#connection_state.socket, packet(pingreq, false)) of
    ok ->
%			Pid = spawn_link(?MODULE, wait_pong, []),
			New_processes = (State#connection_state.processes)#{ping => Callback},
			{reply, ok, State#connection_state{
																				processes = New_processes, 
																				ping_count = State#connection_state.ping_count + 1}
			};
    {error, Reason} -> {reply, {error, Reason}, State}
  end.

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
%% @private
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

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
%% @private
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
%			io:format(user, " >>> handle_info tcp_closed for socket: ~p and PID: ~p.~nState:~p~n", [Socket, self(), State]),
			gen_tcp:close(Socket),
			{stop, normal, State};
%			{noreply, State};
		_ ->
			io:format(user, " >>> handle_info unknown message: ~p state:~p~n", [Info, State]),
			{noreply, State}
	end.

	
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
%% @private
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(_Reason, _State) ->
%	io:format(user, " >>> terminate ~p~n~p~n", [_Reason, _State]),
	ok.

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
%% @private
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
% Common values:
  Processes = State#connection_state.processes,
%	io:format(user, " ->-- socket_stream_process message: state:~p Bin: ~p~n", [State, Binary]),
	case input_parser(Binary) of
		{connectack, SP, CRC, Msg, Tail} ->
			case maps:get(connect, Processes, undefined) of
				{Pid, Ref} ->
					Pid ! {connectack, Ref, SP, CRC, Msg},
					socket_stream_process(
						State#connection_state{processes = maps:remove(connect, Processes), 
																		session_present = SP},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pingresp, Tail} -> 
			case maps:get(ping, Processes, undefined) of
				{M, F} ->
%					Pid ! {pong, State},
					spawn(M, F, [pong]);
				F ->
%					Pid ! {pong, State},
					spawn(fun() -> apply(F, [pong]) end);
				_ -> true
			end,
			socket_stream_process(
				State#connection_state{processes = maps:remove(ping, Processes), 
																ping_count = State#connection_state.ping_count - 1},
				Tail);
		{suback, Packet_Id, Return_code, Tail} when is_integer(Return_code) ->
			case maps:get(Packet_Id, Processes, undefined) of
				{{Pid, Ref}, {Topic, QoS, Callback}} ->
					Pid ! {suback, Ref, Return_code},
%% store session subscription
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = 0, topic = Topic},
          (State#connection_state.storage):save(#storage_publish{key = Prim_key, document = {QoS, Callback}}), %% @todo check clean_session flag
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, Processes),
							subscriptions = (State#connection_state.subscriptions)#{Topic => {QoS, Callback}}},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{suback, Packet_Id, Return_codes, Tail} when is_list(Return_codes)->
			case maps:get(Packet_Id, Processes, undefined) of
				{{Pid, Ref}, Subscriptions} when is_list(Subscriptions) ->
%% store session subscriptions
					[ begin 
          		Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = 0, topic = Topic},
          		(State#connection_state.storage):save(#storage_publish{key = Prim_key, document = {QoS, Callback}})
						end || {Topic, QoS, Callback} <- Subscriptions], %% @todo check clean_session flag
					
					Fun = fun ({Topic, QoS, Callback}, Subs_Map) ->
									Subs_Map#{Topic => {QoS, Callback}}
								end,
					New_Subscriptions = lists:foldl(Fun, State#connection_state.subscriptions, Subscriptions),
					Pid ! {suback, Ref, Return_codes},
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, Processes),
							subscriptions = New_Subscriptions},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{unsuback, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info unsuback: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, Processes, undefined) of
				{{Pid, Ref}, Topics} ->
					Pid ! {unsuback, Ref},
%% discard session subscriptions
					[ begin 
          		Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = 0, topic = Topic},
          		(State#connection_state.storage):remove(Prim_key)
						end || Topic <- Topics], %% @todo check clean_session flag
					
					Fun = fun (Topic, Subs_Map) ->
									maps:remove(Topic, Subs_Map)
								end,
					New_Subscribsions = lists:foldl(Fun, State#connection_state.subscriptions, Topics),
					socket_stream_process(
						State#connection_state{
							processes = maps:remove(Packet_Id, Processes),
							subscriptions = New_Subscribsions}, 
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
 		{publish, _QoS, _Packet_Id, _Topic, _Payload, Tail} when State#connection_state.test_flag =:= skip_rcv_publish ->
			socket_stream_process(State, Tail);
		{publish, QoS, Packet_Id, Topic, Payload, Tail} ->
			case QoS of
				0 -> 	
					delivery_to_application(State, Topic, QoS, Payload),
					socket_stream_process(State, Tail);
				1 when State#connection_state.test_flag =:= skip_send_puback ->
					delivery_to_application(State, Topic, QoS, Payload),
					socket_stream_process(State, Tail);
				1 ->
					delivery_to_application(State, Topic, QoS, Payload),
					case gen_tcp:send(State#connection_state.socket, packet(puback, Packet_Id)) of
						ok -> ok;
						{error, _Reason} -> ok
					end,
					socket_stream_process(State, Tail);
				2 when State#connection_state.test_flag =:= skip_send_pubrec ->
					socket_stream_process(State, Tail);
				2 ->
					New_State = 
						case	maps:is_key(Packet_Id, Processes) of
							true -> State;
							false -> 
					      delivery_to_application(State, Topic, QoS, Payload),
%% store PI after receiving message
                Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
                (State#connection_state.storage):save(#storage_publish{key = Prim_key, document = #publish{acknowleged = pubrec}}),
					      case gen_tcp:send(State#connection_state.socket, packet(pubrec, Packet_Id)) of
					        ok -> 
        				    New_processes = Processes#{Packet_Id => {undefined, #publish{topic = Topic, qos = QoS, acknowleged = pubrec}}},
				        	  State#connection_state{processes = New_processes};
						      {error, _Reason} -> State
					      end
					  end,
					socket_stream_process(New_State, Tail);
				_ -> socket_stream_process(State, Tail)
			end;
		{puback, _Packet_Id, Tail} when State#connection_state.test_flag =:= skip_rcv_puback ->
			socket_stream_process(State, Tail);
		{puback, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info puback: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, Processes, undefined) of
				{{Pid, Ref}, _Params} ->
					Pid ! {puback, Ref},
%% discard message after pub ack
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
	        (State#connection_state.storage):remove(Prim_key),
					socket_stream_process(
						State#connection_state{processes = maps:remove(Packet_Id, Processes)},
						Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrec, _Packet_Id, Tail} when State#connection_state.test_flag =:= skip_rcv_pubrec ->
			socket_stream_process(State, Tail);
		{pubrec, Packet_Id, Tail} when State#connection_state.test_flag =:= skip_send_pubrel ->
			case maps:get(Packet_Id, Processes, undefined) of
				{From, Params} ->
%% store message before pubrel
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
          (State#connection_state.storage):save(#storage_publish{key = Prim_key, document = undefined}),
					New_processes = Processes#{Packet_Id => {From, Params#publish{acknowleged = pubrec}}},
					socket_stream_process(State#connection_state{processes = New_processes}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrec, Packet_Id, Tail} ->
			case maps:get(Packet_Id, Processes, undefined) of
				{From, Params} ->
%% store message before pubrel
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
          (State#connection_state.storage):save(#storage_publish{key = Prim_key, document = undefined}),
					New_processes = Processes#{Packet_Id => {From, Params#publish{acknowleged = pubrec}}},
					case gen_tcp:send(State#connection_state.socket, packet(pubrel, Packet_Id)) of
						ok -> ok; 
						{error, _Reason} -> ok
					end,
					socket_stream_process(State#connection_state{processes = New_processes}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrel, _Packet_Id, Tail} when State#connection_state.test_flag =:= skip_rcv_pubrel ->
			socket_stream_process(State, Tail);
		{pubrel, Packet_Id, Tail} when State#connection_state.test_flag =:= skip_send_pubcomp ->
			case maps:get(Packet_Id, Processes, undefined) of
				{_From, _Params} ->
%% discard PI before pubcomp send
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
          (State#connection_state.storage):remove(Prim_key),
					New_processes = maps:remove(Packet_Id, Processes),
					socket_stream_process(State#connection_state{processes = New_processes}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubrel, Packet_Id, Tail} ->
			case maps:get(Packet_Id, Processes, undefined) of
				{_From, _Params} ->
%% discard PI before pubcomp send
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
          (State#connection_state.storage):remove(Prim_key),
					New_processes = maps:remove(Packet_Id, Processes),
					case gen_tcp:send(State#connection_state.socket, packet(pubcomp, Packet_Id)) of
						ok -> ok;
						{error, _Reason} -> ok
					end,
					socket_stream_process(State#connection_state{processes = New_processes}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		{pubcomp, _Packet_Id, Tail} when State#connection_state.test_flag =:= skip_rcv_pubcomp ->
			socket_stream_process(State, Tail);
		{pubcomp, Packet_Id, Tail} ->
%			io:format(user, " >>> handle_info pubcomp: Pk Id=~p state=~p~n", [Packet_Id, State]),
			case maps:get(Packet_Id, Processes, undefined) of
				{{Pid, Ref}, _Params} ->
					Pid ! {pubcomp, Ref},
%% discard message after pub comp
          Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = Packet_Id},
	        (State#connection_state.storage):remove(Prim_key),
					socket_stream_process(State#connection_state{processes = maps:remove(Packet_Id, Processes)}, Tail);
				undefined ->
					socket_stream_process(State, Tail)
			end;
		_ ->
			io:format(user, " >>> handle_info unparsed message: ~p state:~p~n", [Binary, State]),
			State#connection_state{tail = Binary}
	end.

next(Packet_Id, State) ->
	PI =
		if Packet_Id == 16#FFFF -> 0;
			true -> Packet_Id + 1 
		end,
  Prim_key = #primary_key{client_id = (State#connection_state.config)#connect.client_id, packet_id = PI},
	case (State#connection_state.storage):exist(Prim_key) of
		false -> PI;
		true -> next(PI, State)
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

delivery_to_application(State, Topic, QoS, Payload) ->
	case get_topic_attributes(State, Topic) of
    [] -> do_callback(State#connection_state.default_callback, [{{Topic, QoS}, QoS, Payload}]);
		List ->
			[
			  case do_callback(Callback, [{{Topic, TopicQoS}, QoS, Payload}]) of
					false -> do_callback(State#connection_state.default_callback, [{{Topic, QoS}, QoS, Payload}]);
				  _ -> ok
			  end
				|| {TopicQoS, Callback} <- List
			]
	end.

do_callback(Callback, Args) ->
  case Callback of
	  {M, F} -> spawn(M, F, Args);
	  F -> spawn(fun() -> apply(F, Args) end);
		_ -> false
  end.
	
restore_session(State, Conn_config) ->
 	Records = (State#connection_state.storage):get_all(Conn_config#connect.client_id),
	MessageList = [{PI, Doc} || #storage_publish{key = #primary_key{packet_id = PI, topic = []}, document = Doc} <- Records],
	TopicList = [{Topic, QoS, Callback} || #storage_publish{key = #primary_key{packet_id = 0, topic = Topic}, document = {QoS, Callback}} <- Records],
  [spawn(gen_server, call, [self(), {republish, Params, PI}, ?GEN_SERVER_TIMEOUT])	|| {PI, Params} <- MessageList],
	Fun = fun ({Topic, QoS, Callback}, Subs_Map) ->
									Subs_Map#{Topic => {QoS, Callback}}
				end,
	lists:foldl(Fun, State#connection_state.subscriptions, TopicList).
