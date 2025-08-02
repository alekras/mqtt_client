%%
%% Copyright (C) 2015-2023 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2023 Alexei Krasnopolski
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
	is_connected/1,
	publish/2, publish/3,
	subscribe/2, subscribe/3,
	unsubscribe/2, unsubscribe/3,
	pingreq/1,
	disconnect/1, disconnect/3,
	dispose/1
]).

-spec create(Client_name) -> Result when
	Client_name :: atom(),
	Result :: pid() | #mqtt_error{}.
%% 
%% @doc The function creates instance of MQTT client.
create(Client_name) ->
	case mqtt_client_sup:new_client(Client_name) of
		{ok, Pid} -> Pid;
		#mqtt_error{} = Error -> 
			lager:error([{endtype, client}], "client create catched error: ~p, ~n", [Error]),
			Error;
		Exit ->
			lager:error([{endtype, client}], "client create catched exit: ~p, ~n", [Exit]),
			#mqtt_error{oper = create, source = "mqtt_client:create/2", error_msg = Exit}
	end.

-spec connect(Client_name, Conn_config, Callback) -> ok when
	Client_name :: atom() | pid(),
	Conn_config :: #connect{},
	Callback :: function() | pid() | {module(), function()}.
%% 
%% @doc The function open socket to MQTT server and sends connect package to the server.
%% <dl>
%% <dt>Client_name</dt>
%% <dd>Registered name or Pid of client process.</dd>
%% <dt>Callback</dt><dd>Definition of callback function that receives any events of the client's life time.</dd>
%% <dt>Conn_config</dt>
%% <dd>#connect{} record defines the connection options.</dd>
%% <dt>Socket_options</dt>
%% <dd>Additional socket options.</dd>
%% </dl>
%% Returns ok or error record. 
%%
connect(Client_name, Conn_config, Callback) ->
	connect(Client_name, Conn_config, Callback, []).

-spec connect(Client_name, Conn_config, Callback, Socket_options) -> ok when
	Client_name :: atom() | pid(),
	Conn_config :: #connect{},
	Callback :: function() | pid() | {module(), function()},
	Socket_options :: list().
%% 
%% @doc The function creates socket connection to MQTT server and sends connect package to the server.<br/>
%% Parameters:
%% <ul style="list-style-type: none;">
%% <li>Client_name - Registered name or Pid of client process.</li>
%% <li>Conn_config - #connect{} record defines the connection options.</li>
%% <li>Callback - Definition of callback function that receives any events of the client's life time.</li>
%% <li>Socket_options - Additional socket options.</li>
%% </ul>
%% Returns ok or error record. 
%%
connect(Client_name, Conn_config, Callback, Socket_options) ->
	%% @todo check input parameters
	gen_server:cast(
		Client_name,
		{connect, Conn_config, Callback, Socket_options}
	).

-spec status(Pid) -> Result when
 Pid :: pid(),
 Result :: disconnected | [{connected, boolean()} | {session_present, SP:: 0 | 1} |
		{subscriptions, #{Topic::string() => {QoS::integer(), Callback::{fun()} | {module(), fun()}}}}].
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

is_connected(Client_name) ->
	case status(Client_name) of
		disconnected -> false;
		[{connected, CS}, _, _] -> (CS == 1)
	end.

-spec publish(Pid, Params, Payload) -> ok when
 Pid :: pid(),
 Params :: #publish{}, 
 Payload :: binary(). 
%% 
%% @doc The function sends a publish packet to MQTT server.
%% 
publish(Pid, Params, Payload) ->
  publish(Pid, Params#publish{payload = Payload}).	
	
-spec publish(Pid, Params) -> ok when
 Pid :: pid(),
 Params :: #publish{}. 
%% 
%% @doc The function sends a publish packet to MQTT server.
%% 
publish(Pid, Params) -> 
	gen_server:cast(Pid, {publish, Params}).

-spec subscribe(Pid, Subscriptions) -> ok when
 Pid :: pid(),
 Subscriptions :: [{Topic::string(), QoS::integer()}]. 
%% Callback :: fun((A :: tuple()) -> any()) | {module(), fun((A :: tuple()) -> any())}. 
%% 
%% @doc The function sends a subscribe packet to MQTT server.
%% 
subscribe(Pid, Subscriptions) ->
	gen_server:cast(Pid, {subscribe, Subscriptions}).

subscribe(Pid, Subscriptions, Properties) ->
	gen_server:cast(Pid, {subscribe, Subscriptions, Properties}).

-spec unsubscribe(Pid, Topics) -> ok when
 Pid :: pid(),
 Topics :: [Topic::string()]. 
%% 
%% @doc The function sends a subscribe packet to MQTT server.
%% 
unsubscribe(Pid, Topics) ->
	unsubscribe(Pid, Topics, []).

unsubscribe(Pid, Topics, Properties) ->
	gen_server:cast(Pid, {unsubscribe, Topics, Properties}).

-spec pingreq(Pid) -> ok when
 Pid :: pid().
%% Callback :: fun((A::tuple()) -> any()) | {module(), fun((A::tuple()) -> any())}. 
%% 
%% @doc The function sends a ping request to MQTT server. Response will hit callback function arity 1.
%% 
pingreq(Pid) -> 
	gen_server:cast(Pid, pingreq).

-spec disconnect(Pid) -> ok when
 Pid :: pid() | atom().
%% 
%% @doc The function sends a disconnect request to MQTT server.
%% 
disconnect(Pid) ->
	disconnect(Pid, 0, []).

-spec disconnect(Client_name, ReasonCode, Properties) -> ok when
 Client_name :: pid() | atom(),
 ReasonCode :: integer(),
 Properties :: list().
%% 
%% @doc The function sends a disconnect request to MQTT server.
%% 
disconnect(Client_name, ReasonCode, Properties) ->
	case is_connected(Client_name) of
		true ->
			gen_server:cast(Client_name, {disconnect, ReasonCode, Properties});
		false -> ok
	end.

-spec dispose(Client_name) -> Result when
 Client_name :: pid() | atom(),
 Result :: ok | #mqtt_error{}.
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
-spec start(Type :: normal | {takeover, _Node} | {failover, _Node}, Args :: term()) ->
	{ok, Pid :: pid()}
	| {ok, Pid :: pid(), State :: term()}
	| {error, Reason :: term()}.
%% ====================================================================
start(_Type, StartArgs) ->
	lager:start(),
	application:ensure_started(sasl),
	application:ensure_started(inets),
	application:ensure_started(crypto),
	application:ensure_started(asn1),
	application:ensure_started(public_key),
	application:ensure_started(ssl),
	application:start(mqtt_common),
	case application:get_env(lager, log_root) of
		{ok, _} -> ok;
		undefined ->
			application:set_env(lager, log_root, "logs", [{persistent, true}]),
			application:set_env(lager, error_logger_redirect, true, [{persistent, true}]),
			application:set_env(lager, handlers, [{lager_console_backend, [{level, error}]}], [{persistent, true}]),
			application:stop(lager),
			lager:start()
	end,
	S = lists:concat([io_lib:format("    ~p~n",[App]) || App <- application:which_applications()]),
	lager:info([{endtype, client}], "running apps: ~n~s",[S]),	
	Storage =
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_storage;
		dets -> mqtt_dets_storage
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


