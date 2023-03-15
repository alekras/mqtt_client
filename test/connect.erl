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
%% -include_lib("eunit/include/eunit.hrl").
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
	keep_alive/2
]).

%-import(testing, [wait_all/1]).
%%
%% API Functions
%%

connect_0({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_0 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec, 
		[]
	),	
	
	?debug_Fmt("::test:: 1. successfully connected : ~p", [ConnResp]),
	?assert(ConnResp =:= ok),

	?PASSED
end}.

connect_1({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_1 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{port = 3883}, 
		[]
	),	
	
	?debug_Fmt("::test:: 2. wrong port number : ~120p", [ConnResp]),
	?assertMatch(#mqtt_client_error{}, ConnResp),

	?PASSED
end}.

connect_2({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_2 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{user_name = "quest"},
		[]
	),	
	
	?debug_Fmt("::test:: 3. wrong user name : ~p Connection Resp:~120p", [ConnRec#connect.user_name, ConnResp]),
	?assertMatch(#mqtt_client_error{}, ConnResp),

	?PASSED
end}.

connect_3({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_3 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{password = <<"gueest">>},
		[]
	),	
	
	?debug_Fmt("::test:: 4. wrong user password : ~120p", [ConnResp]),
	?assertMatch(#mqtt_client_error{}, ConnResp),

	?PASSED
end}.

connect_4({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_4 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec,
		[]
	),	
	
	?debug_Fmt("::test:: 5. duplicate client id: ~p", [ConnResp]),
	?assert(erlang:is_pid(Publisher)),
	Conn = whereis(testClient0),
	?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn]),
	?assertMatch([{connected, 0},_,_], mqtt_client:status(Conn)),

	?PASSED
end}.

connect_5({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_5 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{user_name = binary_to_list(<<"gu", 16#d802:16, "est">>)},
		[]
	),	
	
	?debug_Fmt("::test:: 6. wrong utf-8 : ~p", [ConnResp]),
	?assertMatch(#mqtt_client_error{}, ConnResp),

	?PASSED
end}.

connect_6({Id, connect} = _X, [Publisher] = _Conns) -> {"connect_6 = " ++ atom_to_list(Id) ++ ".", timeout, 100, fun() ->
	ConnRec = testing:get_connect_rec(publisher),	
	ConnResp = mqtt_client:connect(
		Publisher, 
		ConnRec#connect{password = <<"gu", 0, "est">>},
		[]
	),	
	
	?debug_Fmt("::test:: 7. wrong utf-8 : ~p", [ConnResp]),
	?assertMatch(#mqtt_client_error{}, ConnResp),

	?PASSED
end}.

keep_alive(_, Conn) -> {"\n\e[1;34mkeep alive test\e[0m", timeout, 15, fun() ->	
	register(test_result, self()),
	R1 = mqtt_client:pingreq(Conn, {testing, ping_callback}), 
	?assertEqual(ok, R1),
	timer:sleep(4900),
	R2 = mqtt_client:status(Conn), 
	?assertEqual([{connected,1},{session_present,0},{subscriptions,[]}], R2),
	timer:sleep(3000),
	R3 = mqtt_client:status(Conn), 
	?assertEqual([{connected,0},{session_present,0},{subscriptions,[]}], R3),

	unregister(test_result),
	?PASSED
end}.
