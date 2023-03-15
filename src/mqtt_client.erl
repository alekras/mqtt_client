%%
%% Copyright (C) 2015-2022 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc Main module of mqtt_client application. The module implements application behaviour
%% and application API.
%% @headerfile "mqtt.hrl"

-module(mqtt_client).
-behaviour(application).

%%
%% Include files
%%
-include_lib("mqtt_common/include/mqtt.hrl").

-export([start/2, stop/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	create/1,
	connect/3, connect/4,
	status/1,
	publish/2, publish/3,
	subscribe/2, subscribe/3,
	unsubscribe/2, unsubscribe/3,
	pingreq/2,
	disconnect/1, disconnect/3,
	dispose/1
]).

-spec create(Client_name) -> Result when
	Client_name :: atom(),
	Result :: pid() | #mqtt_client_error{}.
%% 
%% @doc The function creates instance of MQTT client.
create(Client_name) ->
	case mqtt_client_sup:new_client(Client_name) of
		{ok, Pid} -> Pid;
		#mqtt_client_error{} = Error -> 
			lager:error([{endtype, client}], "client create catched error: ~p, ~n", [Error]),
			Error;
		Exit ->
			lager:error([{endtype, client}], "client create catched exit: ~p, ~n", [Exit]),
			#mqtt_client_error{type = connection, source = "mqtt_client:create/2", message = Exit}
	end.	

-spec connect(Client_name, Conn_config, Socket_options) -> Result when
  Client_name :: atom() | pid(),
  Conn_config :: #connect{},
  Socket_options :: list(),
  Result :: ok | #mqtt_client_error{}.
%% 
%% @doc The function open socket to MQTT server and sends connect package to the server.
%% <dl>
%% <dt>Client_name</dt>
%% <dd>Registered name or Pid of client process.</dd>
%% <dt>Conn_config</dt>
%% <dd>#connect{} record defines the connection options.</dd>
%% <dt>Socket_options</dt>
%% <dd>Additional socket options.</dd>
%% </dl>
%% Returns ok or error record. 
%%
connect(Client_name, Conn_config, Socket_options) ->
  connect(Client_name, Conn_config, undefined, Socket_options).

-spec connect(Client_name, Conn_config, Default_Callback, Socket_options) -> Result when
 Client_name :: atom() | pid(),
 Conn_config :: #connect{},
 Default_Callback :: {atom()} | {atom(), atom()},
 Socket_options :: list(),
 Result :: ok | #mqtt_client_error{}.
%% 
%% @doc The function creates socket connection to MQTT server and sends connect package to the server.<br/>
%% Parameters:
%% <ul style="list-style-type: none;">
%% <li>Client_name - Registered name or Pid of client process.</li>
%% <li>Conn_config - #connect{} record defines the connection options.</li>
%% <li>Default_Callback - Definition of callback function for any subscriptions what miss callback definition.</li>
%% <li>Socket_options - Additional socket options.</li>
%% </ul>
%% Returns ok or error record. 
%%
connect(Client_name, Conn_config, Default_Callback, Socket_options) ->
	%% @todo check input parameters
	case gen_server:call(
				Client_name,
				{connect, Conn_config, Default_Callback, Socket_options},
				?MQTT_GEN_SERVER_TIMEOUT)
	of
		{ok, Ref} ->
			receive
				{connack, Ref, _SP, 0, _Msg, _Properties} -> 
					ok;
				{connack, Ref, _, ErrNo, Msg, _Properties} -> 
					#mqtt_client_error{type = connection, errno = ErrNo, source = "mqtt_client:conect/4", message = Msg}
			after ?MQTT_GEN_SERVER_TIMEOUT ->
					#mqtt_client_error{type = connection, source = "mqtt_client:conect/4", message = "timeout"}
			end;
		#mqtt_client_error{} = Error -> 
			lager:error([{endtype, client}], "client catched connection error: ~p, ~n", [Error]),
			Error;
		Exit ->
			lager:error([{endtype, client}], "client catched exit while connecting: ~p, ~n", [Exit]),
			#mqtt_client_error{type = connection, source = "mqtt_client:conect/4", message = Exit}
	end.

-spec status(Pid) -> Result when
 Pid :: pid(),
 Result :: disconnected | [{connected, boolean()} | {session_present, SP:: 0 | 1} | {subscriptions, #{Topic::string() => {QoS::integer(), Callback::{fun()} | {module(), fun()}}}}].
%% @doc The function returns status of connection with pid = Pid.
%% 
status(Pid) when is_pid(Pid) ->
	case is_process_alive(Pid) of
		true ->
			try
				gen_server:call(Pid, status, ?MQTT_GEN_SERVER_TIMEOUT)
			catch
				_:_ -> disconnected
			end;
		false -> disconnected
	end;
status(Name) when is_atom(Name) ->
	case whereis(Name) of
		undefined -> disconnected;
		Pid -> status(Pid)
	end;
status(_) -> disconnected.

-spec publish(Pid, Params, Payload) -> Result when
 Pid :: pid(),
 Params :: #publish{}, 
 Payload :: binary(),
 Result :: ok | #mqtt_client_error{}. 
%% 
%% @doc The function sends a publish packet to MQTT server.
%% 
publish(Pid, Params, Payload) ->
  publish(Pid, Params#publish{payload = Payload}).	
	
-spec publish(Pid, Params) -> Result when
 Pid :: pid(),
 Params :: #publish{}, 
 Result :: ok | #mqtt_client_error{}. 
%% 
%% @doc The function sends a publish packet to MQTT server.
%% 
publish(Pid, Params) -> 
	case gen_server:call(Pid, {publish, Params}, ?MQTT_GEN_SERVER_TIMEOUT) of
		{ok, Ref} -> 
			case Params#publish.qos of
				0 -> ok;
				1 ->
					receive
						{puback, Ref, _ReasonCode, _Properties} ->
							ok
					after ?MQTT_GEN_SERVER_TIMEOUT ->
						#mqtt_client_error{type = publish, source = "mqtt_client:publish/2", message = "puback timeout"}
					end;
				2 ->
					receive
						{pubcomp, Ref, _ReasonCode, _Properties} ->
							ok
					after ?MQTT_GEN_SERVER_TIMEOUT ->
						#mqtt_client_error{type = publish, source = "mqtt_client:publish/2", message = "pubcomp timeout"}
					end
			end;
		{error, #mqtt_client_error{} = Response, _Ref} ->
				Response;
		{error, Reason, _Ref} ->
				#mqtt_client_error{type = publish, source = "mqtt_client:publish/2", message = Reason}
	end.

-spec subscribe(Pid, Subscriptions) -> Result when
 Pid :: pid(),
 Subscriptions :: [{Topic::string(), QoS::integer(), Callback}], 
 Callback :: fun((A :: tuple()) -> any()) | {module(), fun((A :: tuple()) -> any())},
 Result :: {suback, [integer()]} | #mqtt_client_error{}. 
%% 
%% @doc The function sends a subscribe packet to MQTT server. Callback function will receive messages from the Topic.
%% 
subscribe(Pid, Subscriptions) ->
	subscribe(Pid, Subscriptions, []).

subscribe(Pid, Subscriptions, Properties) ->
	case gen_server:call(Pid, {subscribe, Subscriptions, Properties}, ?MQTT_GEN_SERVER_TIMEOUT) of
		{ok, Ref} ->
			receive
				{suback, Ref, Return_codes, Props} ->
					{suback, Return_codes, Props}
			after ?MQTT_GEN_SERVER_TIMEOUT ->
				#mqtt_client_error{type = subscribe, source = "mqtt_client:subscribe/3", message = "subscribe timeout"}
			end;
		{error, Reason} ->
				#mqtt_client_error{type = subscribe, source = "mqtt_client:subscribe/3", message = Reason}
	end.

-spec unsubscribe(Pid, Topics) -> Result when
 Pid :: pid(),
 Topics :: [Topic::string()], 
 Result :: {unsuback, ReturnCodes::list(), Properties::list()} | #mqtt_client_error{}. 
%% 
%% @doc The function sends a subscribe packet to MQTT server.
%% 
unsubscribe(Pid, Topics) ->
	unsubscribe(Pid, Topics, []).

unsubscribe(Pid, Topics, Properties) ->
	case gen_server:call(Pid, {unsubscribe, Topics, Properties}, ?MQTT_GEN_SERVER_TIMEOUT) of
		{ok, Ref} ->
			receive
				{unsuback, Ref, ReturnCodes, Props} ->
					{unsuback, ReturnCodes, Props}
			after ?MQTT_GEN_SERVER_TIMEOUT ->
				#mqtt_client_error{type = unsubscribe, source = "mqtt_client:unsubscribe/3", message = "unsubscribe timeout"}
			end;
		{error, Reason} ->
				#mqtt_client_error{type = unsubscribe, source = "mqtt_client:unsubscribe/3", message = Reason}
	end.

-spec pingreq(Pid, Callback) -> Result when
 Pid :: pid(),
 Callback :: fun((A::tuple()) -> any()) | {module(), fun((A::tuple()) -> any())},
 Result :: ok. 
%% 
%% @doc The function sends a ping request to MQTT server. Response will hit callback function arity 1.
%% 
pingreq(Pid, Callback) -> 
	gen_server:call(Pid, {pingreq, Callback}, ?MQTT_GEN_SERVER_TIMEOUT).

-spec disconnect(Pid) -> Result when
 Pid :: pid() | atom(),
 Result :: ok | #mqtt_client_error{}.
%% 
%% @doc The function sends a disconnect request to MQTT server.
%% 
disconnect(Pid) ->
	disconnect(Pid, 0, []).

-spec disconnect(Pid, ReasonCode, Properties) -> Result when
 Pid :: pid() | atom(),
 ReasonCode :: integer(),
 Properties :: list(),
 Result :: ok | #mqtt_client_error{}.
%% 
%% @doc The function sends a disconnect request to MQTT server.
%% 
disconnect(Pid, ReasonCode, Properties) when is_pid(Pid) ->
	case is_process_alive(Pid) of
		true ->
			case gen_server:call(Pid, {disconnect, ReasonCode, Properties}) of
				{ok, Ref} -> 
					receive
						{disconnected, Ref} -> 
							ok
					after ?MQTT_GEN_SERVER_TIMEOUT ->
						#mqtt_client_error{type = disconnect, source = "mqtt_client:disconnect/2", message = "disconnect timeout"}
					end;
				_ -> ok
			end;
		false -> ok
	end;
disconnect(Name, ReasonCode, Properties) when is_atom(Name) ->
	case whereis(Name) of
		undefined -> ok;
		Pid -> disconnect(Pid, ReasonCode, Properties)
	end;
disconnect(_,_,_) -> ok.

-spec dispose(Client_name) -> Result when
 Client_name :: pid() | atom(),
 Result :: ok | #mqtt_client_error{}.
%% 
%% @doc The function deletes the client process with pid or registered name Client_name from supervisor tree.
%% 
dispose(Client_name) ->
	disconnect(Client_name),
	mqtt_client_sup:dispose_client(Client_name).
%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/apps/kernel/application.html#Module:start-2">application:start/2</a>
%% @private
-spec start(Type :: normal | {takeover, Node} | {failover, Node}, Args :: term()) ->
	{ok, Pid :: pid()}
	| {ok, Pid :: pid(), State :: term()}
	| {error, Reason :: term()}.
%% ====================================================================
start(_Type, StartArgs) ->
	lager:start(),
	case application:get_env(lager, log_root) of
		{ok, _} -> ok;
		undefined ->
			application:set_env(lager, log_root, "logs", [{persistent, true}]),
			application:set_env(lager, error_logger_redirect, true, [{persistent, true}]),
			application:set_env(lager, handlers, [{lager_console_backend, [{level, error}]}], [{persistent, true}]),
			application:stop(lager),
			lager:start()
	end,
	application:load(sasl),
	lager:info([{endtype, client}], "running apps: ~p",[application:which_applications()]),	
	Storage =
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end,
	case supervisor:start_link({local, mqtt_client_sup}, mqtt_client_sup, StartArgs) of
		{ok, Pid} ->
			Storage:start(client),
			{ok, Pid};
		Error ->
			Error
  end.

%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/apps/kernel/application.html#Module:stop-1">application:stop/1</a>
-spec stop(State :: term()) ->  Any :: term().
%% ====================================================================
%% @private
stop(_State) ->
  ok.

%% ====================================================================
%% Internal functions
%% ====================================================================


