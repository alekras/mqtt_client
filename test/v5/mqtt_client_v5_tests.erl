%%
%% Copyright (C) 2015-2022 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running erlang unit tests.

-module(mqtt_client_v5_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include("test.hrl").

-export([
]).
%%
%% API Functions
%%
mqtt_client_test_() ->
	[ 
		{ setup, 
			fun testing_v5:do_start/0, 
			fun testing_v5:do_stop/1, 
			{inorder, [
				{ foreachx, 
					fun testing_v5:do_setup/1, 
					fun testing_v5:do_cleanup/2, 
					[
						{{testClient0, connect}, fun connect_v5:connect_0/2},
						{{testClient1, connect}, fun connect_v5:connect_1/2},
						{{testClient2, connect}, fun connect_v5:connect_2/2},
						{{testClient3, connect}, fun connect_v5:connect_3/2},
						{{testClient4, connect}, fun connect_v5:connect_4/2},
						{{testClient5, connect}, fun connect_v5:connect_5/2},
						{{testClient6, connect}, fun connect_v5:connect_6/2},
						{{testClient7, connect}, fun connect_v5:reconnect/2},
						{{1, keep_alive},        fun connect_v5:keep_alive/2},

						{{1, combined},    fun subscribe_v5:combined/2},
						{{1, subs_list},   fun subscribe_v5:subs_list/2},
						{{1, subs_filter}, fun subscribe_v5:subs_filter/2},
						{{0, share}, fun share:publish_0/2},
						{{2, share}, fun share:publish_1/2},

						{{2, publish}, fun topic_alias:publish_0/2},
						{{2, publish}, fun topic_alias:publish_1/2},
						{{2, publish}, fun topic_alias:publish_2/2},
						{{2, publish}, fun topic_alias:publish_3/2},

						{{0, publish}, fun publish_v5:publish_0/2},
						{{1, publish}, fun publish_v5:publish_0/2},
						{{2, publish}, fun publish_v5:publish_0/2},
						{{0, publish}, fun publish_v5:publish_1/2},
						{{1, publish}, fun publish_v5:publish_1/2},
						{{2, publish}, fun publish_v5:publish_1/2},

						{{2, publish_rec_max}, fun publish_v5:publish_2/2},

						{{1, session}, fun session_v5:session_1/2},
						{{2, session}, fun session_v5:session_1/2},
						{{3, session}, fun session_v5:session_1/2},
						{{4, session}, fun session_v5:session_1/2},

						{{5, session}, fun session_v5:session_2/2},
						{{6, session}, fun session_v5:session_2/2},
						{{7, session}, fun session_v5:session_2/2},
						{{8, session}, fun session_v5:session_2/2},
						{{9, session}, fun session_v5:session_2/2},
						{{10, session}, fun session_v5:session_2/2},
						{{11, session}, fun session_v5:session_2/2},
						{{12, session}, fun session_v5:session_2/2},
						{{1, session_expire}, fun session_v5:session_expire/2},
						{{2, session_expire}, fun session_v5:session_expire/2},
						{{3, session_expire}, fun session_v5:session_expire/2},
						{{4, session_expire}, fun session_v5:session_expire/2},
						{{1, session}, fun session_v5:msg_expire/2},
						{{2, session}, fun session_v5:msg_expire/2},

						{{0, will}, fun will_v5:will_a/2},
						{{0, will}, fun will_v5:will_0/2},
						{{1, will}, fun will_v5:will_0/2},
						{{2, will}, fun will_v5:will_0/2},
						{{2, will_delay}, fun will_v5:will_delay/2},
						{{1, will_retain}, fun will_v5:will_retain/2},
						{{2, will_retain}, fun will_v5:will_retain/2},

						{{0, retain}, fun retain_v5:retain_0/2},
						{{1, retain}, fun retain_v5:retain_0/2},
						{{2, retain}, fun retain_v5:retain_0/2},
						{{0, retain}, fun retain_v5:retain_1/2},
						{{1, retain}, fun retain_v5:retain_1/2},
						{{2, retain}, fun retain_v5:retain_1/2},
						{{2, retain}, fun retain_v5:retain_2/2},
						{{2, retain}, fun retain_v5:retain_3/2},
						{{2, retain}, fun retain_v5:subscription_option/2},
						{{2, retain}, fun retain_v5:subscription_id/2}
					]
				}
			]}
		}
	].
