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
%% @since 2016-09-08
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running unit tests for some modules.

-module(mqtt_client_dets_dao_tests).

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

dets_dao_test_() ->
	[
		{ setup,
			fun do_start/0,
			fun do_stop/1,
			[
				fun create/0,
				fun read/0,
				fun read_all/0,
				fun update/0,
				fun delete/0
			]
		} 
	].

do_start() ->
	mqtt_client_dets_dao:start().

do_stop(X) ->
	mqtt_client_dets_dao:close(),
	?debug_Fmt("::test:: clean up ~p", [X]).	

create() ->
	?debug_Msg("::test:: create."),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 101}, document = #publish{topic = "AK", payload = <<"Payload lemon 1">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = orange, packet_id = 101}, document = #publish{topic = "AK", payload = <<"Payload orange 1">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 10101}, document = #publish{topic = "AK", payload = <<"Payload 2">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 201}, document = #publish{topic = "AK", payload = <<"Payload 3">>}}),
	R = dets:match_object(session_db, #storage_publish{_ = '_'}),
	?debug_Fmt("::test:: after create ~p", [R]),	
	?assertEqual(4, length(R)),
	?PASSED.
	
read() ->
	?debug_Msg("::test:: read."),
	R = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 101}),
	?debug_Fmt("::test:: read returns ~120p", [R]),	
	?assertEqual(#publish{topic = "AK",payload = <<"Payload lemon 1">>}, R#storage_publish.document),
  ?PASSED.
	
read_all() ->
	?debug_Msg("::test:: read ALL."),
	R = mqtt_client_dets_dao:get_all(lemon),
	?debug_Fmt("::test:: read returns ~120p", [R]),	
	?assertEqual(3, length(R)),
  ?PASSED.
	
update() ->
	?debug_Msg("::test:: update."),	
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 101}, document = #publish{topic = "", payload = <<>>}}),
	R = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 101}),
	?debug_Fmt("::test:: read returns ~120p", [R]),
	?assertEqual(#publish{topic = "",payload = <<>>}, R#storage_publish.document),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 201}, document = undefined}),
	R1 = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 201}),
	?debug_Fmt("::test:: read returns ~120p", [R1]),
	?assertEqual(undefined, R1#storage_publish.document),
  ?PASSED.
	
delete() ->
	?debug_Msg("::test:: delete."),
	mqtt_client_dets_dao:remove(#primary_key{client_id = lemon, packet_id = 101}),
	R = dets:match_object(session_db, #storage_publish{_ = '_'}),
	?debug_Fmt("::test:: after delete ~p", [R]),	
	?assertEqual(3, length(R)),
  ?PASSED.

