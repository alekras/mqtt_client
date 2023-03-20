%%
%% Copyright (C) 2015-2022 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to testing.


-module(testing_v5).
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-define(CONN_REC(X), (#connect{
		client_id = X,
		host = ?TEST_SERVER_HOST_NAME,
		port = ?TEST_SERVER_PORT,
		user_name = ?TEST_USER, 
		password = ?TEST_PASSWORD, 
		conn_type = ?TEST_CONN_TYPE,
		keep_alive = 600, 
		version = '5.0'})
).

%%
%% API functions
%%
-export([
	do_setup/1, 
	do_cleanup/2, 
	do_start/0, 
	do_stop/1,
	get_connect_rec/1, 
	wait_all/1,
	callback/1, 
	ping_callback/1, 
	spring_callback/1, 
	summer_callback/1, 
	winter_callback/1
]).

do_start() ->
	?debug_Fmt("~n=============~n Start test on server: ~p:~p, connection type:~p~n=============~n",
						 [?TEST_SERVER_HOST_NAME, ?TEST_SERVER_PORT, ?TEST_CONN_TYPE]),
	?assertEqual(ok, application:start(mqtt_client)).

do_stop(_R) ->
	?assertEqual(ok, application:stop(mqtt_client)).

create(Name) when is_atom(Name) -> mqtt_client:create(Name);
create(Name) when is_list(Name) -> mqtt_client:create(list_to_atom(Name)).

connect(Name) ->
	connect(Name, Name).

connect(Name, CID) ->
	Pid = create(Name),
	?assert(is_pid(Pid)),
	ok = mqtt_client:connect(
		Pid, 
		?CONN_REC(CID)#connect{properties=[{?Topic_Alias_Maximum,10}]}, 
		[]
	),
%	?debug_Fmt("~n::test:: connect: ~p",[Pid]),
	Pid.

do_setup({Client_Id, connect} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[create(Client_Id)];
do_setup({_, publish}) ->
	[connect(publisher), connect(subscriber)];
do_setup({_, publish_rec_max} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{properties=[{?Receive_Maximum, 5}]}, 
		[]
	),
	?assert(is_pid(P1)),
	[P1, connect(subscriber)];
do_setup({_, share}) ->
	[connect(publisher), connect(subscriber1), connect(subscriber2), connect(subscriber3), connect(subscriber4)];
do_setup({_, session}) ->
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		[]
	),
	?assert(is_pid(P1)),
	S1 = create(subscriber),
	ok = mqtt_client:connect(
		S1, 
		?CONN_REC(subscriber)#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		[]
	),
	?assert(is_pid(S1)),
	[P1, S1];
do_setup({_, session_expire}) ->
	[create(subscriber)];
do_setup({QoS, will}) ->
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				topic= "AK_will_test",
				payload= <<"Test will message">>
			}
		}, 
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({QoS, will_delay}) ->
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				topic= "AK_will_test",
				payload= <<"Test will message">>,
				properties =[{?Will_Delay_Interval, 5}]}
		}, 
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({QoS, will_retain}) ->
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				retain= 1,
				topic= "AK_will_retain_test",
				payload= <<"Test will retain message">>
			}
		}, 
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber), create(subscriber2)];
do_setup({_QoS, retain}) ->
	[connect(publisher), connect(subscriber1), connect(subscriber2)];
do_setup({_, keep_alive}) ->
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{keep_alive = 5}, 
		[]
	),
	?assert(is_pid(P)),
	P;
do_setup(_X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	connect(publisher).

do_cleanup({testClient0, connect}, [_P]) ->
	ok;
do_cleanup({_, connect}, [P]) ->
	ok = mqtt_client:dispose(P);
do_cleanup({_, Tag} = _X, [P, S] = _Pids) when Tag == publish; Tag == publish_rec_max ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({_, share}, [P, S1, S2, S3, S4]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),
	ok = mqtt_client:dispose(S3),
	ok = mqtt_client:dispose(S4),
	(get_storage()):cleanup(client);
do_cleanup({_, session}, [P1, S1]) ->
	ok = mqtt_client:dispose(P1),
	ok = mqtt_client:dispose(S1),
	(get_storage()):cleanup(client);
do_cleanup({_, session_expire}, [S]) ->
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({_QoS, Tag}, [P, S]) when Tag == will; Tag == will_delay ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({QoS, will_retain}, [P, S1, S2]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),

	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{
			clean_session = 1
		}, 
		[]
	),
	ok = mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = QoS}, <<>>), 
	ok = mqtt_client:dispose(P1),

	(get_storage()):cleanup(client);
do_cleanup({QoS, retain}, [P1, S1, S2]) ->
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),
	ok = case mqtt_client:status(P1) of
		disconnected ->
			P2 = create(publisher),
			ok = mqtt_client:connect(
				P2, 
				?CONN_REC(publisher)#connect{clean_session = 0}, 
				[]
			),
			ok = mqtt_client:publish(P2, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P2);
		[{connected, true}, _, _] ->
			ok = mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P1);
		_ ->
			ok = mqtt_client:connect(
				P1, 
				?CONN_REC(publisher)#connect{clean_session = 0},
				[]
			),
			ok = mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P1)
	end,
	(get_storage()):cleanup(client);
do_cleanup(_X, _Pids) ->
	ok = mqtt_client:dispose(publisher),
	(get_storage()):cleanup(client).

get_connect_rec(Cl_Id) ->
	?CONN_REC(Cl_Id).

get_storage() ->
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end.
	
wait_all(N) ->
	case wait_all(N, 0) of
		{ok, _M} -> 
%			?debug_Fmt("::test:: all ~p done received.", [_M]),
			true;
		{fail, _T} -> 
			?debug_Fmt("::test:: ~p done have not received.", [N - _T]), 
			false
%			?assert(true)
	end
	and
	case wait_all(100, 0) of
		{fail, 0} -> 
%			?debug_Fmt("::test:: ~p unexpected done received.", [0]),
			true;
		{fail, _Z} -> 
			?debug_Fmt("::test:: ~p unexpected done received.", [_Z]),
			false;
		{ok, _R} -> 
			?debug_Fmt("::test:: ~p unexpected done received.", [_R]), 
			false
%			?assert(true)
	end.

wait_all(0, M) -> {ok, M};
wait_all(N, M) ->
	receive
		done -> wait_all(N - 1, M + 1)
	after 500 -> {fail, M}
	end.

callback({0, #publish{topic= "AKTest", qos= QoS}} = Arg) ->
	case QoS of
		0 -> ?assertMatch({0, #publish{topic= "AKTest", qos= 0, payload= <<"Test Payload QoS = 0.">>}}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback<0>: ~p",[?MODULE, Arg]),
	test_result ! done;
callback({1, #publish{topic= "AKTest", qos= QoS}} = Arg) ->
	case QoS of
		0 -> ?assertMatch({1, #publish{topic= "AKTest", qos= 0, payload= <<"Test Payload QoS = 0.">>}}, Arg);
		1 -> ?assertMatch({1, #publish{topic= "AKTest", qos= 1, payload= <<"Test Payload QoS = 1.">>}}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback<1>: ~p",[?MODULE, Arg]),
	test_result ! done;
callback({2, #publish{topic= "AKTest", qos= QoS}} = Arg) ->
	case QoS of
		0 -> ?assertMatch({2, #publish{topic= "AKTest", qos= 0, payload= <<"Test Payload QoS = 0.">>}}, Arg);
		1 -> ?assertMatch({2, #publish{topic= "AKTest", qos= 1, payload= <<"Test Payload QoS = 2.">>}}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback<2>: ~p",[?MODULE, Arg]),
	test_result ! done;
callback({_, #publish{qos= QoS}} = Arg) ->
	case QoS of
		0 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 0, payload= <<"Test Payload QoS = 0.">>}}, Arg);
		1 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 1, payload= <<"Test Payload QoS = 1.">>}}, Arg);
		2 -> ?assertMatch({2, #publish{topic= "AKtest", qos= 2, payload= <<"Test Payload QoS = 2.">>}}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback<_>: ~p",[?MODULE, Arg]),
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
