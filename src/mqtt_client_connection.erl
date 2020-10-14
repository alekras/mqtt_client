%%
%% Copyright (C) 2015-2020 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2020 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_connection.

-module(mqtt_client_connection).

%%
%% Include files
%%
-include_lib("mqtt_common/include/mqtt.hrl").

-export([start_link/4]).

%% ====================================================================
%% API functions
%% ====================================================================

start_link(Connection_id, Host, Port, Options) ->
	Transport =
	case proplists:get_value(conn_type, Options) of 
		ssl -> ssl;
		tsl -> ssl;
		clear -> gen_tcp;
		web_socket -> mqtt_ws_handler;
		web_sec_socket -> mqtt_ws_handler;
		_ -> gen_tcp
	end,

	Storage =
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end,

%% 	Host = application:get_env(mqtt_client, host, "localhost"),
%% 	Port = application:get_env(mqtt_client, port, 1883),

	State =
	case Socket = open_socket(Transport, Host, Port, Options) of
		#mqtt_client_error{} -> Socket;
		_ -> #connection_state{socket = Socket, transport = Transport, storage = Storage, end_type = client}
	end,	
	case T = gen_server:start_link({local, Connection_id}, mqtt_connection, State, [{timeout, ?MQTT_GEN_SERVER_TIMEOUT}]) of
		{ok, Pid} ->
			ok = Transport:controlling_process(Socket, Pid),
			T;
		{error, _} ->
			T
	end.

open_socket(gen_tcp, Host, Port, Options) ->
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
          {send_timeout, ?SOC_SEND_TIMEOUT} | proplists:delete(conn_type, Options)
        ], 
        ?SOC_CONN_TIMEOUT
      )
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, Socket} -> Socket;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="mqtt_client_connection:open_socket/4:", message = Reason}
  end;  
open_socket(ssl, Host, Port, Options) ->
  case 
    try
      ssl:connect(
        Host,
        Port, 
        [
          binary, %% @todo check and add options from Argument _Options
          {active, true}, 
          {packet, 0}, 
          {recbuf, ?SOC_BUFFER_SIZE}, 
          {sndbuf, ?SOC_BUFFER_SIZE}, 
          {send_timeout, ?SOC_SEND_TIMEOUT} | proplists:delete(conn_type, Options)
        ], 
        ?SOC_CONN_TIMEOUT
      )
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, Socket} -> Socket;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="mqtt_client_connection:open_socket/4:" , message = Reason}
  end;  
open_socket(mqtt_ws_handler, Host, Port, Options) ->
  case 
    try
			mqtt_ws_handler:start_link(Host, Port, Options)
    catch
      _:_Err -> {error, _Err}
    end
  of
    {ok, WS_handler_Pid} -> WS_handler_Pid;
    {error, Reason} -> #mqtt_client_error{type = tcp, source="mqtt_client_connection:open_socket/4:" , message = Reason}
  end.  

