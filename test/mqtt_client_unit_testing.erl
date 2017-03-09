%%
%% Copyright (C) 2015-2017 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @since 2016-01-23
%% @copyright 2015-2017 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running unit tests for some modules.

-module(mqtt_client_unit_testing).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

%%
%% Import modules
%%
%-import(helper_common, []).

%%
%% Exported Functions
%%
-export([
]).

%%
%% API Functions
%%

unit_test_() ->
	[ 
		{"decode_remaining_length", fun decode_remaining_length/0},
		{"packet output", fun packet_output/0},
		{"input_parser", fun input_parser/0},
		{"encode_remaining_length", fun encode_remaining_length/0},
		{"is_match", fun is_match/0}
	].

decode_remaining_length() ->
	?assertEqual({<<1, 1>>, 2}, mqtt_client_input:decode_remaining_length(<<2:8, 1:8, 1:8>>)),
	?assertEqual({<<1, 1>>, 2049}, mqtt_client_input:decode_remaining_length(<<16#81:8, 16:8, 1:8, 1:8>>)),
	?assertEqual({<<1, 1>>, 47489}, mqtt_client_input:decode_remaining_length(<<16#81:8, 16#f3:8, 2:8, 1:8, 1:8>>)),
	?assertEqual({<<1, 1>>, 32110977}, mqtt_client_input:decode_remaining_length(<<16#81:8, 16#f3:8, 16#A7, 15:8, 1:8, 1:8>>)),
	?passed.

packet_output() ->
	Value1_1 = mqtt_client_output:packet(
								connect,
								#connect{
									client_id = "publisher",
									user_name = "guest",
									password = <<"guest">>,
									will = 0,
									will_message = <<>>,
									will_topic = [],
									clean_session = 1,
									keep_alive = 1000
								} 
	),
%	io:format(user, " value=~256p~n", [Value1_1]),
	?assertEqual(<<16,35,0,4,"MQTT"/utf8,4,194,3,232,0,9,"publisher"/utf8,0,5,"guest"/utf8,0,5,"guest">>, Value1_1),
	
	Value1_2 = mqtt_client_output:packet(
								connect,
								#connect{
									client_id = "publisher",
									user_name = "guest",
									password = <<"guest">>,
									will = 1,
									will_qos = 2,
									will_retain = 1,
									will_message = <<"Good bye!">>,
									will_topic = "Last_msg",
									clean_session = 1,
									keep_alive = 1000
								} 
	),
%	io:format(user, " value=~256p~n", [Value1_2]),
	?assertEqual(<<16,56,0,4,"MQTT"/utf8,4,246,3,232,0,9,"publisher"/utf8,0,8,"Last_msg"/utf8,0,9,"Good bye!",0,5,"guest"/utf8,0,5,"guest">>, Value1_2),

	Value2 = mqtt_client_output:packet(connack, {1, 2}),
%	io:format(user, " value=~256p~n", [Value2]),
	?assertEqual(<<32,2,1,2>>, Value2),

	Value3 = mqtt_client_output:packet(publish, #publish{topic = "Topic", payload = <<"Test">>}),
%	io:format(user, " value=~256p~n", [Value3]),
	?assertEqual(<<48,11,0,5,84,111,112,105,99,84,101,115,116>>, Value3),

	Value4 = mqtt_client_output:packet(publish, {#publish{topic = "Topic", payload = <<"Test">>}, 100}),
%	io:format(user, " value=~256p~n", [Value4]),
	?assertEqual(<<48,13,0,5,84,111,112,105,99,0,100,84,101,115,116>>, Value4),

	Value5 = mqtt_client_output:packet(subscribe, {[{"Topic_1", 0, 0}, {"Topic_2", 1, 0}, {"Topic_3", 2, 0}], 101}),
%	io:format(user, " value=~256p~n", [Value5]),
	?assertEqual(<<130,32,0,101,0,7,"Topic_1"/utf8,0,0,7,"Topic_2"/utf8,1,0,7,"Topic_3"/utf8,2>>, Value5),

	Value6 = mqtt_client_output:packet(suback, {[0,1,2], 102}),
%	io:format(user, " value=~256p~n", [Value6]),
	?assertEqual(<<144,5,0,102,0,1,2>>, Value6),

	Value7 = mqtt_client_output:packet(unsubscribe, {["Test_topic_1", "Test_topic_2"], 103}),
%	io:format(user, "~n value=~256p~n", [Value7]),
	?assertEqual(<<162,30,0,103,0,12,"Test_topic_1"/utf8,0,12,"Test_topic_2"/utf8>>, Value7),

	Value8 = mqtt_client_output:packet(unsuback, 1205),
%	io:format(user, "~n value=~256p~n", [Value8]),
	?assertEqual(<<176,2,4,181>>, Value8),

	Value9 = mqtt_client_output:packet(disconnect, 0),
%	io:format(user, "~n value=~256p~n", [Value9]),
	?assertEqual(<<224,0>>, Value9),

	Value10 = mqtt_client_output:packet(pingreq, 0),
%	io:format(user, "~n value=~256p~n", [Value10]),
	?assertEqual(<<192,0>>, Value10),

	Value11 = mqtt_client_output:packet(pingresp, 0),
%	io:format(user, "~n value=~256p~n", [Value11]),
	?assertEqual(<<208,0>>, Value11),

	Value12 = mqtt_client_output:packet(puback, 23044),
%	io:format(user, "~n value=~256p~n", [Value12]),
	?assertEqual(<<64,2,90,4>>, Value12),

	Value13 = mqtt_client_output:packet(pubrec, 23045),
%	io:format(user, "~n value=~256p~n", [Value13]),
	?assertEqual(<<80,2,90,5>>, Value13),

	Value14 = mqtt_client_output:packet(pubrel, 23046),
%	io:format(user, "~n value=~256p~n", [Value14]),
	?assertEqual(<<98,2,90,6>>, Value14),

	Value15 = mqtt_client_output:packet(pubcomp, 25046),
%	io:format(user, "~n value=~256p~n", [Value15]),
	?assertEqual(<<112,2,97,214>>, Value15),

  ?passed.

input_parser() ->
	Config = #connect{
						client_id = "publisher",
						user_name = "guest",
						password = <<"guest">>,
						will = 0,
						will_message = <<>>,
						will_topic = [],
						clean_session = 1,
						keep_alive = 1000
					}, 
	?assertEqual({connect, Config, <<7:8,7:8>>}, 
							 mqtt_client_input:input_parser(<<16,35,0,4,"MQTT"/utf8,4,194,3,232,0,9,"publisher"/utf8,0,5,"guest"/utf8,0,5,"guest",7:8,7:8>>)),
	?assertEqual({connack, 1, 0, "0x00 Connection Accepted", <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#20:8, 2:8, 1:8, 0:8, 1:8, 1:8>>)),
	?assertEqual({publish, 0, 0, "Topic", <<1:8, 2:8, 3:8, 4:8, 5:8, 6:8>>, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#30:8, 13:8, 5:16, "Topic", 1:8, 2:8, 3:8, 4:8, 5:8, 6:8, 1:8, 1:8>>)),
	?assertEqual({publish, 1, 100, "Topic", <<1:8, 2:8, 3:8, 4:8, 5:8, 6:8>>, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#32:8, 15:8, 5:16, "Topic", 100:16, 1:8, 2:8, 3:8, 4:8, 5:8, 6:8, 1:8, 1:8>>)),
	?assertEqual({publish, 2, 101, "Топик", <<1:8, 2:8, 3:8, 4:8, 5:8, 6:8>>, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#34:8, 20:8, 10:16, "Топик"/utf8, 101:16, 1:8, 2:8, 3:8, 4:8, 5:8, 6:8, 1:8, 1:8>>)),
	?assertEqual({puback, 101, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#40:8, 2:8, 101:16, 1:8, 1:8>>)),
	?assertEqual({pubrec, 101, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#50:8, 2:8, 101:16, 1:8, 1:8>>)),
	?assertEqual({pubrel, 102, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#62:8, 2:8, 102:16, 1:8, 1:8>>)),
	?assertEqual({pubcomp, 103, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#70:8, 2:8, 103:16, 1:8, 1:8>>)),
	?assertEqual({subscribe, 101, [{<<"Topic_3">>,2},{<<"Topic_2">>,1},{<<"Topic_1">>,0}], <<7:8,7:8>>}, 
							 mqtt_client_input:input_parser(<<130,32,0,101,0,7,"Topic_1"/utf8,0,0,7,"Topic_2"/utf8,1,0,7,"Topic_3"/utf8,2,7,7>>)),
	?assertEqual({suback, 103, [7], <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#90:8, 3:8, 103:16, 7:8, 1:8, 1:8>>)),
	?assertEqual({unsubscribe, 103, [<<"Test_topic_2">>,<<"Test_topic_1">>], <<8:8, 8:8>>}, 
							 mqtt_client_input:input_parser(<<162,30,0,103,0,12,"Test_topic_1"/utf8,0,12,"Test_topic_2"/utf8, 8:8, 8:8>>)),
	?assertEqual({unsuback, 103, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#B0:8, 2:8, 103:16, 1:8, 1:8>>)),
	?assertEqual({pingreq, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<192,0,1:8,1:8>>)),
	?assertEqual({pingresp, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#D0:8, 0:8, 1:8, 1:8>>)),
	?assertEqual({disconnect, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<224, 0, 1:8, 1:8>>)),
	?passed.

encode_remaining_length() ->
	?assertEqual(<<45>>, mqtt_client_output:encode_remaining_length(45)),
	?assertEqual(<<161,78>>, mqtt_client_output:encode_remaining_length(10017)),
	?assertEqual(<<142,145,82>>, mqtt_client_output:encode_remaining_length(1345678)),
	?assertEqual(<<206,173,133,85>>, mqtt_client_output:encode_remaining_length(178345678)),
  ?passed.

is_match() ->
	?assert(mqtt_connection:is_match("Winter/Feb/23", "Winter/+/23")),
	?assert(mqtt_connection:is_match("Season/Spring/Month/March/25", "Season/+/Month/+/25")),
	?assert(mqtt_connection:is_match("Winter/Feb/23", "Winter/#")),
	?assert(mqtt_connection:is_match("/Feb/23", "/+/23")),
	?assert(mqtt_connection:is_match("/Feb/23", "/Feb/23")),
	?assertNot(mqtt_connection:is_match("/Feb/23", "/February/23")),

	?passed.
