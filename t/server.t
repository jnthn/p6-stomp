use Test;
use Test::IO::Socket::Async;
use Stomp::Server;

plan 15;

constant $test-socket = Test::IO::Socket::Async.new;
my \TestableServer = Stomp::Server but role {
    method socket-provider() {
        $test-socket
    }
}

constant $test-host = 'localhost';
constant $test-port = 1234;
dies-ok { TestableServer.new }, "Must provide host and port to new (1)";
dies-ok { TestableServer.new(host => $test-host) }, "Must provide host and port to new (2)";
dies-ok { TestableServer.new(port => $test-port) }, "Must provide host and port to new (3)";

{
    my $test-server = TestableServer.new(host => $test-host, port => $test-port);
    my $listen-supply = $test-server.listen();
    isa-ok $listen-supply, Supply, "Stomp::Server listen method returns a Supply";

    my $socket-listening = $test-socket.start-listening;
    nok $socket-listening, "Not listening before supply is tapped";
    my $listen-tap = $listen-supply.tap(-> $incoming { });
    my $socket-listener = await $socket-listening;
    ok $socket-listener, "Listening once supply is tapped";
    is $socket-listener.host, $test-host, "Listening on correct host";
    is $socket-listener.port, $test-port, "Listening on correct port";
    $listen-tap.close;
    ok (await $socket-listener.is-closed), "Closing supply tap also closes socket";
}

{
    constant $test-login = 'user';
    constant $test-password = 'correcthorsebatterystaple';

    my $test-server = TestableServer.new(host => $test-host, port => $test-port);
    my $listen-tap = $test-server.listen().tap(-> $conn { });
    my $socket-listener = await $test-socket.start-listening;
    my $test-conn = $socket-listener.incoming-connection;

    $test-conn.receive-data: Stomp::Message.new(
        command => 'CONNECT',
        headers => (
            login => $test-login,
            passcode => $test-password,
            accept-version => '1.2'
        ));

    my $message-text = await $test-conn.sent-data;
    my $parsed-message = Stomp::Parser.parse($message-text);
    ok $parsed-message, "Server responded to CONNECT with valid message";
    my $message = $parsed-message.made;
    is $message.command, "CONNECTED", "Server sent CONNECTED command";
    ok $message.headers<accept-version>:exists, "Server sent accept-version header";
    is $message.body, "", "Server sent no message body";
}

{
    my $test-server = TestableServer.new(host => $test-host, port => $test-port);
    my $listen-tap = $test-server.listen().tap(-> $conn { });
    my $socket-listener = await $test-socket.start-listening;
    my $test-conn = $socket-listener.incoming-connection;

    $test-conn.receive-data: "EPIC FAIL!";

    my $message-text = await $test-conn.sent-data;
    my $parsed-message = Stomp::Parser.parse($message-text);
    ok $parsed-message, "Server responded to invalid message with valid message";
    is $parsed-message.made.command, "ERROR", "Server sent ERROR command";
}
