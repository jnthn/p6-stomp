use Stomp::Parser;
use Stomp::MessageStream;

class Stomp::Server does Stomp::MessageStream[Stomp::Parser::ClientCommands] {
    has Str $.host is required;
    has Int $.port is required;

    method listen() {
        supply {
            whenever self.socket-provider.listen($!host, $!port) -> $conn {
                self!process-messages($conn).tap:
                    {
                        await $conn.print: Stomp::Message.new:
                            command => 'CONNECTED',
                            headers => ( accept-version => '1.2' );
                    },
                    quit => {
                        when X::Stomp::MalformedMessage {
                            await $conn.print: Stomp::Message.new:
                                command => 'ERROR',
                                body => .message;
                        }
                    };
            }
        }
    }

    method socket-provider() {
        IO::Socket::Async
    }
}
