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

%% @hidden
%% @since 2023-02-25
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a testing of MQTT connection.

-module(connect).

%%
%% Include files
%%

-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
	connect_0/2,
	connect_1/2,
	connect_2/2,
	connect_3/2,
	connect_4/2,
	connect_5/2,
	connect_6/2,
	reconnect/2,
	keep_alive/2
]).

-import(testing_v5, [wait_events/2]).
%%
%% API Functions
%%

connect_0({Id, connect}, [Publisher]) -> {"connect_0 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 1. successfully connected : ~p~n", [A]), test_result ! onConnect end),

	ConnRec = testing:get_connect_rec(Id),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec,
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onConnect])),
	unregister(test_result),
	?PASSED
end}.

connect_1({Id, connect}, [Publisher]) -> {"connect_1 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 2. successfully connected : ~p~n", [A]) end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 2. wrong port number : ~120p~n", [A]), test_result ! onError end),
	ConnRec = testing:get_connect_rec(Id),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{port = 3883}, 
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onError])),
	unregister(test_result),
	?PASSED
end}.

connect_2({Id, connect}, [Publisher]) -> {"connect_2 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 3. successfully connected : ~p~n", [A]) end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 3. wrong user name. Connection Resp:~120p~n", [A]), test_result ! onError end),

	ConnRec = testing:get_connect_rec(Id),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{user_name = "quest"},
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onError])),
	unregister(test_result),
	?PASSED
end}.

connect_3({Id, connect}, [Publisher]) -> {"connect_3 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 4. successfully connected : ~p~n", [A]) end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 4. wrong user password : ~120p~n", [A]), test_result ! onError end),

	ok = mqtt_client:connect(
		Publisher, 
		(testing:get_connect_rec(Id))#connect{password = <<"gueest">>},
		{callback, call},
		[]
	),	

	?assert(wait_events("", [onError])),
	unregister(test_result),
	?PASSED
end}.

connect_4({Id, connect}, [Publisher]) -> {"connect_4 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 5. duplicate client id successfully connected : ~p~n", [A]), test_result ! onConnect end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 5. duplicate client id: ~p~n", [A]) end),
	callback:set_event_handler(onClose, fun(onClose, A) -> ?debug_Fmt("::test:: 5. duplicate client id onClose : ~p~n", [A]), test_result ! onClose end),

	ConnRec = testing:get_connect_rec(testClient0),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec,
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onConnect, onClose])),
	unregister(test_result),

	?assert(erlang:is_pid(Publisher)),
	Conn = whereis(testClient0),
	?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn]),
	?assertEqual(false, mqtt_client:is_connected(Conn)),

	?PASSED
end}.

connect_5({Id, connect}, [Publisher]) -> {"connect_5 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 6. successfully connected : ~p~n", [A]) end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 6. wrong utf-8 : ~p~n", [A]), test_result ! onError end),

	ok = mqtt_client:connect(
		Publisher, 
		(testing:get_connect_rec(Id))#connect{user_name = binary_to_list(<<"gu", 16#d802:16, "est">>)},
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onError])),
	unregister(test_result),
	?PASSED
end}.

connect_6({Id, connect}, [Publisher]) -> {"connect_6 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 7. successfully connected : ~p~n", [A]) end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 7. wrong utf-8 : ~p~n", [A]), test_result ! onError end),

	ConnRec = testing:get_connect_rec(Id),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{password = <<"gu", 0, "est">>},
		{callback, call},
		[]
	),	
	
	?assert(wait_events("", [onError])),
	unregister(test_result),
	?PASSED
end}.

reconnect({Id, connect}, [Publisher]) -> {"reconnect = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onConnect, fun(onConnect, A) -> ?debug_Fmt("::test:: 8. successfully connected : ~p~n", [A]), test_result ! onConnect end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: 8. onError : ~p~n", [A]), test_result ! onError end),
	callback:set_event_handler(onClose, fun(onClose, A) -> ?debug_Fmt("::test:: 8. onClose : ~p~n", [A]), test_result ! onClose end),

	ConnRec = testing:get_connect_rec(Id),	
	ok = mqtt_client:connect(
		Publisher, 
		ConnRec, 
		{callback, call},
		[]
	),	
	?assert(wait_events("", [onConnect])),
	true = mqtt_client:is_connected(Publisher),
	
	ok = mqtt_client:disconnect(Publisher),
	?assert(wait_events("", [onClose])),
	false = mqtt_client:is_connected(Publisher),
	
	ok = mqtt_client:reconnect(Publisher),
	?assert(wait_events("", [onConnect])),
	unregister(test_result),
	true = mqtt_client:is_connected(Publisher),
	?debug_Fmt("::test:: 8. successfully reconnected.", []),

	?PASSED
end}.

keep_alive(_, Conn) -> {"\n\e[1;34mkeep alive test\e[0m", timeout, 15, fun() ->	
	timer:sleep(1500),
	ok = mqtt_client:pingreq(Conn), 

	timer:sleep(4900),
	R2 = mqtt_client:status(Conn), 
	?assertMatch([{connected,1},{session_present,0},{subscriptions,_}], R2),
	timer:sleep(3000),
	R3 = mqtt_client:status(Conn), 
	?assertMatch([{connected,0},{session_present,0},{subscriptions,_}], R3),

	?PASSED
end}.
