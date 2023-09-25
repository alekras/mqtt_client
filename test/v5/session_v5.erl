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

-module(session_v5).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	session_1/2,
	session_2/2,
	session_expire/2,
	msg_expire/2
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
session_1({1, session}, [Publisher, Subscriber]) -> {[$\n] ++ ">>>>>>session QoS=1, publisher skips send publish." ++ [$\n], timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=1}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=1}}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])),

	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"2) Test Payload QoS = 1. annon. function callback. ">>), 
	?assert(wait_events("Skip publish", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),

	?assert(wait_events("After reconnect", [onPublish, onReceive])),
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip recieve publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({2, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips recieve puback.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=1}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])),

	gen_server:call(Publisher, {set_test_flag, skip_rcv_puback}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Skip receive puback", [onError, onReceive])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Publisher, 
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),

	?assert(wait_events("After reconnect", [onPublish, onReceive])),
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip recieve publish. Resend publish after reconnect and restore session. Duplicate message.
session_1({3, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips receive publish", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=1}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message 

	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Skip receive publish", [onPublish])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	?debug_Fmt("::test:: Subscriber with saved session : ~p", [Subscriber]),
	timer:sleep(100),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("After reconnect", [onPublish, onReceive, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip send publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({4, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips send puback.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=1}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message 

	gen_server:call(Subscriber, {set_test_flag, skip_send_puback}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("Skip send puback", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100), %% allow subscriber to disconnect 
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	timer:sleep(100),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	?assert(wait_events("After reconnect", [onPublish, onReceive, onReceive])),
	
	unregister(test_result),
	?PASSED
end}.

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_2({5, session} = _X, [Publisher, Subscriber] = _Conns) -> {[$\n]++" >>>>> session QoS=2, publisher skips send publish."++[$\n], timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Skip send publish", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("After reconnect", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip receive pubrec. Resend publish after reconnect and restore session.
session_2({6, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips receive pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assert(wait_events("Skip receive pubrec", [onError])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	
	?assert(wait_events("After reconnect", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip send pubrel. Resend pubrel after reconnect and restore session.
session_2({7, session}, [Publisher, Subscriber]) -> {"session QoS=2, publisher skips send pubrel.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message
	
	gen_server:call(Publisher, {set_test_flag, skip_send_pubrel}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Skip send pubrel", [onError])),
	
	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:reconnect(
		Publisher,
		[]
	),
	
	?assert(wait_events("After reconnect", [onPublish])), %% @todo check if onReceive event need
	
	unregister(test_result),
	?PASSED
end};

%% Publisher: skip receive pubcomp. Resend publish after reconnect and restore session.
session_2({8, session}, [Publisher, Subscriber]) -> {"session QoS=2, publisher skips receive pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKTest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubcomp}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Skip receive pubcomp", [onError, onReceive])),

	gen_server:call(Publisher, {set_test_flag, undefined}),
	mqtt_client:disconnect(Publisher),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	
%	?assert(wait(0,0,1,0)), % @todo this is wrong test (in server side) !!!
	?assert(wait_events("After reconnect", [onPublish])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip receive publish. Resend publish after reconnect and restore session.
session_2({9, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips receive publish.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Skip receive publish", [onPublish])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0},
		{callback, call},
		[]
	),

	?assert(wait_events("After reconnect", [onReceive])),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 

	?assert(wait_events("After publish", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session.
session_2({10, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Skip send pubrec", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
	?assert(wait_events("After reconnect", [onReceive])),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip receive pubrel. Resend publish after reconnect and restore session.
session_2({11, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips receive pubrel.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_rcv_pubrel}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Skip receive pubrel", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
%	?assert(wait(0,0,0,1)), %% @todo test failed: something wrong!
%	?assert(wait(0,0,0,0)), %% wrong!
	?assert(wait_events("After reconnect", [])),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip send pubcomp. Resend publish after reconnect and restore session.
session_2({12, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 2}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubcomp}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Skip send pubcomp", [onPublish, onReceive])),

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{callback, call},
		[]
	),
%%	?assert(wait(0,0,0,1)), %% @todo did not receive: something wrong!
%	?assert(wait(0,0,0,0)), %% wrong!
	?assert(wait_events("After reconnect", [])),
	?assert(mqtt_client:is_connected(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end}.

session_expire({1, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is not expired.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 16#FFFFFFFF}]
			}, 
		{callback, call},
		[]
	),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onSubscribe, onPublish, onReceive])), %% allow subscriber to receive first message

	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(100), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{
			clean_session = 0,
			keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100), %%  

	?assertMatch([_, {session_present, 1}, _], mqtt_client:status(Subscriber)),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 

	?assert(wait_events("After publish", [onPublish, onReceive])),
	
	unregister(test_result),
	?PASSED
end};

session_expire({2, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is ended.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 0}]
			}, 
		{callback, call},
		[]
	),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onSubscribe, onPublish, onReceive])), %% allow subscriber to receive first message

	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{
			clean_session = 0,
			keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100),
	?assertMatch([_, {session_present, 0}, _], mqtt_client:status(Subscriber)),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish])),

	ok = mqtt_client:disconnect(Subscriber,0,[{?Session_Expiry_Interval, 5}]),
	
	unregister(test_result),
	?PASSED
end};

session_expire({3, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is expire in 1 minutes.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 60}] %% in seconds
			}, 
		{callback, call},
		[]
	),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onSubscribe, onPublish, onReceive])), %% allow subscriber to receive first message

	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(100), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100), %%  

	?assertMatch([_, {session_present, 1}, _], mqtt_client:status(Subscriber)),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish, onReceive])),

	unregister(test_result),
	?PASSED
end};

session_expire({4, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is expire in 1 minutes.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 10}] %% in seconds
			}, 
		{callback, call},
		[]
	),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish", [onSubscribe, onPublish, onReceive])), %% allow subscriber to receive first message

	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(20000),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100),
	?assertMatch([_, {session_present, 0}, _], mqtt_client:status(Subscriber)),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assert(wait_events("After publish", [onPublish])),
	
	unregister(test_result),
	?PASSED
end}.

%% Subscriber: skip_send_pubrec. Resend publish after reconnect and restore session. Testing message Expiry interval.
msg_expire({1, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec to test message expiry interval", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]),
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(
				Publisher,
				#publish{
					topic = "AKtest",
					qos = 2,
					properties=[{?Message_Expiry_Interval, 5}]},
				<<"::1 Test message expiry interval, QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish 1", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(
				Publisher,
				#publish{
					topic = "AKtest",
					qos = 2,
					properties=[{?Message_Expiry_Interval, 5}]},
				<<"::2 Test message expiry interval, QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish 2", [onPublish, onReceive])), %% allow subscriber to receive second message

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(100),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100),
	?assert(mqtt_client:is_connected(Subscriber)),
	
	?assert(wait_events("After reconnect", [onReceive])),
	
	unregister(test_result),
	?PASSED
end};

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session. Testing message Expiry interval.
msg_expire({2, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec to test message expiry interval", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=2}, "AKtest"),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}}]), 
	?assert(wait_events("Subscribe", [onSubscribe])),
	ok = mqtt_client:publish(
				Publisher,
				#publish{
					topic = "AKtest",
					qos = 2,
					properties=[{?Message_Expiry_Interval, 5}]},
				<<"::1 Test message expiry interval, QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish 1", [onPublish, onReceive])), %% allow subscriber to receive first message

	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(
				Publisher,
				#publish{
					topic = "AKtest",
					qos = 2,
					properties=[{?Message_Expiry_Interval, 5}]},
				<<"::2 Test message expiry interval, QoS = 2. function callback. ">>), 
	?assert(wait_events("Publish 2", [onPublish, onReceive])), %% allow subscriber to receive second message

	gen_server:call(Subscriber, {set_test_flag, undefined}),
	mqtt_client:disconnect(Subscriber),
	timer:sleep(10000), %% allow message to expire 
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		{callback, call},
		[]
	),
	timer:sleep(100),
	?assert(mqtt_client:is_connected(Subscriber)),
	
	?assert(wait_events("After reconnect", [])),

	unregister(test_result),
	?PASSED
end}.
