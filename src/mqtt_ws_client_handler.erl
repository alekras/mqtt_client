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
%% @doc Handler for websocket connection.

-module(mqtt_ws_client_handler).

-behaviour(websocket_client_handler).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
         start_link/3,
         init/2,
         websocket_handle/3,
         websocket_info/3,
         websocket_terminate/3,
				 send/2,
				 close/1,
				 controlling_process/2,
				 peername/1
        ]).

start_link(Host, Port, Options) ->
	lager:debug([{endtype, client}], ">>> start_link: ~p:~p~n     Options:~p~n", [Host, Port, Options]),
	ok = application:ensure_started(crypto),
	ok = application:ensure_started(ssl),
	{ok, HostName} = inet:gethostname(),
	Headers = [
		{"accept-language", "en-US,en;q=0.5"},
		{"cache-control","no-cache"},
		{"connection","keep-alive"},
%		{"host", lists:concat([Host, ":", Port])},
		{"origin", HostName},
		{"pragma", "no-cache"},
		{"sec-websocket-extensions", "permessage-deflate"},
		{"user-agent", "MQTT Erlang client. See https://sourceforge.net/projects/mqtt-client."},
		{"sec-websocket-protocol", "mqttv3.1, mqttv3.1.1"}
	],
	Protocol = case proplists:get_value(conn_type, Options, clear) of
							 web_socket -> "ws://";
							 web_sec_socket -> "wss://"
						 end,
	URL = lists:concat([
		Protocol,
		Host,
		":",
		Port,
		"/mqtt"
	]),
	lager:debug([{endtype, client}], "<<< start_link: url: ~p~n     Headers:~p~n", [URL, Headers]),
	websocket_client:start_link(URL, ?MODULE, [], [{extra_headers, Headers}]).

init(_Arg, _ConnState) ->
	lager:debug([{endtype, client}], "init with ARG: ~p~nConn State:~p~n", [_Arg, _ConnState]),
	{ok, #{}}.

websocket_handle({binary, Binary} = _Info, _ConnState, State) ->
	Pid = maps:get(conn_pid, State, undefined),
	Pid ! {tcp, self(), Binary},
	{ok, State};
websocket_handle(_Info, _ConnState, State) ->
	lager:debug([{endtype, client}], "unknown message: ~p~nConn state: ~p~nState: ~p~n", [_Info, _ConnState, State]),
	{ok, State}.
%% websocket_handle({text, Msg}, _ConnState, 5) ->
%%     io:format("Received msg ~p~n", [Msg]),
%%     {close, <<>>, "done"};
%% websocket_handle({text, Msg}, _ConnState, State) ->
%%     io:format("Received msg ~p~n", [Msg]),
%%     timer:sleep(1000),
%%     BinInt = list_to_binary(integer_to_list(State)),
%%     {reply, {text, <<"hello, this is message #", BinInt/binary >>}, State + 1}.

websocket_info({start, Conn_Process_Pid} = _Info, _ConnState, State) ->
	State1 = maps:put(conn_pid, Conn_Process_Pid, State),
	{ok, State1};
websocket_info({out, Packet} = _Info, _ConnState, State) ->
	{reply, {binary, Packet}, State};
websocket_info({'EXIT', Pid, Reason}, ConnState, State) ->
	lager:info([{endtype, client}], "get EXIT from pid: ~p reason: ~p conn state: ~p~n state: ~p~n", [Pid, Reason, ConnState, State]),
	{close, {binary, <<>>}, State};
websocket_info(close_ws, ConnState, State) ->
	lager:info([{endtype, client}], "get close socket from connection, conn state: ~p~n state: ~p~n", [ConnState, State]),
	State1 = maps:put(conn_pid, undefined, State),
	{close, {binary, <<>>}, State1};
websocket_info(_Info, _ConnState, State) ->
	lager:debug([{endtype, client}], "_Info: ~120p~n~p~n~p~n", [_Info, _ConnState, State]),
	{ok, State}.

websocket_terminate(Reason, _ConnState, State) ->
	lager:info([{endtype, client}], "Websocket closed in state ~p wih reason ~p~n", [State, Reason]),
	Pid = maps:get(conn_pid, State, undefined),
	if is_pid(Pid) ->	Pid ! {tcp_closed, self()};
		 true -> ok
	end,
	ok.

send(WS_Handler_Pid, Packet) ->
	WS_Handler_Pid ! {out, Packet},
	ok.
	
close(WS_Handler_Pid) ->
	WS_Handler_Pid ! close_ws,
	ok.

controlling_process(WS_Handler_Pid, Conn_Process_Pid) ->
	WS_Handler_Pid ! {start, Conn_Process_Pid},
	ok.

peername(_WS_Handler_Pid) -> ok.
%% ====================================================================
%% Internal functions
%% ====================================================================


