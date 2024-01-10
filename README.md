## Introduction
The client allows to connect to MQTT server and send/receive messages according to MQTT messaging protocol versions 3.1, 3.1.1 and 5.0.
The client is written in Erlang. 
The client was tested with RabbitMQ and Mosquitto server on Windows/Linux/MacOSX boxes.

## Architecture
MQTT client is an OTP application. Top level component is supervisor
that is monitoring a child connection processes so the client keeps connections to different servers concurrently. Session state data are storing in database (DETS and MySQL in current version)

## Getting started
### Installation
To start with the client you have to complete three steps below:

1. Install [Mosquitto](https://mosquitto.org/) or [RabbitMQ](https://www.rabbitmq.com/) (with MQTT plugin) server.
2. Install [Erlang](http://www.erlang.org/download.html).
3. Install [Rebar3](https://www.rebar3.org/).


### Building
#### Download or clone from Github
To get the client code from GIT repository type command 

```bash
git clone https://git.code.sf.net/p/mqtt-client/code erl.mqtt.client
```
to clone from SourceForge GIT repository. For GitHub repository type

```bash
git clone https://github.com/alekras/mqtt_client.git erl.mqtt.client
```
Under folder erl.mqtt.client exists an Eclipse project. You do not need to use Eclipse to build the client but 
if you want you can use convenience of Eclipse and Erlide plugin.

#### Compiling
After you have got source code of the client then change directory to the erl.mqtt.client:

```bash
cd erl.mqtt.client
```
Run rebar3 for this project. You have to add path to rebar3 to OS PATH variable or just use the whole path:

```bash
/opt/local/bin/rebar3 compile
```
Rebar will fetch code of all dependencies and compile source files of main project and all dependencies.

### Testing
Next step is running the examples. For testing we need to run MQTT server locally or use external servers running outside in Internet.
 1. Suppose you install Mosquitto MQTT server as 'localhost' that opened 1883 port 
for listening a TCP/IP connections from clients.
You have to setup 'quest' account with 'guest' password.
 2. You can connect to public available MQTT server broker.hivemq.com with ports:
  - clear tcp: 1883
  - ssl/tls: 8883
  - websocet (ws): 8000
  - secure websocket: 8884
 3. Other public MQTT Broker broker.emqx.io has ports:
  - clear tcp: 1883
  - ssl/tls: 8883
  - websocket (ws): 8083
  - secure websocket: 8084
 4. Erlang MQTT server is running on lucky3p.com with ports:
  - websocket (ws): 8880 (we will use this configuration for below examples)
  - secure websocket: 4443

We will test the client from Erlang shell:

```bash
erl -pa _build/default/lib/*/ebin
```

## Run application
After we start Erlang shell for testing we need to start application 'mqtt_client' that represents describing client.

```erlang
1> application:start(mqtt_client).
20:17:18.656 [info] running apps: [{mqtt_common,"MQTT common library","2.1.0"},{sasl,"SASL  CXC 138 11","4.1.2"},{lager,"Erlang logging framework","3.9.2"},
{goldrush,"Erlang event stream processor","0.1.9"},{compiler,"ERTS  CXC 138 10","8.1.1.3"},{syntax_tools,"Syntax tools","2.6"},{stdlib,"ERTS  CXC 138 10","3.17.2.2"},{kernel,"ERTS  CXC 138 10","8.3.2.3"}]
ok
```
Load records definitions to console environment. This is not required operation but it makes our next steps more easy and clear 
by using defined records in mqtt.hrl:

```erlang
2> rr("_build/default/lib/mqtt_common/include/mqtt.hrl").
[connect,connection_state,primary_key,publish,session_state,
 sslsocket,storage_connectpid,storage_publish,storage_retain,
 storage_subscription,subs_primary_key,subscription_options,
 user]
```
It is time to create client process. We will register the process under name 'publisher':

```erlang
3> Client_pid = mqtt_client:create(publisher).
<0.148.0>
```
We can use in following steps either 'publisher' registered name or Client_pid.

## Connection
Record #connect encapsulates connection information needed to connect to MQTT server.
Assign record #connect{} to Conn_def value:

```erlang
4> Conn_def = #connect{
4> client_id = "publisher",
4) host = "lucky3p.com",
4) port = 8880,
4) version = '5.0',
4) conn_type = web_socket,
4> user_name = "guest",
4> password = <<"guest">>,
4> clean_session = 1
4> }.
#connect{client_id = "publisher",user_name = "guest",
         password = <<"guest">>,will = 0,will_qos = 0,
         will_retain = 0,will_topic = [],will_message = <<>>,
         clean_session = 1,keep_alive = 1000}
```
And finally create new connection to MQTT server at lucky3p.com:8880 

```erlang
5> ok = mqtt_client:connect(publisher, Conn_def, fun(Event, Argument) ->  io:fwrite(user,"Publisher:: Event:~p Arg:~p~n", [Event, Argument]) end).
ok
```
We have client with name = 'publisher' (or PID = <0.148.0>) connected to MQTT server now.
We define callback function (CBF) for this connection. This function will act as 'application' 
from MQTT protocol terminology. When client receives message or some event
from server then callback function will be invoked and the message will be passed to it.
See detailed explanation of CBF below.

Let's create one more client with different client Id and connect to the same MQTT server:

```erlang
6> Client_pid_subs = mqtt_client:create(subscriber).
<0.149.0>
6> Conn_def_subs = Conn_def#connect{client_id = "subscriber"}.
#connect{client_id = "subscriber",user_name = "guest",
         password = <<"guest">>,will = 0,will_qos = 0,
         will_retain = 0,will_topic = [],will_message = <<>>,
         clean_session = 1,keep_alive = 1000}
7> ok = mqtt_client:connect(subscriber, Conn_def_subs, fun(Event, Argument) ->  io:fwrite(user,"Subscriber:: Event:~p Arg:~p~n", [Event, Argument]) end).
ok
```
## TLS/SSL and Web socket Connection

To establish TCP connection secured by TLS/SSL or web-socket connection 
we need to assign to record field #connect.conn_type a corresponded value:

conn_type description
'clear'
'ssl' or 'tls' 
'web_socket' 
'web_sec_socket'

Note that we need to set up corresponded port. How configure Mosquitto server
[see here](https://dzone.com/articles/secure-communication-with-tls-and-the-mosquitto-broker/).
If we want to pass additional properties to SSL application on client side we can do it using options list:

```erlang
7> ok = mqtt_client:connect(subscriber, Conn_def_subs, [{certfile,"client.crt"}, {verify, verify_none}]).
```

## Subscribe and publish
To finish set up of the connection we need to subscribe it to some topic for example "Test" topic. .

```erlang
8> CBF = fun(Arg) -> io:format(user,"callback function: ~p",[Arg]) end.
#Fun<erl_eval.6.52032458>
9> mqtt_client:subscribe(SubCon, [{"Test", 1, CBF}]).
{suback,[1]}
```
Now we can publish message to "Test" topic. After short moment subscriber receives this message and fire callback function:

```erlang
10> mqtt_client:publish(PubCon, #publish{topic = "Test"}, <<"Test Message Payload.">>).
ok
11> callback function: {1,{publish, 0,0,0,<<"Test Message Payload.">>}}
```
Callback function argument is a tuple of two elements. First element is QoS of the topic from that the message came. Second element is a message `#publish{}` record.

```erlang
Arg = {Topic_QoS, Message#publish{}}
```

## References

1. [https://mosquitto.org/] - Mosquitto MQTT server.
2. [https://www.rabbitmq.com/] - RabbitMQ server with MQTT plugin.
3. [https://sourceforge.net/projects/mqtt-server/] - Erlang MQTT server.
4. [http://www.hivemq.com/demos/websocket-client/] - MQTT websocket client.
5. [http://www.mqttfx.org/] - MQTT client.

