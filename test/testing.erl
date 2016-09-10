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

%% @since 2015-12-25
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to testing.


-module(testing).
-include_lib("eunit/include/eunit.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

%%
%% API functions
%%
-export([
	do_setup/1, 
	do_cleanup/2, 
	do_start/0, 
	do_stop/1,
	get_connect_rec/0, 
	wait_all/1]).

do_start() ->
  R = application:start(mqtt_client),
  ?debug_Fmt("::test:: start app return: ~p",[R]).

do_stop(_R) ->
  ?debug_Fmt("::test:: stop app ~p",[_R]),
  R = application:stop(mqtt_client),
  ?debug_Fmt("::test:: stop app return: ~p",[R]).

do_setup({_, publish} = X) ->
  ?debug_Fmt("::test:: setup before: ~p~n",[X]),
	P = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
		S = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	[P,S];
do_setup(X) ->
  ?debug_Fmt("::test:: setup before: ~p~n",[X]),
	mqtt_client:connect(
		test_cli, 
		#connect{
			client_id = "test_cli",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	).

do_cleanup({_, publish} = X, [P, S] = Pid) ->
	R1 = mqtt_client:disconnect(P),
	R2 = mqtt_client:disconnect(S),
  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~p~n",[X, Pid, {R1, R2}]);
do_cleanup(X, Pid) ->
	R = mqtt_client:disconnect(test_cli),
  ?debug_Fmt("::test:: teardown after: ~p  pid=~p  disconnect returns=~p~n",[X, Pid, R]).

get_connect_rec() ->
	#connect{
		client_id = "test_client",
		user_name = "guest",
		password = <<"guest">>,
		will = 0,
		will_message = <<>>,
		will_topic = [],
		clean_session = 1,
		keep_alive = 1000
	}.

wait_all(0) -> ok;
wait_all(N) ->
	receive
		done -> wait_all(N - 1)
	after 1000 -> fail
	end.
