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

%% @since 2015-12-25
%% @copyright 2015-2017 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_sup.


-module(mqtt_client_sup).
-behaviour(supervisor).
%%
%% Include files
%%
-include("mqtt_client.hrl").

-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	new_connection/4
%	close_connection/1
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

%% Connection_id::atom()
new_connection(Connection_id, Host, Port, Options) ->
  Child_spec = {
    Connection_id,
    {gen_server, start_link,
      [{local, Connection_id}, mqtt_client_connection, {Host, Port, Options}, [{timeout, ?MQTT_GEN_SERVER_TIMEOUT}]]
    },
    temporary,
    brutal_kill,
    worker,
    [mqtt_client_connection]
  },

  R = try 
				supervisor:start_child(?MODULE, Child_spec) 
			catch
				exit:{noproc,_R1} -> 
					{error, {#mqtt_client_error{type=connection, message="unexpected server connection drop"}, undef}}
			end,
  case R of
    {ok, _Pid} -> R;
    {ok, Pid, _Info} -> {ok, Pid};
    {error, {#mqtt_client_error{} = Reason, _}} -> Reason;
    {error, Reason} -> #mqtt_client_error{
                                    type = connection,
                                    message = Reason}
  end.

%% close_connection(Connection_id) when is_atom(Connection_id) -> 
%%   io:format(user, " >>> close_connection (id:~p)~n", [Connection_id]),
%%   case supervisor:terminate_child(?MODULE, Connection_id) of
%%     ok -> supervisor:delete_child(?MODULE, Connection_id);
%%     {error, R} -> #mqtt_client_error{type = connection, message = atom_to_list(R)}
%%   end;
%% 
%% close_connection(Connection_pid) when is_pid(Connection_pid) -> 
%%   io:format(user, " >>> close_connection (pid:~p)~n", [Connection_pid]),
%%   case [ Id || {Id, Pid, _, _} <- supervisor:which_children(?MODULE), Pid == Connection_pid] of
%%     [Connection_id] -> close_connection(Connection_id);
%%     [] -> ok
%%   end.

%% ====================================================================
%% Internal functions
%% ====================================================================

