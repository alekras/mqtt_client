%%
%% Copyright (C) 2015-2022 by krasnop@bellsouth.net (Alexei Krasnopolski)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%		 http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License. 
%%

%% @hidden
%% @since 2016-01-03
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running erlang unit tests.

-module(mqtt_client_v5_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	callback/1, 
	ping_callback/1, 
	spring_callback/1, 
	summer_callback/1, 
	winter_callback/1]).
-import(testing_v5, [wait_all/1, do_start/0, do_stop/1, do_setup/1, do_cleanup/2, get_connect_rec/0]).
%%
%% API Functions
%%
mqtt_client_test_() ->
	[ 
		{ setup, 
			fun testing_v5:do_start/0, 
			fun testing_v5:do_stop/1, 
			{inorder, [
				{"connect", timeout, 15, fun connect/0},
				{ foreachx, 
					fun testing_v5:do_setup/1, 
					fun testing_v5:do_cleanup/2, 
					[
						{{1, keep_alive}, fun keep_alive/2},
						{{1, combined}, fun combined/2},
						{{1, subs_list}, fun subs_list/2},
						{{1, subs_filter}, fun subs_filter/2},
						{{0, share}, fun share:publish_0/2},
						{{2, share}, fun share:publish_1/2},

						{{2, publish}, fun topic_alias:publish_0/2},
						{{2, publish}, fun topic_alias:publish_1/2},
						{{2, publish}, fun topic_alias:publish_2/2},
						{{2, publish}, fun topic_alias:publish_3/2},

						{{0, publish}, fun publish_v5:publish_0/2},
						{{1, publish}, fun publish_v5:publish_0/2},
						{{2, publish}, fun publish_v5:publish_0/2},
						{{0, publish}, fun publish_v5:publish_1/2},
						{{1, publish}, fun publish_v5:publish_1/2},
						{{2, publish}, fun publish_v5:publish_1/2},

						{{2, publish_rec_max}, fun publish_v5:publish_2/2},

						{{1, session}, fun session_v5:session_1/2},
						{{2, session}, fun session_v5:session_1/2},
						{{3, session}, fun session_v5:session_1/2},
						{{4, session}, fun session_v5:session_1/2},

						{{5, session}, fun session_v5:session_2/2},
						{{6, session}, fun session_v5:session_2/2},
						{{7, session}, fun session_v5:session_2/2},
						{{8, session}, fun session_v5:session_2/2},
						{{9, session}, fun session_v5:session_2/2},
						{{10, session}, fun session_v5:session_2/2},
						{{11, session}, fun session_v5:session_2/2},
						{{12, session}, fun session_v5:session_2/2},
						{{1, session_expire}, fun session_v5:session_expire/2},
						{{2, session_expire}, fun session_v5:session_expire/2},
						{{3, session_expire}, fun session_v5:session_expire/2},
						{{4, session_expire}, fun session_v5:session_expire/2},
						{{1, session}, fun session_v5:msg_expire/2},
						{{2, session}, fun session_v5:msg_expire/2},

						{{0, will}, fun will_v5:will_a/2},
						{{0, will}, fun will_v5:will_0/2},
						{{1, will}, fun will_v5:will_0/2},
						{{2, will}, fun will_v5:will_0/2},
						{{2, will_delay}, fun will_v5:will_delay/2},
						{{1, will_retain}, fun will_v5:will_retain/2},
						{{2, will_retain}, fun will_v5:will_retain/2},

						{{0, retain}, fun retain_v5:retain_0/2},
						{{1, retain}, fun retain_v5:retain_0/2},
						{{2, retain}, fun retain_v5:retain_0/2},
						{{0, retain}, fun retain_v5:retain_1/2},
						{{1, retain}, fun retain_v5:retain_1/2},
						{{2, retain}, fun retain_v5:retain_1/2},
						{{2, retain}, fun retain_v5:retain_2/2},
						{{2, retain}, fun retain_v5:retain_3/2},
						{{2, retain}, fun retain_v5:subscription_option/2},
						{{2, retain}, fun retain_v5:subscription_id/2}
					]
				}
			]}
		}
	].

connect() ->
	ConnRec = (get_connect_rec())#connect{
			properties=[{?Topic_Alias_Maximum,3},{?Request_Problem_Information, 1},{?Request_Response_Information, 1},{?User_Property, {"Key", "Value"}}],
			will = 1,
			will_publish= #publish{qos= 1, retain= 0, topic= "Will_Topic", payload= <<"Msg">>,
														 properties = [{?Payload_Format_Indicator, 1},{?User_Property, {"Key", "Value"}}]}
																			 },
	Conn = mqtt_client:connect(
		test_client, 
		ConnRec, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 1. successfully connected : ~p", [Conn]),
	?assert(erlang:is_pid(Conn)),
	
	Conn1 = mqtt_client:connect(
		test_client_1, 
		ConnRec#connect{
			client_id = "test_client_1"
		}, 
		?TEST_SERVER_HOST_NAME, 
		3883, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 2. wrong port number : ~120p", [Conn1]),
	?assertMatch(#mqtt_client_error{}, Conn1),
	
	Conn2 = mqtt_client:connect(
		test_client_2, 
		ConnRec#connect{
			client_id = "test_client_2",
			user_name = "quest",
			password = <<"guest">>
		}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 3. wrong user name : ~p Connection:~120p", [ConnRec#connect.user_name, Conn2]),
	?assertMatch(#mqtt_client_error{}, Conn2),
	
	Conn3 = mqtt_client:connect(
		test_client_3, 
		ConnRec#connect{
			client_id = "test_client_3",
			user_name = "guest",
			password = <<"gueest">>
		}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 4. wrong user password : ~120p", [Conn3]),
	?assertMatch(#mqtt_client_error{}, Conn3),
	
	Conn4 = mqtt_client:connect(
		test_client_4, 
		ConnRec, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn4]),
	?assert(erlang:is_pid(Conn4)),
	?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn]),
	?assertEqual(disconnected, mqtt_client:status(Conn)),
	
	Conn5 = mqtt_client:connect(
		test_client_5, 
		ConnRec#connect{
			client_id = binary_to_list(<<"test_",255,0,255,"client_5">>),
			user_name = "guest",
			password = <<"guest">>
		}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 6. wrong utf-8 : ~p", [Conn5]),
	?assertNot(erlang:is_pid(Conn5)),
	?assertMatch(#mqtt_client_error{}, Conn5),
	
	Conn6 = mqtt_client:connect(
		test_client_6, 
		ConnRec#connect{
			client_id = "test_client_6",
			user_name = binary_to_list(<<"gu", 0, "est">>),
			password = <<"guest">>
		}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 7. wrong utf-8 : ~p", [Conn6]),
	?assertMatch(#mqtt_client_error{}, Conn6),
	
	Conn7 = mqtt_client:connect(
		test_client_7, 
		ConnRec#connect{
			client_id = "test_client_7",
			user_name = "guest",
			password = <<"gu", 0, "est">>
%%			password = <<"guest">>
		}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]
	),
	?debug_Fmt("::test:: 8. wrong utf-8 : ~p", [Conn7]),
	?assertMatch(#mqtt_client_error{}, Conn7),
	
	?PASSED.

keep_alive(_, Conn) -> {"keep alive test", timeout, 15, fun() ->	
	register(test_result, self()),
	R1 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R1),
	timer:sleep(4900),
	R2 = mqtt_client:status(Conn), 
	?assertEqual([{session_present,0},{subscriptions,[]}], R2),
	timer:sleep(3000),
	R3 = mqtt_client:status(Conn), 
	?assertEqual(disconnected, R3),
	W = wait_all(1),
	unregister(test_result),
	?assert(W),
	?PASSED
end}.

combined(_, Conn) -> {"combined", timeout, 100, fun() ->
	register(test_result, self()),
%	timer:sleep(1000),
	R1 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R1),
	
	R2_0 = mqtt_client:subscribe(Conn, 
			[{"AKtest", 2, 
				fun(Arg) -> ?assertMatch({2,#publish{topic = "AKtest", 
																							properties= [{?User_Property, {<<"Key">>, <<"Value">>}},{?Subscription_Identifier, 21}], 
																							payload= <<"Test Payload QoS = 0. annon. function callback. ">>}}, 
																	Arg), 
										 test_result ! done 
				end
			 }],
			[{?Subscription_Identifier, 21},{?User_Property, {"Key", "Value"}}]
															), 
	?debug_Fmt("::test:: combined->suback : ~p", [R2_0]),
	?assertMatch({suback,[2], _}, R2_0),
	R3_0 = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key", "Value"}}]},
														 <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),

	timer:sleep(100),
	R2 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {?MODULE, callback}}], []), 
	?assertEqual({suback,[2], []}, R2),
	R3 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R3),
	R4 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R4),
	R5 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1.">>), 
	?assertEqual(ok, R5),
	R6 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R6),
	R7 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	?assertEqual(ok, R7),
	R8 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R8),
	timer:sleep(500),
	R9 = mqtt_client:unsubscribe(Conn, ["AKtest"], []), 
	?assertEqual({unsuback, [0], []}, R9),
	R10 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R10),
% does not come
	R11 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	?assertEqual(ok, R11),

	W = wait_all(9),
	
	unregister(test_result),
	?assert(W),

	?passed
end}.

subs_list(_, Conn) -> {"subscribtion list", timeout, 100, fun() ->	
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer", 2, {?MODULE, summer_callback}}, {"Winter", 1, {?MODULE, winter_callback}}], []), 
	?assertEqual({suback,[2,1], []}, R2),
	timer:sleep(100),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to winter. QoS = 0.">>), 
	?assertEqual(ok, R3),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to summer.">>), 
	?assertEqual(ok, R5),
	R6 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 1}, <<"Sent to winter. QoS = 1.">>), 
	?assertEqual(ok, R6),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	?assertEqual(ok, R7),

	W = wait_all(4),

	R8 = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"], []), 
	?assertEqual({unsuback, [0,0], []}, R8),
	timer:sleep(100),
	R9 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	?assertEqual(ok, R9),
	
	W1 = wait_all(1),
	
	unregister(test_result),
	?assert(W),
	?assertNot(W1),

	?PASSED
end}.

subs_filter(_, Conn) -> {"subscription filter", fun() ->	
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer/+", 2, {?MODULE, summer_callback}}, 
																		{"Winter/#", 1, {?MODULE, winter_callback}},
																		{"Spring/+/Month/+", 0, {?MODULE, spring_callback}}
																	 ], []), 
	?assertEqual({suback,[2,1,0], []}, R2),
	timer:sleep(100),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	?assertEqual(ok, R3),
	R4 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), %% not delivered 
	?assertEqual(ok, R4),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	?assertEqual(ok, R5),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 
	?assertEqual(ok, R7),

	R8 = mqtt_client:publish(Conn, #publish{topic = "Spring/March/Month/08", qos = 2}, <<"Sent to Spring/March/Month/08. QoS = 2.">>),
	?assertEqual(ok, R8),
	R9 = mqtt_client:publish(Conn, #publish{topic = "Spring/April/Month/01", qos = 1}, <<"Sent to Spring/April/Month/01. QoS = 1.">>),
	?assertEqual(ok, R9),
	R10 = mqtt_client:publish(Conn, #publish{topic = "Spring/May/Month/09", qos = 0}, <<"Sent to Spring/May/Month/09. QoS = 0.">>),
	?assertEqual(ok, R10),

	W = wait_all(6),

	R12 = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#", "Spring/+/Month/+"], []),
	?assertEqual({unsuback, [0,0,0],[]}, R12),
	
	unregister(test_result),
	?assert(W),
	?PASSED
end}.

callback({_, #publish{qos= QoS}} = Arg) ->
	case QoS of
		0 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 0, payload= <<"Test Payload QoS = 0.">>}}, Arg);
		1 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 1, payload= <<"Test Payload QoS = 1.">>}}, Arg);
		2 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 2, payload= <<"Test Payload QoS = 2.">>}}, Arg)
	end,
	?debug_Fmt("::test:: ~p:callback<_>: ~p",[?MODULE, Arg]),
	test_result ! done.

ping_callback(Arg) ->
%	?debug_Fmt("::test:: ping callback: ~p",[Arg]),
	?assertEqual(pong, Arg),
	test_result ! done.

summer_callback({_, #publish{topic= "Summer/Jul", qos= QoS}} = Arg) ->
	?assertMatch({2,#publish{topic= "Summer/Jul", qos= QoS, payload= <<"Sent to Summer/Jul.">>}}, Arg),
	test_result ! done;
summer_callback({_, #publish{qos= QoS}} = Arg) ->
	?assertMatch({2,#publish{topic= "Summer", qos= QoS, payload= <<"Sent to summer.">>}}, Arg),
	test_result ! done.

winter_callback({ _, #publish{topic= "Winter/Jan", qos= QoS}} = Arg) ->
	?assertMatch({1,#publish{topic= "Winter/Jan", qos= QoS, payload= <<"Sent to Winter/Jan.">>}}, Arg),
	test_result ! done;
winter_callback({_, #publish{topic= "Winter/Feb/23", qos= QoS}} = Arg) ->
	?assertMatch({1,#publish{topic= "Winter/Feb/23", qos= QoS, payload= <<"Sent to Winter/Feb/23. QoS = 2.">>}}, Arg),
	test_result ! done;
winter_callback({_, #publish{qos= QoS}} = Arg) ->
	?assertMatch({1,#publish{topic= "Winter", qos= QoS, payload= <<"Sent to winter. QoS = ", _/binary>>}}, Arg),
	test_result ! done.

spring_callback({_, #publish{topic= "Spring/March/Month/08", qos= QoS}} = Arg) ->
%	?debug_Fmt("::test:: spring_callback: ~p",[Arg]),
	?assertMatch({0,#publish{topic= "Spring/March/Month/08", qos= QoS, payload= <<"Sent to Spring/March/Month/08. QoS = 2.">>}}, Arg),
	test_result ! done;
spring_callback({_, #publish{topic= "Spring/April/Month/01", qos= QoS}} = Arg) ->
%	?debug_Fmt("::test:: spring_callback: ~p",[Arg]),
	?assertMatch({0, #publish{topic= "Spring/April/Month/01", qos= QoS, payload= <<"Sent to Spring/April/Month/01. QoS = 1.">>}}, Arg),
	test_result ! done;
spring_callback({_, #publish{topic= "Spring/May/Month/09", qos= QoS}} = Arg) ->
%	?debug_Fmt("::test:: spring_callback: ~p",[Arg]),
	?assertMatch({0, #publish{topic= "Spring/May/Month/09", qos= QoS, payload= <<"Sent to Spring/May/Month/09. QoS = 0.">>}}, Arg),
	test_result ! done.
