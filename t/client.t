use Test;
use Test::IO::Socket::Async;
use Stomp::Client;

plan 17;

constant $test-host = 'localhost';
constant $test-port = 1234;
constant $test-login = 'user';
constant $test-password = 'correcthorsebatterystaple';

constant $test-socket = Test::IO::Socket::Async.new;
my \TestableClient = Stomp::Client but role {
    method socket-provider() {
        $test-socket
    }
}

{
    my $client = TestableClient.new(
        host => $test-host, port => $test-port,
        login => $test-login, password => $test-password
    );
    my $connect-promise = $client.connect();
    my $test-conn = await $test-socket.connection-made;
    is $test-conn.host, $test-host, "Connected to the correct host";
    is $test-conn.port, $test-port, "Connected to the correct port";
}

{
    my $client = TestableClient.new(
        host => $test-host, port => $test-port,
        login => $test-login, password => $test-password
    );
    my $connect-promise = $client.connect();
    my $test-conn = await $test-socket.connection-made;
    $test-conn.deny-connection();
    dies-ok { await $connect-promise },
        "Failed STOMP server connection breaks connect Promise";
}

{
    my $client = TestableClient.new(
        host => $test-host, port => $test-port,
        login => $test-login, password => $test-password
    );
    my $connect-promise = $client.connect();
    my $test-conn = await $test-socket.connection-made;
    $test-conn.accept-connection();

    my $message-text = await $test-conn.sent-data;
    my $parsed-message = Stomp::Parser.parse($message-text);
    ok $parsed-message, "Client sent valid message to server";
    my $message = $parsed-message.made;
    is $message.command, "CONNECT", "Client sent a CONNECT command";
    is $message.headers<login>, $test-login, "Client sent login";
    is $message.headers<passcode>, $test-password, "Client sent password";
    ok $message.headers<accept-version>:exists, 'Client sent accept-version header';
    is $message.body, "", "Client sent no message body";

    $test-conn.receive-data: Stomp::Message.new(
        command => 'CONNECTED',
        headers => ( version => '1.2' )
    );
    ok (await $connect-promise), "CONNECTED message completes connection";

    constant $test-destination = "/queue/shopping";
    constant $test-body = "Buy a karahi!";
    my $send-promise = $client.send($test-destination, $test-body);
    $message-text = await $test-conn.sent-data;
    $parsed-message = Stomp::Parser.parse($message-text);
    ok $parsed-message, "send method sent well-formed message";
    $message = $parsed-message.made;
    is $message.command, "SEND", "message has SEND command";
    is $message.headers<destination>, $test-destination, "destination header correct";
    is $message.headers<content-type>, "text/plain", "has default content-type header";
    is $message.body, $test-body, "message had expected body";
    is $send-promise.status, Kept, "Promise retunred by send was kept";

    constant $test-type = "text/html";
    $send-promise = $client.send($test-destination, $test-body,
        content-type => $test-type);
    $message = Stomp::Parser.parse(await $test-conn.sent-data).made;
    is $message.headers<content-type>, $test-type, "can set content-type header";
}
