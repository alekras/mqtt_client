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

%% @since 2016-09-08
%% @copyright 2015-2017 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to dets_dao.


-module(mqtt_mysql_dao).
%%
%% Include files
%%
-include("mqtt_client.hrl").
-include_lib("mysql_client/include/my.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(MYSQL_SERVER_HOST_NAME, "localhost").
-define(MYSQL_SERVER_PORT, 3306).
-define(MYSQL_USER, "mqtt_user").
-define(MYSQL_PASSWORD, "mqtt_password").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start/0,
	close/0,
	save/1,
	remove/1,
	get/1,
	get_client_topics/1,
	get_matched_topics/1,
	get_all/1,
  cleanup/1,
  cleanup/0,
  exist/1
]).

start() ->
	R = my:start_client(),
	lager:info("Start MySQL ~p",[R]),
	DS_def = #datasource{
		name = mqtt_storage,
		host = ?MYSQL_SERVER_HOST_NAME, 
		port = ?MYSQL_SERVER_PORT, 
		user = ?MYSQL_USER, 
		password = ?MYSQL_PASSWORD, 
		flags = #client_options{}
	},
	case my:new_datasource(DS_def) of
		{ok, Pid} ->
			Conn = datasource:get_connection(mqtt_storage),
  		R1 = connection:execute_query(Conn, "CREATE DATABASE IF NOT EXISTS mqtt_db"),
			lager:debug("create DB: ~p", [R1]),

			Query1 =
				"CREATE TABLE IF NOT EXISTS mqtt_db.session ("
				"client_id char(25) DEFAULT '',"
				" packet_id int DEFAULT 0,"
				" publish_rec blob,"
				" PRIMARY KEY (client_id, packet_id)"
				" ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8",
  		R2 = connection:execute_query(Conn, Query1),
			lager:debug("create session table: ~p", [R2]),

			Query2 =
				"CREATE TABLE IF NOT EXISTS mqtt_db.subscription ("
				"client_id char(25) DEFAULT '',"
				" topic varchar(512) DEFAULT ''," %% @todo make separate table 'topic'. Do I need it at all?
				" topic_re varchar(512),"           %% @todo make separate table 'topic'
				" qos tinyint(1),"
				" callback blob,"
				" PRIMARY KEY (topic, client_id)"
				" ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8",
  		R3 = connection:execute_query(Conn, Query2),
			lager:debug("create subscription table: ~p", [R3]),

			Query3 =
				"CREATE TABLE IF NOT EXISTS mqtt_db.connectpid ("
				"client_id char(25) DEFAULT '',"
				" pid tinyblob,"
				" PRIMARY KEY (client_id)"
				" ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8",
  		R4 = connection:execute_query(Conn, Query3),
			lager:debug("create connectpid table: ~p", [R4]),
  		datasource:return_connection(mqtt_storage, Conn),
			Pid;
		#mysql_error{} -> ok
	end.

save(#storage_publish{key = #primary_key{client_id = Client_Id, packet_id = Packet_Id}, document = Document}) ->
	Query = ["REPLACE INTO mqtt_db.session VALUES ('",
		Client_Id, "',",
		integer_to_list(Packet_Id), ",x'",
		binary_to_hex(term_to_binary(Document)), "')"],
	execute_query(Query);
save(#storage_subscription{key = #subs_primary_key{client_id = Client_Id, topic = Topic}, qos = QoS, callback = CB}) ->
	CBin = term_to_binary(CB),
	Query = ["REPLACE INTO mqtt_db.subscription VALUES ('",
		Client_Id, "','",
		Topic, "','",
		mqtt_client_connection:topic_regexp(Topic), "',",
		integer_to_list(QoS), ",x'",
		binary_to_hex(CBin), "')"],
		execute_query(Query);
save(#storage_connectpid{client_id = Client_Id, pid = Pid}) ->
	Query = ["REPLACE INTO mqtt_db.connectpid VALUES ('",
		Client_Id, "',x'",
		binary_to_hex(term_to_binary(Pid)), "')"],
	execute_query(Query).

remove(#primary_key{client_id = Client_Id, packet_id = Packet_Id}) ->
	Query = ["DELETE FROM mqtt_db.session WHERE client_id='",
		Client_Id, "' and packet_id=",
		integer_to_list(Packet_Id)],
	execute_query(Query);
remove(#subs_primary_key{client_id = Client_Id, topic = Topic}) ->
	Query = ["DELETE FROM mqtt_db.subscription WHERE client_id='",
		Client_Id, "' and topic='",
		Topic, "'"],
	execute_query(Query);
remove({client_id, Client_Id}) ->
	Query = ["DELETE FROM mqtt_db.connectpid WHERE client_id='", Client_Id, "'"],
	execute_query(Query).

get(#primary_key{client_id = Client_Id, packet_id = Packet_Id}) ->
	Query = ["SELECT publish_rec FROM mqtt_db.session WHERE client_id='",
		Client_Id, "' and packet_id=",
		integer_to_list(Packet_Id)],
	case execute_query(Query) of
		[] -> undefined;
		[[R2]] -> #storage_publish{key = #primary_key{client_id = Client_Id, packet_id = Packet_Id}, document = binary_to_term(R2)}
	end;
get(#subs_primary_key{client_id = Client_Id, topic = Topic}) -> %% @todo delete it
	Query = ["SELECT qos, callback FROM mqtt_db.subscription WHERE client_id='",
		Client_Id, "' and topic='",
		Topic, "'"],
	case execute_query(Query) of
		[] -> undefined;
		[[QoS, CB]] -> #storage_subscription{key = #subs_primary_key{topic = Topic, client_id = Client_Id}, qos = QoS, callback = binary_to_term(CB)}
	end;
get({client_id, Client_Id}) ->
	Query = [
		"SELECT pid FROM mqtt_db.connectpid WHERE client_id='",
		Client_Id, "'"],
	case execute_query(Query) of
		[] -> undefined;
		[[Pid]] -> binary_to_term(Pid)
	end.

get_client_topics(Client_Id) ->
	Query = ["SELECT topic, qos, callback FROM mqtt_db.subscription WHERE client_id='", Client_Id, "'"],
	[{Topic, QoS, binary_to_term(Callback)} || [Topic, QoS, Callback] <- execute_query(Query)].

get_matched_topics(#subs_primary_key{topic = Topic, client_id = Client_Id}) ->
	Query = ["SELECT topic,qos,callback FROM mqtt_db.subscription WHERE client_id='",Client_Id,
					 "' and '",Topic,"' REGEXP topic_re"],
	L = execute_query(Query),
	[{TopicFilter, QoS, binary_to_term(CB)} || [TopicFilter, QoS, CB] <- L];
get_matched_topics(Topic) ->
	Query = ["SELECT client_id,topic,qos,callback FROM mqtt_db.subscription WHERE '",Topic,"' REGEXP topic_re"],
	L = execute_query(Query),
	[#storage_subscription{key = #subs_primary_key{client_id = Client_Id, topic = TopicFilter}, qos = QoS, callback = binary_to_term(CB)}
		|| [Client_Id, TopicFilter, QoS, CB] <- L].
	
get_all({session, Client_Id}) ->
	Query = [
		"SELECT client_id, packet_id, publish_rec FROM mqtt_db.session WHERE client_id='",
		Client_Id, "'"],
	R = execute_query(Query),
	[#storage_publish{key = #primary_key{client_id = CI, packet_id = PI}, document = binary_to_term(Publish_Rec)}
		|| [CI, PI, Publish_Rec] <- R];
get_all(topic) ->
	Query = <<"SELECT topic FROM mqtt_db.subscription">>,
	execute_query(Query),
	[T || [T] <- execute_query(Query)].

cleanup(Client_Id) ->
	Conn = datasource:get_connection(mqtt_storage),
  R1 = connection:execute_query(Conn, [
		"DELETE FROM mqtt_db.session WHERE client_id='",
		Client_Id, "'"]),
	lager:debug("session delete: ~p", [R1]),
	R2 = connection:execute_query(Conn, [
		"DELETE FROM mqtt_db.subscription WHERE client_id='",
		Client_Id, "'"]),
	lager:debug("subscription delete: ~p", [R2]),
  R3 = connection:execute_query(Conn, [
		"DELETE FROM mqtt_db.connectpid WHERE client_id='",
		Client_Id, "'"]),
	lager:debug("connectpid delete: ~p", [R3]),
	datasource:return_connection(mqtt_storage, Conn).

cleanup() ->
	Conn = datasource:get_connection(mqtt_storage),
  R1 = connection:execute_query(Conn, "DELETE FROM mqtt_db.session"),
	lager:debug("session delete: ~p", [R1]),
  R2 = connection:execute_query(Conn, "DELETE FROM mqtt_db.subscription"),
	lager:debug("subscription delete: ~p", [R2]),
  R3 = connection:execute_query(Conn, "DELETE FROM mqtt_db.connectpid"),
	lager:debug("connectpid delete: ~p", [R3]),
	datasource:return_connection(mqtt_storage, Conn).

exist(#primary_key{client_id = Client_Id, packet_id = Packet_Id}) ->
	Query = [
		"SELECT packet_id FROM mqtt_db.session WHERE client_id='",
		Client_Id, "' and packet_id=",
		integer_to_list(Packet_Id)],
	case execute_query(Query) of
		[[_]] -> true;
		[] -> false
	end.

close() -> 
	datasource:close(mqtt_storage).
%% ====================================================================
%% Internal functions
%% ====================================================================

execute_query(Query) ->
	Conn = datasource:get_connection(mqtt_storage),
	Rez =
	case connection:execute_query(Conn, Query) of
		{_, R} ->
			lager:debug("Query: ~120p response: ~p", [Query, R]),
			R;
		Other ->
			lager:error("Error with Query: ~120p, ~120p", [Query, Other]),
			[]
	end,
	datasource:return_connection(mqtt_storage, Conn),
	Rez.

binary_to_hex(Binary) ->
[
    if N < 10 -> 48 + N; % 48 = $0
       true   -> 87 + N  % 87 = ($a - 10)
    end
 || <<N:4>> <= Binary].
