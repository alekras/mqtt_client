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
%% @since 2016-09-29
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT session.

-module(session).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
	session_1/2,
	session_2/2
]).
-import(testing_v5, [wait_events/2]).
%%
%% API Functions
%%
set_handlers(QoS_expected, Topic_expected) ->
	callback:set_event_handler(onSubscribe, fun(onSubscribe, _A) -> test_result ! onSubscribe end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish : ~p~n", [A]), test_result ! onPublish end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! onError end),
	callback:set_event_handler(onReceive, 
				fun(onReceive, {Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = Arg) -> 
					?debug_Fmt("::test:: onReceive : ~p~n", [Arg]),
					 ?assertEqual(QoS_expected, Q),
					 ?assertEqual(Topic_expected, Topic),
					 test_result ! onReceive 
				end).
	
%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_1({1, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips send publish.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(1, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	?assert(wait_events("", [onReceive, onPublish])),

	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"2) Test Payload QoS = 1. annon. function callback. ">>), 
	?assert(wait_events("", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher, 
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("", [onPublish, onReceive])),
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip recieve publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({2, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips recieve puback.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(1, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	gen_server:call(Publisher, {set_test_flag, skip_rcv_puback}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onError, onReceive])),

	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher, 
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),

	?assert(wait_events("", [onPublish, onReceive])),
	unregister(test_result),

	?PASSED
end};

%% Subscriber: skip recieve publish. Resend publish after reconnect and restore session. Duplicate message.
session_1({3, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips receive publish", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(1, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	timer:sleep(500),
	?assert(wait_events("", [onReceive])),
	?debug_Fmt("::test:: Subscriber with saved session : ~p~n", [Subscriber]),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip send publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({4, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips send puback.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(1, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("", [onSubscribe])),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_send_puback}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500), %% allow subscriber to disconnect 
	ok = mqtt_client:connect(
		Subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% @todo have to be 3

	unregister(test_result),

	?PASSED
end}.

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_2({1, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips send publish.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),
	
	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher,
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip receive pubrec. Resend publish after reconnect and restore session.
session_2({2, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips receive pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assert(wait_events("", [onPublish, onReceive])),
	
	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assert(wait_events("", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher,
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("", [onPublish, onReceive])),
	
	unregister(test_result),

	?PASSED
end};

%% Publisher: skip send pubrel. Resend pubrel after reconnect and restore session.
session_2({3, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips send pubrel.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	gen_server:call(Publisher, {set_test_flag, skip_send_pubrel}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher,
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("", [onPublish])),
	
	unregister(test_result),

	?PASSED
end};

%% Publisher: skip receive pubcomp. Resend publish after reconnect and restore session.
session_2({4, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips receive pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>),
	?assert(wait_events("", [onPublish, onReceive])),
	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubcomp}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>),
	?assert(wait_events("", [onError, onReceive])),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Publisher,
		?CONN_REC(publisher)#connect{clean_session = 0},
		{callback, call},
		[]
	),
	
	?assert(wait_events("", [onPublish])), %% @todo this is wrong test (in server side) !!!

	unregister(test_result),

	?PASSED
end};

%% Subscriber: skip receive publish. Resend publish after reconnect and restore session.
session_2({5, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, subscriber skips receive publish.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>),
	?assert(wait_events("", [onPublish, onReceive])),
	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>),
	?assert(wait_events("", [onPublish])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0},
		{callback, call},
		[]
	),
	?assert(wait_events("", [onReceive])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),
	
	unregister(test_result),

	?PASSED
end};

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session.
session_2({6, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, subscriber skips send pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive second message 

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	ok = mqtt_client:connect(
		subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0},
		{callback, call},
		[]
	),
	?assert(wait_events("", [onReceive])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])),
	
	unregister(test_result),

	?PASSED
end};

%% Subscriber: skip receive pubrel. Resend publish after reconnect and restore session.
session_2({7, session}, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, subscriber skips receive pubrel.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive first message 

	gen_server:call(Subscriber, {set_test_flag, skip_rcv_pubrel}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive second message 

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0},
		{callback, call},
		[]
	),
	timer:sleep(500),
%	?assert(wait_events(1)), %% @todo test failed

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% @todo test failed: something wrong!

	unregister(test_result),

	?PASSED
end};

%% Subscriber: skip send pubcomp. Resend publish after reconnect and restore session.
session_2({8, session}, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, subscriber skips send pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(2, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive first message 

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubcomp}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %% allow subscriber to receive second message
	
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	ok = mqtt_client:connect(
		Subscriber, 
		?CONN_REC(subscriber)#connect{clean_session = 0},
		{callback, call},
		[]
	),
	timer:sleep(500),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("", [onPublish, onReceive])), %%
	
	unregister(test_result),

	?PASSED
end}.
