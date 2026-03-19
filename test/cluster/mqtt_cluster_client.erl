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
%% @since 2017-01-05
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a testing of MQTT retain meaasages.

-module(mqtt_cluster_client).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	publish/2,
	session/2
]).

-import(callback, [wait_events/2]).
-import(mqtt_cluster_tests, [create/1, connect/2,get_connect_rec/2]).
%%
%% API Functions
%%

onReceiveCallback(QoS, Subscriber) ->
	fun(onReceive, {#subscription_options{max_qos= QOpt}, #publish{qos=Q, topic=T, payload=P, properties=_Props}} = A) -> 
		?debug_Fmt("::test:: onReceive of Subscriber[~p] : ~100p~n", [Subscriber, A]),
		<<QoS_m:1/bytes, _/binary>> = P,
		Msq_QoS = list_to_integer(binary_to_list(QoS_m)),
		?assertEqual(QoS, QOpt),
		Expect_QoS = if QoS > Msq_QoS -> Msq_QoS; true -> QoS end,
		?assertEqual(Expect_QoS, Q),
		?assert(lists:member(T, ["AKTest_0", "AKTest_1"])),
		test_result ! onReceive 
	end.

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

publish({QoS, publish} = _X, [P, S] = _Conns) -> {"publish with QoS = " ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	Publisher = connect(0, P),
	Subscriber = connect(1, S),
	ok = mqtt_client:subscribe(Subscriber, [{"AKTest_1", #subscription_options{max_qos=QoS}}]), 
	ok = mqtt_client:subscribe(Publisher, [{"AKTest_0", #subscription_options{max_qos=QoS}}]), 
	?assert(wait_events("", [onSubscribe, onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest_1", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest_1", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest_1", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 

	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKTest_0", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKTest_0", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKTest_0", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onReceive, onReceive, onReceive, onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session({1, session}, [P, S]) -> {[$\n] ++ ">>>>>>session QoS=1, publisher skips send publish." ++ [$\n], timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=1}, "AKtest"),

	Publisher = create(P),
	ok = mqtt_client:connect(
		Publisher, 
		(get_connect_rec(0, P))#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		{callback, call},
		[]
	),
	?assert(is_pid(Publisher)),
	Subscriber = create(S),
	ok = mqtt_client:connect(
		Subscriber, 
		(get_connect_rec(1, S))#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		{callback, call},
		[]
	),
	?assert(is_pid(Subscriber)),

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
		(get_connect_rec(1, P))#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		{callback, call},
		[]
	),

	?assert(wait_events("After reconnect", [onPublish, onReceive])),
	unregister(test_result),
	?PASSED
end}.

