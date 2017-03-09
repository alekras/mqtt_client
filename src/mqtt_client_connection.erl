%%
%% Copyright (C) 2015-2017 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2017 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_connection.

-module(mqtt_client_connection).

%%
%% Include files
%%
-include("mqtt_client.hrl").

-export([start_link/4]).

%% ====================================================================
%% API functions
%% ====================================================================

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
          {recbuf, ?SOC_BUFFER_SIZE}, 
          {sndbuf, ?SOC_BUFFER_SIZE}, 
          {send_timeout, ?SOC_SEND_TIMEOUT} | Options
        ], 
        ?SOC_CONN_TIMEOUT
      )
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, Socket} -> Socket;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="open_socket/3", message = Reason}
  end.  

start_link(Connection_id, Host, Port, Options) ->
	Storage =
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end,
	State =
	case R = open_socket(Host, Port, Options) of
		#mqtt_client_error{} -> R;
		_ -> #connection_state{socket = R, transport = gen_tcp, storage = Storage, end_type = client}
	end,	
	{ok, Pid} = gen_server:start_link({local, Connection_id}, mqtt_connection, State, [{timeout, ?MQTT_GEN_SERVER_TIMEOUT}]),
	ok = gen_tcp:controlling_process(R, Pid),
	{ok, Pid}.
