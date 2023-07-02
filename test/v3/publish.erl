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
%% @doc This module implements a testing of MQTT publish meaasages.

-module(publish).

%%
%% Include files
%%
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
  publish_0/2,
  publish_1/2
]).

-import(testing, [wait_all/1]).

run_test(QoS_subsc, Publisher, Subscriber) ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {[Q],[]} = A) -> ?assertEqual(Q, QoS_subsc), ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onReceive, 
				fun(onReceive, {undefined, #publish{topic= Topic, qos=QoS_pub, dup=_Dup, payload= Msg}} = Arg) -> 
					?debug_Fmt("::test:: onReceive : ~p~n", [Arg]),
					<<QoS_msg:8/integer, _/binary>> = Msg,
%					?assertEqual(QoS_subsc, QoS_recv),
					Expect_QoS = if QoS_subsc > QoS_msg -> QoS_msg; true -> QoS_subsc end,
					?assertEqual(Expect_QoS, QoS_pub),
					?assertEqual("AKTest", Topic),
					test_result ! done
				end),
	callback:set_event_handler(onUnsubscribe, fun(onUnsubscribe, {[],[]} = A) -> ?debug_Fmt("::test:: onUnsubscribe : ~p~n", [A]), test_result ! done end),

	mqtt_client:subscribe(Subscriber, [{"AKTest", QoS_subsc}]),
	?assert(wait_all(1)),
	
	Payload = <<") Test Payload QoS = 0. annon. function callback. ">>,
	[ begin 
			Msg = <<Q:8, Payload/binary>>,
			ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = Q}, Msg) 
		end || Q <- [0,1,2]],
	?assert(wait_all(5)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos=1}, <<"Test Payload QoS = 0.">>), 
	?assert(wait_all(1)),
%% errors:
	ok = mqtt_client:publish(Publisher, #publish{topic = <<"AK",16#d801:16,"Test">>, qos = 2}, <<"Test Payload QoS = 0.">>), %% @todo catch this error: Erlang server @todo - have to fail!!!
%	?assertMatch(#mqtt_error{}, R4), %% Mosquitto server
	ok = mqtt_client:unsubscribe(Subscriber, ["AKTest"]),

	?assert(wait_all(1)),
	unregister(test_result),

	?PASSED
.

publish_0({_, publish}, [Publisher, Subscriber]) -> 
	{"\npublish with QoS = 0,1,2.", 
		timeout, 100, 
		fun() -> 
			[run_test(QoS, Publisher, Subscriber) || QoS <- [0,1,2]]
		end
	}.

publish_1({_QoS, publish}, [Publisher, Subscriber]) -> {"\npublish with QoS = 1", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {[1],[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish : ~p~n", [A]), test_result ! done end),
	Payload = <<"Test Payload QoS = 1. annon. function callback. ">>,
	callback:set_event_handler(onReceive, 
				fun(onReceive, Arg) -> 
					?debug_Fmt("::test:: onReceive : ~p~n", [Arg]),
					?assertMatch(
						{undefined, #publish{topic= "AKtest", payload= <<QoS_exp:8, Payload/binary>>, qos= QoS_exp}},
						Arg), 
					test_result ! done
				end),
	callback:set_event_handler(onUnsubscribe, fun(onUnsubscribe, {[],[]} = A) -> ?debug_Fmt("::test:: onUnsubscribe : ~p~n", [A]), test_result ! done end),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", 1}]), 
	?assert(wait_all(1)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<0:8, Payload/binary>>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<1:8, Payload/binary>>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<1:8, Payload/binary>>), 
	?assert(wait_all(5)),

	callback:set_event_handler(onReceive, 
				fun(onReceive, Arg) -> 
					?debug_Fmt("::test:: onReceive : ~p~n", [Arg]),
					Pay_load = <<"Test Payload QoS = 0.">>,
					?assertMatch(
						{undefined, #publish{topic= "AKTest", payload= Pay_load, qos= 0}},
						Arg), 
					test_result ! done
				end),
	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", 1}]), 
	?assert(wait_all(1)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 0.">>), 
	?assert(wait_all(1)),
	ok = mqtt_client:unsubscribe(Subscriber, ["AKTest"]),
	?assert(wait_all(1)),
	
	unregister(test_result),

	?PASSED
end}.
