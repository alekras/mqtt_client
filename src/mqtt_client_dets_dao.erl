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


-module(mqtt_client_dets_dao).
%%
%% Include files
%%
-include("mqtt_client.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start/0,
	close/0,
	save/1,
	remove/1,
	get/1,
	get_all/1,
  cleanup/1,
  exist/1
]).

start() ->
	Session_DB =
	case dets:open_file(session_db, [{file, "session-db.bin"}, {type, set}, {auto_save, 10000}, {keypos, #storage_publish.key}]) of
		{ok, session_db} ->
			true;
		{error, Reason1} ->
			lager:error("Cannot open session_db dets: ~p~n", [Reason1]),
			false
	end,
	Subscription_DB =
	case dets:open_file(subscription_db, [{file, "subscription-db.bin"}, {type, set}, {auto_save, 10000}, {keypos, #storage_subscription.topic}]) of
		{ok, subscription_db} ->
			true;
		{error, Reason2} ->
			lager:error("Cannot open subscription_db dets: ~p~n", [Reason2]),
			false
	end,
	ConnectionPid_DB =
	case dets:open_file(connectpid_db, [{file, "connectpid-db.bin"}, {type, set}, {auto_save, 10000}, {keypos, #storage_connectpid.client_id}]) of
		{ok, connectpid_db} ->
			true;
		{error, Reason3} ->
			lager:error("Cannot open connectpid_db dets: ~p~n", [Reason3]),
			false
	end,
	(Session_DB and Subscription_DB and ConnectionPid_DB).

save(#storage_publish{key = Key} = Document) ->
	case dets:insert(session_db, Document) of
		{error, Reason} ->
			lager:error("session_db: Insert failed: ~p; reason ~p~n", [Key, Reason]),
			false;
		ok ->
			true
	end;
save(#storage_subscription{topic = Key} = Document) ->
	case dets:insert(subscription_db, Document) of
		{error, Reason} ->
			lager:error("subscription_db: Insert failed: ~p; reason ~p~n", [Key, Reason]),
			false;
		ok ->
			true
	end;
save(#storage_connectpid{client_id = Key} = Document) ->
	case dets:insert(connectpid_db, Document) of
		{error, Reason} ->
			lager:error("connectpid_db: Insert failed: ~p; reason ~p~n", [Key, Reason]),
			false;
		ok ->
			true
	end.

remove(#primary_key{} = Key) ->
	case dets:match_delete(session_db, #storage_publish{key = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Delete is failed for key: ~p with error code: ~p~n", [Key, Reason]),
			false;
		ok -> true
	end;
remove({topic, Key}) ->
	case dets:match_delete(subscription_db, #storage_subscription{topic = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Delete is failed for key: ~p with error code: ~p~n", [Key, Reason]),
			false;
		ok -> true
	end;
remove({client_id, Key}) ->
	case dets:match_delete(session_db, #storage_connectpid{client_id = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Delete is failed for key: ~p with error code: ~p~n", [Key, Reason]),
			false;
		ok -> true
	end.

get(#primary_key{} = Key) ->
	case dets:match_object(session_db, #storage_publish{key = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Get failed: key=~p reason=~p~n", [Key, Reason]),
			undefined;
		[D] -> D;
		U ->
			lager:warning("Unexpected get: ~p for key=~p~n", [U, Key]),
			undefined
	end;
get({topic, Key}) ->
	case dets:match_object(subscription_db, #storage_subscription{topic = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Get failed: key=~p reason=~p~n", [Key, Reason]),
			[];
		[#storage_subscription{document = List}] -> List;
		U ->
			lager:warning("Unexpected get: ~p for key=~p~n", [U, Key]),
			[]
	end;
get({client_id, Key}) ->
	case dets:match_object(connectpid_db, #storage_connectpid{client_id = Key, _ = '_'}) of
		{error, Reason} ->
			lager:error("Get failed: key=~p reason=~p~n", [Key, Reason]),
			undefined;
		[D] -> D;
		U ->
			lager:warning("Unexpected get: ~p for key=~p~n", [U, Key]),
			undefined
	end.

get_all({session, ClientId}) ->
	case dets:match_object(session_db, #storage_publish{key = #primary_key{client_id = ClientId, _ = '_'}, _ = '_'}) of 
		{error, Reason} -> 
			lager:error("match_object failed: ~p~n", [Reason]),
			[];
		R -> R
	end;
get_all(topic) ->
	case dets:match_object(subscription_db, #storage_subscription{_ = '_'}) of 
		{error, Reason} -> 
			lager:error("match_object failed: ~p~n", [Reason]),
			[];
		R -> R
	end.

cleanup(ClientId) ->
	case dets:match_delete(session_db, #storage_publish{key = #primary_key{client_id = ClientId, _ = '_'}, _ = '_'}) of 
		{error, Reason1} -> 
			lager:error("match_delete failed: ~p~n", [Reason1]),
			ok;
		ok -> ok
	end,
	case dets:match_delete(connectpid_db, #storage_connectpid{client_id = ClientId, _ = '_'}) of 
		{error, Reason2} -> 
			lager:error("match_delete failed: ~p~n", [Reason2]),
			ok;
		ok -> ok
	end,
	remove({client_id, ClientId}).

exist(Key) ->
	case dets:member(session_db, Key) of
		{error, Reason} ->
			lager:error("Exist failed: key=~p reason=~p~n", [Key, Reason]),
			false;
		R -> R
	end.

close() -> 
	dets:close(session_db),
	dets:close(subscription_db),
	dets:close(connectpid_db).
%% ====================================================================
%% Internal functions
%% ====================================================================


