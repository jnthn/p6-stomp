use Stomp::Message;
use Stomp::Parser;
use Concurrent::Iterator;

role X::Stomp::Client is Exception { }
class X::Stomp::Client::NotConnected does X::Stomp::Client {
    method message() {
        "STOMP client is not connected"
    }
}

class Stomp::Client {
    has Str $.host is required;
    has Int $.port is required;
    has Str $.login = 'guest';
    has Str $.password = 'guest';
    has $!connection;
    has $!incoming;
    has $!ids = concurrent-iterator(1..Inf);

    method connect() {
        start {
            my $conn = await self.socket-provider.connect($!host, $!port);
            $!incoming = self!process-messages($conn.Supply).share;

            my $connected = $!incoming
                .grep(*.command eq 'CONNECTED')
                .head(1)
                .Promise;
            await $conn.print: Stomp::Message.new:
                command => 'CONNECT',
                headers => (
                    accept-version => '1.2',
                    login => $!login,
                    passcode => $!password
                );
            await $connected;
            $!connection = $conn;

            True
        }
    }

    method socket-provider() {
        IO::Socket::Async
    }

    method send($destination, $body, :$content-type = "text/plain") {
        self!ensure-connected;
        $!connection.print: Stomp::Message.new:
            command => 'SEND',
            headers => ( :$destination, :$content-type ),
            body => $body;
    }

    method subscribe($destination) {
        self!ensure-connected;
        supply {
            my $id = $!ids.pull-one;

            $!connection.print: Stomp::Message.new:
                command => 'SUBSCRIBE',
                headers => ( :$destination, :$id );
            CLOSE {
                $!connection.print: Stomp::Message.new:
                    command => 'UNSUBSCRIBE',
                    headers => ( :$id );
            }

            whenever $!incoming {
                if .command eq 'MESSAGE' && .headers<subscription> == $id {
                    emit $_;
                }
            }
        }
    }

    method !ensure-connected() {
        die X::Stomp::Client::NotConnected.new
            unless $!connection
    }

    method !process-messages($incoming) {
        supply {
            my $buffer = '';
            whenever $incoming -> $data {
                $buffer ~= $data;
                while Stomp::Parser::ServerCommands.subparse($buffer) -> $/ {
                    given $/.made -> $message {
                        die $message.body if $message.command eq 'ERROR';
                        emit $message;
                    }
                    $buffer .= substr($/.chars);
                }
            }
        }
    }
}
