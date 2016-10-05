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

%% @since 2016-09-08
%% @copyright 2015-2016 Alexei Krasnopolski
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
	case dets:open_file(session_db, [{file, "session-db.bin"}, {type, set}, {auto_save, 10000}, {keypos, #storage_publish.key}]) of
		{ok, session_db} ->
			session_db;
		{error, Reason} ->
			io:format(user, "Cannot open dets: ~p~n", [Reason]),
			undefined
	end.

save(#storage_publish{key = Key} = Document) ->
	case dets:insert(session_db, Document) of
		{error, Reason} ->
			io:format(user, "Insert failed: ~p; reason ~p~n", [Key, Reason]),
			false;
		ok ->
%			io:format(user, "Insert: ~p~n", [Key]),
			true
	end.

remove(Key) ->
	case dets:match_delete(session_db, #storage_publish{key = Key, _ = '_'}) of
		{error, Reason} ->
			io:format(user, "Delete is failed for key: ~p with error code: ~p~n", [Key, Reason]),
			false;
		ok -> true
	end.

get(Key) ->
	case dets:match_object(session_db, #storage_publish{key = Key, _ = '_'}) of
		{error, Reason} ->
			io:format(user, "Get failed: key=~p reason=~p~n", [Key, Reason]),
			undefined;
		[D] -> D;
		U ->
			io:format(user, "Unexpected get: ~p for key=~p~n", [U, Key]),
			undefined
	end.

get_all(ClientId) ->
	case dets:match_object(session_db, #storage_publish{key = #primary_key{client_id = ClientId, _ = '_'}, _ = '_'}) of 
		{error, Reason} -> 
			io:format(user, "match_object failed: ~p~n", [Reason]),
			[];
		R -> R
	end.

cleanup(ClientId) ->
	case dets:match_delete(session_db, #storage_publish{key = #primary_key{client_id = ClientId, _ = '_'}, _ = '_'}) of 
		{error, Reason} -> 
			io:format(user, "match_delete failed: ~p~n", [Reason]),
			ok;
		ok -> ok
	end.

exist(Key) ->
	case dets:member(session_db, Key) of
		{error, Reason} ->
			io:format(user, "Exist failed: key=~p reason=~p~n", [Key, Reason]),
			false;
		R -> R
	end.

close() -> dets:close(session_db).
%% ====================================================================
%% Internal functions
%% ====================================================================


