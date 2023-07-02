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
%% @doc This module implements a testing of MQTT subsription.

-module(subscribe_v5).

%%
%% Include files
%%
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	combined/2,
	subs_filter/2,
	subs_list/2
]).
-import(testing_v5, [wait_all/1]).

%%
%% API Functions
%%

combined(_, Conn) -> {"combined", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onPong, fun(onPong, A) -> ?debug_Fmt("::test:: onPong : ~p~n", [A]), test_result ! done end),

	ok = mqtt_client:pingreq(Conn), 
	?assert(wait_all(1)),

	callback:set_event_handler(onReceive, 
		fun(onReceive, {#subscription_options{max_qos= _QOpt}, #publish{qos=Q, topic=T, payload=P, properties=Props}} = A) -> 
			?debug_Fmt("::test:: onReceive : ~p~n", [A]),
			case T of
				"AKtest" -> 
					?assertMatch(Props, [
						{?User_Property, {<<"Key1">>, <<"Value1">>}},
						{?Subscription_Identifier, 21}
					]);
				"AKTst" ->
					?assertMatch(Props, [
						{?User_Property, {<<"Key1">>, <<"Value1">>}}
					]);
				_ -> ?assert(false)
			end,
			case Q of
				0 -> ?assertMatch(P, <<"Test Payload QoS = 0.">>);
				1 -> ?assertMatch(P, <<"Test Payload QoS = 1.">>);
				2 -> ?assertMatch(P, <<"Test Payload QoS = 2.">>)
			end,
			test_result ! done 
		end),
	ok = mqtt_client:subscribe(Conn, [{"AKTst", #subscription_options{max_qos= 0}}]),
	?assert(wait_all(1)),

	ok = mqtt_client:publish(Conn, #publish{topic = "AKTst", properties = [{?User_Property, {"Key1", "Value1"}}]},
														 <<"Test Payload QoS = 0.">>), 
	?assert(wait_all(1)),

	ok = mqtt_client:subscribe(
		Conn, 
		[{"AKtest", #subscription_options{max_qos= 2}}],
		[
			{?Subscription_Identifier, 21},
			{?User_Property, {"Key", "Value"}}
		]
	),
	?assert(wait_all(1)),

	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key1", "Value1"}}]}, <<"Test Payload QoS = 0.">>), 
	?assert(wait_all(1)),
	ok = mqtt_client:pingreq(Conn), 
	?assert(wait_all(1)),
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key1", "Value1"}}], qos = 1}, <<"Test Payload QoS = 1.">>), 
	?assert(wait_all(1)),
	ok = mqtt_client:pingreq(Conn), 
	?assert(wait_all(1)),
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key1", "Value1"}}], qos = 2}, <<"Test Payload QoS = 2.">>), 
	?assert(wait_all(1)),
	ok = mqtt_client:pingreq(Conn), 
	?assert(wait_all(1)),

	callback:set_event_handler(onUnsubscribe, fun(onUnsubscribe, A) -> ?debug_Fmt("::test:: onUnsubscribe : ~p~n", [A]), test_result ! done end),
	ok = mqtt_client:unsubscribe(Conn, ["AKtest"], []), 
	?assert(wait_all(1)),

	ok = mqtt_client:pingreq(Conn), 
	?assert(wait_all(1)),
% does not come
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key1", "Value1"}}], qos = 2}, <<"Test Payload QoS = 2.">>), 
	?assert(wait_all(0)),

	unregister(test_result),
	?passed
end}.

subs_list(_, Conn) -> {"subscribtion list", timeout, 100, fun() ->	
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {[1,2],[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onReceive, 
		fun(onReceive, {#subscription_options{max_qos= _QOpt}, #publish{qos=Q, topic=T, payload=P}} = A) -> 
			?debug_Fmt("::test:: onReceive : ~p~n", [A]),
			?assert(lists:member(T, ["Summer", "Winter"])),
			case T of
				"Winter" -> 
					case Q of
						0 -> ?assertMatch(P, <<"Sent to Winter. QoS = 0.">>);
						1 -> ?assertMatch(P, <<"Sent to Winter. QoS = 1.">>);
						2 -> ?assertMatch(P, <<"Sent to Winter. QoS = 2.">>)
					end;
				"Summer" -> 
					?assertEqual(Q, 1),
					?assertMatch(P, <<"Sent to Summer.">>)
			end,
			test_result ! done
		end),
	callback:set_event_handler(onUnsubscribe, fun(onUnsubscribe, {[0,0],[]} = A) -> ?debug_Fmt("::test:: onUnsubscribe : ~p~n", [A]), test_result ! done end),

	ok = mqtt_client:subscribe(Conn, [{"Summer", #subscription_options{max_qos= 1}}, {"Winter", #subscription_options{max_qos= 2}}]),

	ok = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to Winter. QoS = 0.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to Summer.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 1}, <<"Sent to Winter. QoS = 1.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to Winter. QoS = 2.">>),

	?assert(wait_all(5)),

	ok = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"]), 
	?assert(wait_all(1)),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to Winter. QoS = 2.">>), 
	?assert(wait_all(0)),

	unregister(test_result),
	?PASSED
end}.

subs_filter(_, Conn) -> {"subscription filter", fun() ->	
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {[2,1,0],[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onReceive, 
		fun(onReceive, {#subscription_options{max_qos= _QOpt}, #publish{qos=Q, topic=T, payload=P}} = A) -> 
			?debug_Fmt("    ::test:: onReceive : ~100p~n", [A]),
			case T of
				"Winter/Jan" -> ?assertMatch(P, <<"Sent to Winter/Jan.">>);
				"Summer/Jul" -> 
					?assertEqual(Q, 1),
					?assertMatch(P, <<"Sent to Summer/Jul.">>);
				"Winter/Feb/23" -> 
					?assertEqual(Q, 1),
					?assertMatch(P, <<"Sent to Winter/Feb/23. QoS = 2.">>);
				"Spring/March/Month/08" ->
					?assertEqual(Q, 0),
					?assertMatch(P, <<"Sent to Spring/March/Month/08. QoS = 2.">>);
				"Spring/April/Month/01" ->
					?assertEqual(Q, 0),
					?assertMatch(P, <<"Sent to Spring/April/Month/01. QoS = 1.">>);
				"Spring/May/Month/09" ->
					?assertEqual(Q, 0),
					?assertMatch(P, <<"Sent to Spring/May/Month/09. QoS = 0.">>)
			end,
			test_result ! done
		end),
	callback:set_event_handler(onUnsubscribe, fun(onUnsubscribe, {[0,0,0],[]} = A) -> ?debug_Fmt("::test:: onUnsubscribe : ~p~n", [A]), test_result ! done end),

	ok = mqtt_client:subscribe(Conn, [{"Summer/+", #subscription_options{max_qos= 2}}, 
																		{"Winter/#", #subscription_options{max_qos= 1}},
																		{"Spring/+/Month/+", #subscription_options{max_qos= 0}}
																	 ]), 

	ok = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), %% not delivered 
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 

	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/March/Month/08", qos = 2}, <<"Sent to Spring/March/Month/08. QoS = 2.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/April/Month/01", qos = 1}, <<"Sent to Spring/April/Month/01. QoS = 1.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/May/Month/09", qos = 0}, <<"Sent to Spring/May/Month/09. QoS = 0.">>),

	?assert(wait_all(7)),

	ok = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#", "Spring/+/Month/+"]),
	?assert(wait_all(1)),
	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/May/Month/09", qos = 0}, <<"Sent to Spring/May/Month/09. QoS = 0.">>),
	?assert(wait_all(0)),
	
	unregister(test_result),
	?PASSED
end}.
