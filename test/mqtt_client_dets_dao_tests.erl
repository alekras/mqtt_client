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
%% @since 2016-09-08
%% @copyright 2015-2017 Alexei Krasnopolski
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
				{"create", fun create/0},
				{"read", fun read/0},
				{"read_all", fun read_all/0},
				{"update", fun update/0},
				{"delete", fun delete/0}
			]
		} 
	].

do_start() ->
	mqtt_client_dets_dao:start(),
	dets:delete_all_objects(session_db),
	dets:delete_all_objects(subscription_db),
	dets:delete_all_objects(connectpid_db).

do_stop(_X) ->
	dets:delete_all_objects(session_db),
	dets:delete_all_objects(session_db),
	dets:delete_all_objects(subscription_db),
	mqtt_client_dets_dao:close().	

create() ->
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 101}, document = #publish{topic = "AK", payload = <<"Payload lemon 1">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = orange, packet_id = 101}, document = #publish{topic = "AK", payload = <<"Payload orange 1">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 10101}, document = #publish{topic = "AK", payload = <<"Payload 2">>}}),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 201}, document = #publish{topic = "AK", payload = <<"Payload 3">>}}),

	mqtt_client_dets_dao:save(#storage_subscription{topic = "AKtest", document = [{"lemon", 0, {erlang, timestamp}}]}),
	mqtt_client_dets_dao:save(#storage_subscription{topic = "Winter/December", document = [{"orange", 1, {length}}]}),

	mqtt_client_dets_dao:save(#storage_connectpid{client_id = "lemon", pid = list_to_pid("<0.4.1>")}),
	mqtt_client_dets_dao:save(#storage_connectpid{client_id = "orange", pid = list_to_pid("<0.4.2>")}),
	mqtt_client_dets_dao:save(#storage_connectpid{client_id = "apple", pid = list_to_pid("<0.4.3>")}),

	R = dets:match_object(session_db, #storage_publish{_ = '_'}),
	?debug_Fmt("::test:: after create ~p", [R]),	
	?assertEqual(4, length(R)),
	R1 = dets:match_object(subscription_db, #storage_subscription{_ = '_'}),
	?debug_Fmt("::test:: after create ~p", [R1]),	
	?assertEqual(2, length(R1)),
	R2 = dets:match_object(connectpid_db, #storage_connectpid{_ = '_'}),
	?debug_Fmt("::test:: after create ~p", [R2]),	
	?assertEqual(3, length(R2)),
	?passed.

read() ->
	R = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 101}),
%	?debug_Fmt("::test:: read returns ~120p", [R]),	
	?assertEqual(#publish{topic = "AK",payload = <<"Payload lemon 1">>}, R#storage_publish.document),
	R1 = mqtt_client_dets_dao:get({topic, "AKtest"}),
%	?debug_Fmt("::test:: read returns ~120p", [R1]),	
	?assertEqual([{"lemon", 0, {erlang, timestamp}}], R1),
	R2 = mqtt_client_dets_dao:get({client_id, "apple"}),
%	?debug_Fmt("::test:: read returns ~120p", [R2]),	
	?assertEqual(list_to_pid("<0.4.3>"), R2#storage_connectpid.pid),
	?passed.
	
read_all() ->
	R = mqtt_client_dets_dao:get_all({session, lemon}),
%	?debug_Fmt("::test:: read returns ~120p", [R]),	
	?assertEqual(3, length(R)),
	?passed.
	
update() ->
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 101}, document = #publish{topic = "", payload = <<>>}}),
	R = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 101}),
%	?debug_Fmt("::test:: read returns ~120p", [R]),
	?assertEqual(#publish{topic = "",payload = <<>>}, R#storage_publish.document),
	mqtt_client_dets_dao:save(#storage_publish{key = #primary_key{client_id = lemon, packet_id = 201}, document = undefined}),
	R1 = mqtt_client_dets_dao:get(#primary_key{client_id = lemon, packet_id = 201}),
%	?debug_Fmt("::test:: read returns ~120p", [R1]),
	?assertEqual(undefined, R1#storage_publish.document),
	?passed.
	
delete() ->
	mqtt_client_dets_dao:remove(#primary_key{client_id = lemon, packet_id = 101}),
	R = dets:match_object(session_db, #storage_publish{_ = '_'}),
%	?debug_Fmt("::test:: after delete ~p", [R]),	
	?assertEqual(3, length(R)),
	?passed.
