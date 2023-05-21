%%
%% Copyright (C) 2015-2023 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_sup.


-module(mqtt_client_sup).
-behaviour(supervisor).
%%
%% Include files
%%
-include_lib("mqtt_common/include/mqtt.hrl").

-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	new_client/1,
	create_client_process/1,
	dispose_client/1
]).

%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor.html#Module:init-1">supervisor:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
	SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
	RestartStrategy :: one_for_all
					 | one_for_one
					 | rest_for_one
					 | simple_one_for_one,
	ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
	StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
	RestartPolicy :: permanent
				   | transient
				   | temporary,
	Modules :: [module()] | dynamic.
%% ====================================================================
init(_) ->
%  io:format(user, " >>> init supervisor~n", []),
  {ok,
    { {one_for_one, 5, 10}, %% Restart strategy
      []
    }
  }.

new_client(Client_id) when is_binary(Client_id) ->
	new_client(binary_to_list(Client_id));
new_client(Client_id) when is_list(Client_id) ->
	new_client(list_to_atom(Client_id));
new_client(Client_id) when is_atom(Client_id)->
	Child_spec = {
		Client_id,
		{?MODULE, create_client_process, [Client_id]},
		permanent,
		brutal_kill,
		worker,
		[mqtt_connection]
	},

	R = try 
				supervisor:start_child(?MODULE, Child_spec) 
			catch
				exit:{noproc, R1} -> 
					{error, #mqtt_client_error{
						type = create, 
						source = "mqtt_client_sup:new_client/1:(line 75)", 
						message= lists:concat("unexpected supervisor:start_child error", R1)
					}}
			end,

	case R of
		{ok, Pid} -> {ok, Pid};
		{ok, Pid, _Info} -> {ok, Pid};
		{error, #mqtt_client_error{} = Reason} -> Reason;
		{error, Reason} -> #mqtt_client_error{
			type = create,
			source = "mqtt_client_sup:new_client/1:(line 75)",
			message = Reason}
	end.

create_client_process(Client_id) ->
	Storage =
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end,

	State = #connection_state{storage = Storage, end_type = client},
	case T = gen_server:start_link({local, Client_id}, mqtt_connection, State, [{timeout, ?MQTT_GEN_SERVER_TIMEOUT}]) of
		{ok, _Pid} -> T;
		{error, {already_started, OtherPid}} -> 
			{error , #mqtt_client_error{
				type = create, 
				source="mqtt_client_sup:create_client_process/1:(line 106)", 
				message = "Already started with PID: " ++ erlang:pid_to_list(OtherPid)
			}};
		{error, Reason} ->
			{error , #mqtt_client_error{
				type = create, 
				source="mqtt_client_sup:create_client_process/1:(line 106)", 
				message = Reason
			}};
		ignore -> ignore
	end.

dispose_client(Client_id) when is_atom(Client_id) -> 
  case supervisor:terminate_child(?MODULE, Client_id) of
    ok -> supervisor:delete_child(?MODULE, Client_id);
    {error, R} -> #mqtt_client_error{type = dispose, message = R}
  end;
dispose_client(Client_id) when is_pid(Client_id) -> 
  case [ Id || {Id, Pid, _, _} <- supervisor:which_children(?MODULE), Pid == Client_id] of
    [Client_atom_id] -> dispose_client(Client_atom_id);
    [] -> ok
  end.

%% ====================================================================
%% Internal functions
%% ====================================================================

