%%
%% Copyright (C) 2015-2023 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @since 2016-01-03
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running erlang unit tests.

-module(mqtt_client_debug_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([]).
%%
%% API Functions
%%
mqtt_client_test_() ->
	[ 
		{ setup, 
			fun testing:do_start/0, 
			fun testing:do_stop/1, 
			{inorder, [
				{ foreachx, 
					fun testing:do_setup/1, 
					fun testing:do_cleanup/2, 
					[
						{{testClient0, connect}, fun connect:connect_0/2},
						{{testClient1, connect}, fun connect:connect_1/2},
						{{testClient2, connect}, fun connect:connect_2/2},
						{{testClient3, connect}, fun connect:connect_3/2},
						{{testClient4, connect}, fun connect:connect_4/2},
						{{testClient5, connect}, fun connect:connect_5/2},
						{{testClient6, connect}, fun connect:connect_6/2},
						{{testClient7, connect}, fun connect:reconnect/2},
						{{1, keep_alive},        fun connect:keep_alive/2}
					]
				}
			]}
		}
	].
