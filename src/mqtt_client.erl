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
%% @doc @todo Add description to mqtt_client.


-module(mqtt_client).
-behaviour(application).

%%
%% Include files
%%
-include("mqtt_client.hrl").

-export([start/2, stop/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	connect/5,
	status/1,
%%	close/1,
%%  connect/2,
	publish/3,
	subscribe/2,
	unsubscribe/2,
	pingreq/2,
	disconnect/1
]).

connect(Connection_id, Conn_config, Host, Port, Socket_options) ->
	case mqtt_client_sup:new_connection(Connection_id, Host, Port, Socket_options) of
		{ok, Pid} ->
			{ok, Ref} = gen_server:call(Pid, {connect, Conn_config}, ?GEN_SERVER_TIMEOUT),
			receive
				{connectack, Ref, 0, Msg} -> 
%					io:format(user, " >>> received connectack ~p~n", [Msg]), %% @todo check sesion present flag
					io:format(user, " >>> client ~p/~p connected with response: ~p, ~n", [Pid, Conn_config, Msg]),
					Pid;
				{connectack, Ref, ErrNo, Msg} -> 
%					io:format(user, " >>> received connectack ~p~n", [Msg]), %% @todo check sesion present flag
					io:format(user, " >>> client ~p connected with response: ~p, ~n", [Pid, Msg]),
					#mqtt_client_error{type = connection, errno = ErrNo, source = "mqtt_client:conect/5", message = Msg}
			after ?GEN_SERVER_TIMEOUT ->
					#mqtt_client_error{type = connection, source = "mqtt_client:conect/5", message = "timeout"}
			end;
		#mqtt_client_error{} = Error -> Error;
		Exit ->
			io:format(user, " >>> client catched: ~p, ~n", [Exit])
	end.

status(Pid) ->
	case is_process_alive(Pid) of
		true ->
			try
				gen_server:call(Pid, status, ?GEN_SERVER_TIMEOUT)
			catch
				_:_ -> disconnected
			end;
		false -> disconnected
	end.
%% close(Client_id) -> %% Is it really need ?
%% 	mqtt_client_sup:close_connection(Client_id).

%% connect(Pid, Conn_config) -> 
%% 	{ok, Ref} = gen_server:call(Pid, {connect, Conn_config}, ?GEN_SERVER_TIMEOUT),
%% 	receive
%% 		{connectack, Ref, Msg} -> 
%% %			io:format(user, " >>> received connectack ~p~n", [Msg]), 
%% 		{ok, Msg}
%% 	end.

publish(Pid, Params, Payload) -> 
	case Params#publish.qos of
		0 ->
			gen_server:call(Pid, {publish, Params, Payload}, ?GEN_SERVER_TIMEOUT);
		1 ->
			{ok, Ref} = gen_server:call(Pid, {publish, Params, Payload}, ?GEN_SERVER_TIMEOUT),
			receive
				{puback, Ref} -> 
%					io:format(user, " >>> received puback ~p~n", [Ref]), 
					{puback}
			end;
		2 ->
			{ok, Ref} = gen_server:call(Pid, {publish, Params, Payload}, ?GEN_SERVER_TIMEOUT),
			receive
				{pubcomp, Ref} -> 
%					io:format(user, " >>> received pubcomp ~p~n", [Ref]),
					{pubcomp}
			end
	end.

subscribe(Pid, Subscriptions) ->
	{ok, Ref} = gen_server:call(Pid, {subscribe, Subscriptions}, ?GEN_SERVER_TIMEOUT),
	receive
		{suback, Ref, RC} -> 
%			io:format(user, " >>> received suback ~p~n", [RC]), 
			{suback, RC}
	end.

unsubscribe(Pid, Topics) ->
	{ok, Ref} = gen_server:call(Pid, {unsubscribe, Topics}, ?GEN_SERVER_TIMEOUT),
	receive
		{unsuback, Ref} -> 
%			io:format(user, " >>> received unsuback ~p~n", [Ref]), 
			{unsuback}
	end.

pingreq(Pid, Callback) -> 
	gen_server:call(Pid, {ping, Callback}, ?GEN_SERVER_TIMEOUT).

disconnect(Client_id) -> %% @todo arg = Pid
	try 
  	gen_server:call(Client_id, disconnect, ?GEN_SERVER_TIMEOUT)
	catch
    exit:R -> io:format(user, " >>> disconnect ~p~n", [R])
	end.
% 	ok = mqtt_client_sup:close_connection(Client_id).

%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% start/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/apps/kernel/application.html#Module:start-2">application:start/2</a>
-spec start(Type :: normal | {takeover, Node} | {failover, Node}, Args :: term()) ->
	{ok, Pid :: pid()}
	| {ok, Pid :: pid(), State :: term()}
	| {error, Reason :: term()}.
%% ====================================================================
start(Type, StartArgs) ->
  io:format(user, " >>> start application ~p ~p~n", [Type, StartArgs]),
  case supervisor:start_link({local, mqtt_client_sup}, mqtt_client_sup, StartArgs) of
		{ok, Pid} ->
			{ok, Pid};
		Error ->
			Error
    end.

%% stop/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/apps/kernel/application.html#Module:stop-1">application:stop/1</a>
-spec stop(State :: term()) ->  Any :: term().
%% ====================================================================
stop(State) ->
  io:format(user, " <<< stop application ~p~n", [State]),
  ok.

%% ====================================================================
%% Internal functions
%% ====================================================================


