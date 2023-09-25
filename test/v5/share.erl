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

-module(share).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	publish_0/2,
	publish_1/2
]).

-import(testing_v5, [wait_events/2]).
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
		?assertEqual("AKTest", T),
		test_result ! onReceive
	end.

publish_0({QoS, share} = _X, [Publisher, Subscriber1, Subscriber2, _, _] = _Conns) -> {"publish to shared Topic with QoS = " ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 1: ~p~n", [A]), test_result ! onSubscribe1 end),
	callback:set_event_handler(1, onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 2: ~p~n", [A]), test_result ! onSubscribe2 end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 1)),
	callback:set_event_handler(1, onReceive, onReceiveCallback(QoS, 2)),

	ok = mqtt_client:subscribe(Subscriber1, [{"$share/A/AKTest", #subscription_options{max_qos = QoS}}]), 
	ok = mqtt_client:subscribe(Subscriber2, [{"$share/A/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("Subscribe", [onSubscribe1, onSubscribe2])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.

publish_1({QoS, share} = _X, [Publisher, Subscriber1, Subscriber2, Subscriber3, Subscriber4] = _Conns) -> {"publish with QoS = " ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 1: ~p~n", [A]), test_result ! onSubscribe1 end),
	callback:set_event_handler(1, onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 2: ~p~n", [A]), test_result ! onSubscribe2 end),
	callback:set_event_handler(2, onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 3: ~p~n", [A]), test_result ! onSubscribe3 end),
	callback:set_event_handler(3, onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe 4: ~p~n", [A]), test_result ! onSubscribe4 end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 1)),
	callback:set_event_handler(1, onReceive, onReceiveCallback(QoS, 2)),
	callback:set_event_handler(2, onReceive, onReceiveCallback(QoS, 3)),
	callback:set_event_handler(3, onReceive, onReceiveCallback(QoS, 4)),

	ok = mqtt_client:subscribe(Subscriber1, [{"$share/A/AKTest", #subscription_options{max_qos = QoS}}]), 
	ok = mqtt_client:subscribe(Subscriber2, [{"$share/A/AKTest", #subscription_options{max_qos = QoS}}]), 
	ok = mqtt_client:subscribe(Subscriber3, [{"$share/B/AKTest", #subscription_options{max_qos = QoS}}]), 
	ok = mqtt_client:subscribe(Subscriber4, [{"$share/B/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("Subscribe", [onSubscribe1, onSubscribe2, onSubscribe3, onSubscribe4])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("Publish", [onReceive, onReceive, onReceive, onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.
