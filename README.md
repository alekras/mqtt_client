## Introduction
The client allows to connect to MQTT server and send/receive messages according to MQTT messaging protocol version 3.1.1.
The client is written in Erlang. 
The client was tested with RabbitMQ and Mosquitto server on Windows/Linux/MacOSX boxes.

## Architecture
MQTT client is an OTP application. Top level component is supervisor
that is monitoring a child connection processes. Session state data are storing in database (DETS and MySQL in current version)

## Getting started
### Installation
To start with the client you have to complete three steps below:

1. Install [Mosquitto](https://mosquitto.org/) or [RabbitMQ](https://www.rabbitmq.com/) (with MQTT plugin) server.
2. Install [Erlang](http://www.erlang.org/download.html).
3. Install [Rebar3](https://www.rebar3.org/).


### Building
#### Download or clone from SourceForge GIT repository
Download zip file erl.mqtt.client-vsn-1.0.{x}.zip from project files folder [https://sourceforge.net/projects/mqtt-client/files/versions-1.0.x/],
unzip it and rename unziped folder to erl.mqtt.client. This is an Eclipse project folder. You do not need to use Eclipse to build the client but 
if you want you can use convenience of Eclipse and Erlide plugin.
Other way to get the client code is GIT. Type command 
``` bash
git clone https://git.code.sf.net/p/mqtt-client/code erl.mqtt.client
```
to download fron SourceForge GIT repository. For GitHub repository type
``` bash
git clone https://github.com/alekras/mqtt_client.git erl.mqtt.client
```
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
Next step is running the examples. Suppose you install Mosquitto MQTT server as 'localhost' that opened 1883 port 
for listening a TCP/IP connections from clients.
You have to setup 'quest' account with 'guest' password.
Start Erlang shell: 
```bash
erl -pa _build/default/lib/*/ebin</pre>
```

## Run application
After we start Erlang shell for testing we need to start application 'mqtt_client' that represents describing client.

```erlang REPL
2> application:start(mqtt_client).
ok
```
Load records definitions to console environment to make our next steps more clear:

```erlang repl
3> rr("include/mqtt_client.hrl").
[connect,connection_state,mqtt_client_error,primary_key,
 publish,storage_publish]
```

## Connection
Assign record #connect{} to Conn_def value:

```erlang repl
4> Conn_def = #connect{
4> client_id = "publisher", 
4> user_name = "guest",
4> password = <<"guest">>,
4> will = 0,
4> will_message = <<>>,
4> will_topic = "",
4> clean_session = 1,
4> keep_alive = 1000
4> }.
#connect{client_id = "publisher",user_name = "guest",
         password = <<"guest">>,will = 0,will_qos = 0,
         will_retain = 0,will_topic = [],will_message = <<>>,
         clean_session = 1,keep_alive = 1000}
```
And finally create new connection to MQTT server:

```erlang repl
5> PubCon = mqtt_client:connect(publisher, Conn_def, "localhost", 1883, []).
<0.77.0>
```
We have connection PubCon to MQTT server now. Let's create one more client's connection with different client Id:

```erlang repl
6> Conn_def_2 = Conn_def#connect{client_id = "subscriber"}.
#connect{client_id = "subscriber",user_name = "guest",
         password = <<"guest">>,will = 0,will_qos = 0,
         will_retain = 0,will_topic = [],will_message = <<>>,
         clean_session = 1,keep_alive = 1000}
7> SubCon = mqtt_client:connect(subscriber, Conn_def_2, "localhost", 2883, []).
<0.116.0>
```
## TLS/SSL Connection
To establish connection secured by TLS we need to add to socket option list atom 'ssl' like this:

```erlang repl
7> SubCon = mqtt_client:connect(subscriber, Conn_def_2, "localhost", 2884, [ssl]).
```
Note that we are using there port 2884. This MQTT server port has to be set to listen as SSL socket. How configurate Mosquitto server
see [https://dzone.com/articles/secure-communication-with-tls-and-the-mosquitto-broker/].
If we want to pass additional properties to SSL application on client side we can do it using options list:

```erlang repl
7> SubCon = mqtt_client:connect(subscriber, Conn_def_2, "localhost", 2884, [ssl, {certfile,"client.crt"}, {verify, verify_none}]).
```
## Subscribe and publish
To finish set up of the connection we need to suscribe it to some topic for example "Test" topic. Before make subscription we
need to define callback function. This function will act as 'application' from MQTT protokol terminology. When client receives message
from server's topic then callback function will be invoked and the message will be passed to it.

```erlang repl
8> CBF = fun(Arg) -> io:format(user,"callback function: ~p",[Arg]) end.
#Fun<erl_eval.6.52032458>
9> mqtt_client:subscribe(SubCon, [{"Test", 1, CBF}]).
{suback,[1]}
```
Now we can publish message to "Test" topic. After short moment subscriber recieves this message and fire callback function:

```erlang repl
10> mqtt_client:publish(PubCon, #publish{topic = "Test"}, <<"Test Message Payload.">>).
ok
11> callback function: {{"Test",1},0,0,0,<<"Test Message Payload.">>}
```
Callback function arqument is a tuple of five elements. First element is topic description from which message is arrived.
Second element is QoS of the message. Third element marks message as duplicated. Fourth element marks message as retained.
Fifth element is message payload itself.

```erlang repl
Arg = {{Topic, Topic_QoS}, Message_QoS, Dup, Retain, Payload}
```

## References

1. [https://mosquitto.org/] - Mosquitto MQTT server.
2. [https://www.rabbitmq.com/] - RabbitMQ server with MQTT plugin.
3. [https://sourceforge.net/projects/mqtt-server/] - Erlang MQTT server.
4. [http://www.hivemq.com/demos/websocket-client/] - MQTT websocket client.
5. [http://www.mqttfx.org/] - MQTT client.

