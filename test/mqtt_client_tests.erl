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
%% @since 2016-01-03
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running erlang unit tests.

-module(mqtt_client_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

-export([
  connect/0,
  callback/1, 
  ping_callback/1, 
  summer_callback/1, 
  winter_callback/1]).
-import(testing, [wait_all/1]).
%%
%% API Functions
%%
mqtt_client_test_() ->
  [ 
%       {module, mqtt_client_unit_testing},
    { setup, 
      fun testing:do_start/0, 
      fun testing:do_stop/1, 
      {inorder, [
        {test, ?MODULE, connect},
        { foreachx, 
          fun testing:do_setup/1, 
          fun testing:do_cleanup/2, 
          [
            {{1, publish}, fun publish_0/2},
            {{2, publish}, fun publish_1/2},
            {{3, publish}, fun publish_2/2}%,
%%             {{3, subs_list}, fun subs_list/2},
%%             {{4, subs_filter}, fun subs_filter/2}
          ]
        }
      ]}
    }
  ].

connect() ->
	ConnRec = testing:get_connect_rec(),	
	Conn = mqtt_client:connect(
		test_client, 
		ConnRec, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 1. successfully connected : ~p", [Conn]),
	?assert(erlang:is_pid(Conn)),
	
	Conn1 = mqtt_client:connect(
		test_client_1, 
		ConnRec#connect{
			client_id = "test_client_1"
		}, 
		"localhost", 
		3883, 
		[]
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
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 3. wrong user name : ~120p", [Conn2]),
	?assertMatch(#mqtt_client_error{}, Conn2),
	
	Conn3 = mqtt_client:connect(
		test_client_3, 
		ConnRec#connect{
			client_id = "test_client_3",
			user_name = "guest",
			password = <<"gueest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 4. wrong user password : ~120p", [Conn3]),
	?assertMatch(#mqtt_client_error{}, Conn3),
	
	Conn4 = mqtt_client:connect(
		test_client_4, 
		ConnRec, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn4]),
	?assert(erlang:is_pid(Conn4)),
	?assertEqual(disconnected, mqtt_client:status(Conn)),
	
	Conn5 = mqtt_client:connect(
		test_client_5, 
		ConnRec#connect{
			client_id = binary_to_list(<<"test_",255,0,255,"client_5">>),
			user_name = "guest",
			password = <<"guest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 6. wrong utf-8 : ~p", [Conn5]),
%	?assertMatch(#mqtt_client_error{}, Conn5),
	
	Conn6 = mqtt_client:connect(
		test_client_6, 
		ConnRec#connect{
			client_id = "test_client_6",
			user_name = binary_to_list(<<"gu", 0, "est">>),
			password = <<"guest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 7. wrong utf-8 : ~p", [Conn6]),
	?assertMatch(#mqtt_client_error{}, Conn6),
	
	Conn7 = mqtt_client:connect(
		test_client_7, 
		ConnRec#connect{
			client_id = "test_client_7",
			user_name = "guest",
			password = <<"gu", 0, "est">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
  ?debug_Fmt("::test:: 8. wrong utf-8 : ~p", [Conn7]),
	?assertMatch(#mqtt_client_error{}, Conn7),
	
	?PASSED.

publish_0(_, [Publisher, Subscriber] = Conns) -> {timeout, 100, fun() ->
  ?debug_Fmt("::test:: publish_0 : ~p", [Conns]),
	register(test_result, self()),

	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 0, {fun(Arg) -> ?debug_Fmt("::test:: fun callback: ~p",[Arg]), test_result ! done end}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2_0]),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3_0]),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 1) returns: ~p",[R4_0]),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 2) returns: ~p",[R5_0]),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKtest", 0, {?MODULE, callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
%% errors:
	R4 = mqtt_client:publish(Publisher, #publish{topic = binary_to_list(<<"AK",0,0,0,"test">>), qos = 2}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R4]),

	case wait_all(4) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),

	?PASSED
end}.

publish_1(_, [Publisher, Subscriber] = Conns) -> {timeout, 100, fun() ->
  ?debug_Fmt("::test:: publish_1 : ~p", [Conns]),
	register(test_result, self()),

	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {fun(Arg) -> ?debug_Fmt("::test:: fun callback: ~p",[Arg]), test_result ! done end}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2_0]),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3_0]),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 1) returns: ~p",[R4_0]),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 2) returns: ~p",[R5_0]),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {?MODULE, callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),

	case wait_all(4) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),

	?PASSED
end}.

publish_2(_, [Publisher, Subscriber] = Conns) -> {timeout, 100, fun() ->
  ?debug_Fmt("::test:: publish_2 : ~p", [Conns]),
	register(test_result, self()),
  
	F = fun({{Topic, Q}, QoS, _Msg} = Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, {F}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2_0]),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3_0]),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 1) returns: ~p",[R4_0]),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 2) returns: ~p",[R5_0]),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, {?MODULE, callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),

	case wait_all(4) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),

	?PASSED
end}.

connect(_, Conn) -> {timeout, 100, fun() ->
  ?debug_Fmt("::test:: connect : ~p", [Conn]),
	register(test_result, self()),
	timer:sleep(1000),
	R1 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 1st pingreq returns: ~p",[R1]),

	R2_0 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {fun(Arg) -> ?debug_Fmt("::test:: callback: ~p",[Arg]), test_result ! done end}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2_0]),
	R3_0 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3_0]),

	R2 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {?MODULE, callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R4 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 2nd pingreq returns: ~p",[R4]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R6 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 3rd pingreq returns: ~p",[R6]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	R8 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 4th pingreq returns: ~p",[R8]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["AKtest"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	R10 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 5th pingreq returns: ~p",[R10]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(9) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),

	?PASSED
end}.

subs_list(_, Conn) -> {timeout, 100, fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer", 2, {?MODULE, summer_callback}}, {"Winter", 1, {?MODULE, winter_callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to winter.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to summer.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(3) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),
	?PASSED
end}.

subs_filter(_, Conn) -> fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer/+", 2, {?MODULE, summer_callback}}, {"Winter/#", 1, {?MODULE, winter_callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R4 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R4]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(3) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),
	?PASSED
end.

callback(Arg) ->
  ?debug_Fmt("::test:: ~p:callback: ~p",[?MODULE, Arg]),
	test_result ! done.

ping_callback(Arg) ->
  ?debug_Fmt("::test:: ping callback: ~p",[Arg]),
	test_result ! done.

summer_callback(Arg) ->
  ?debug_Fmt("::test:: summer_callback: ~p",[Arg]),
	test_result ! done.

winter_callback(Arg) ->
  ?debug_Fmt("::test:: winter_callback: ~p",[Arg]),
	test_result ! done.
