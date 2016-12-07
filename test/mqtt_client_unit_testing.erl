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
%% @since 2016-01-23
%% @copyright 2015-2016 Alexei Krasnopolski
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

input_parser() ->
	?assertEqual({connectack, 1, 0, "0x00 Connection Accepted", <<1:8, 1:8>>}, 
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
	?assertEqual({suback, 103, [7], <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#90:8, 3:8, 103:16, 7:8, 1:8, 1:8>>)),
	?assertEqual({unsuback, 103, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#B0:8, 2:8, 103:16, 1:8, 1:8>>)),
	?assertEqual({pingresp, <<1:8, 1:8>>}, 
							 mqtt_client_input:input_parser(<<16#D0:8, 0:8, 1:8, 1:8>>)),
	?passed.

encode_remaining_length() ->
	?assertEqual(<<45>>, mqtt_client_output:encode_remaining_length(45)),
	?assertEqual(<<161,78>>, mqtt_client_output:encode_remaining_length(10017)),
	?assertEqual(<<142,145,82>>, mqtt_client_output:encode_remaining_length(1345678)),
	?assertEqual(<<206,173,133,85>>, mqtt_client_output:encode_remaining_length(178345678)),
  ?passed.

is_match() ->
	?assert(mqtt_client_connection:is_match("Winter/Feb/23", "Winter/+/23")),
	?assert(mqtt_client_connection:is_match("Season/Spring/Month/March/25", "Season/+/Month/+/25")),
	?assert(mqtt_client_connection:is_match("Winter/Feb/23", "Winter/#")),
	?assert(mqtt_client_connection:is_match("/Feb/23", "/+/23")),
	?passed.
