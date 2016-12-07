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

%% @hidden
%% @since 2016-09-29
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT session.

-module(session).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

-export([
  session_1/2
]).
-import(testing, [wait_all/1]).
%%
%% API Functions
%%

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_1({1, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips send publish.", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, _Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {F}}]), 
%	?debug_Fmt("::test:: subscribe returns: ~p",[R1_0]),
	?assertEqual({suback,[1]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1. annon. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R2_0]),
	?assertEqual(puback, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1. annon. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_0]),
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","puback timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	Publisher_2 = mqtt_client:connect(
		publisher,
		#connect{
			client_id = "publisher",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 0,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	
  wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher_2),

	?PASSED
end};

%% Publisher: skip recieve publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({2, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips recieve puback.", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, _Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {F}}]), 
%	?debug_Fmt("::test:: subscribe returns: ~p",[R1_0]),
	?assertEqual({suback,[1]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R2_0]),
	?assertEqual(puback, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_rcv_puback}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_0]),
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","puback timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	Publisher_2 = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 0,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	
  wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher_2),

	?PASSED
end};

%% Subscriber: skip recieve publish. Resend publish after reconnect and restore session. Duplicate message.
session_1({3, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips receive publish", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),

	F = fun({{Topic, Q}, _QoS, _Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {F}}]), 
%	?debug_Fmt("::test:: subscribe returns: ~p",[R1_0]),
	?assertEqual({suback,[1]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R2_0]),
	?assertEqual(puback, R2_0),
%	timer:sleep(1000),
	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_0]),
	?assertEqual(puback, R3_0),
%	timer:sleep(1000),
	mqtt_client:disconnect(Subscriber),
%	timer:sleep(1000),
	Subscriber_2 = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 0,
			keep_alive = 60000
		}, 
		"localhost", 
		?TEST_SERVER_PORT,
		{F}, 
		[]
	),
%  ?debug_Fmt("::test:: Subscriber with saved session : ~p", [Subscriber_2]),
	?assert(is_pid(Subscriber_2)),
	R3_1 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_1]),
	?assertEqual(puback, R3_1),
	
  wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber_2),

	?PASSED
end};

%% Subscriber: skip send publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({4, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips send puback.", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, _Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {F}}]), 
%	?debug_Fmt("::test:: subscribe returns: ~p",[R1_0]),
	?assertEqual({suback,[1]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R2_0]),
	?assertEqual(puback, R2_0),
%	timer:sleep(1000),
	gen_server:call(Subscriber, {set_test_flag, skip_send_puback}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_0]),
	?assertEqual(puback, R3_0),
%	timer:sleep(1000),
	mqtt_client:disconnect(Subscriber),
%	timer:sleep(1000),
	Subscriber_2 = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 0,
			keep_alive = 60000
		}, 
		"localhost", 
		?TEST_SERVER_PORT,
		[]
	),
%  ?debug_Fmt("::test:: Subscriber with saved session : ~p", [Subscriber_2]),
	?assert(is_pid(Subscriber_2)),
	R3_1 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_1]),
	?assertEqual(puback, R3_1),
	
  wait_all(4),
%	timer:sleep(1000),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber_2),

	?PASSED
end}.
