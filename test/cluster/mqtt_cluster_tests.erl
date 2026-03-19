%%
%% Copyright (C) 2015-2026 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @since 2026-02-04
%% @copyright 2015-2026 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running integration tests for erlang cluster of mqtt servers.

-module(mqtt_cluster_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
	create/1,
	connect/2,
	get_connect_rec/2
]).

%%
%% API Functions
%%
mqtt_cluster_test_() ->
	[{ setup, 
			fun do_start/0, 
			fun do_stop/1, 
			{inorder, [{
					foreachx,
					fun do_setup/1, 
					fun do_cleanup/2, 
					[
						 {{0, publish}, fun mqtt_cluster_client:publish/2}
						,{{1, session}, fun mqtt_cluster_client:session/2}
					]
				}
			]}
	}].

do_start() ->
	?assertEqual(ok, application:start(mqtt_client)),
	?debug_Fmt("~n=============~n Start test on servers: ~p with ports: ~p, ~p, connection type:~p~n=============~n",
						 [?TEST_SERVER_HOST_NAME, ?TEST_SERVER_PORT, ?TEST_SERVER_PORT_1, ?TEST_CONN_TYPE]),
	callback:start().

do_stop(_R) ->
	callback:stop(),
	?assertEqual(ok, application:stop(mqtt_client)).

create(Name) when is_atom(Name) -> 
	Pid = mqtt_client:create(Name),
	?assert(is_pid(Pid)),
	Pid;
create(Name) when is_list(Name) -> 
	Pid = mqtt_client:create(list_to_atom(Name)),
	?assert(is_pid(Pid)),
	Pid.

connect(NodeId, Name) ->
	connect(NodeId, Name, Name).

connect(NodeId, Name, CID) ->
	Pid = create(Name),
	ok = mqtt_client:connect(
		Pid, 
		get_connect_rec(NodeId, CID),
		{callback, call},
		[]
	),
	Pid.

do_setup({_, publish} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[publisher, subscriber];
do_setup({_, session} = _X) ->
	[publisher, subscriber].

do_cleanup({_, publish}, [P, S]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	callback:reset(),
	(get_storage()):cleanup(client);
do_cleanup({_, session}, [P, S]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	callback:reset(),
	(get_storage()):cleanup(client).
	
get_connect_rec(Node_number, Cl_Id) ->
	Port = case Node_number of
		0 -> ?TEST_SERVER_PORT;
		1 -> ?TEST_SERVER_PORT_1;
		_ -> 
			?debug_Fmt("~n::test:: wrong Node Id in cluster: ~p",[Node_number])
	end,
	#connect{
		client_id = Cl_Id,
		host = ?TEST_SERVER_HOST_NAME,
		port = Port,
		user_name = ?TEST_USER, 
		password = ?TEST_PASSWORD, 
		conn_type = ?TEST_CONN_TYPE,
		keep_alive = 600, 
		version = '5.0'}.

get_storage() ->
	case application:get_env(mqtt_common, storage, dets) of
		mysql -> mqtt_mysql_storage;
		dets -> mqtt_dets_storage;
		mnesia -> mqtt_mnesia_storage
	end.
	