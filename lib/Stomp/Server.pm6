use Stomp::Parser;
use Stomp::MessageStream;

class Stomp::Server {
    has Str $.host is required;
    has Int $.port is required;

    class Connection does Stomp::MessageStream[Stomp::Parser::ClientCommands] {
        has $.conn;
        has Supply $!messages;

        submethod TWEAK {
            $!messages = self!process-messages($!conn);

            my $connect-tap = $!messages.grep({ $_.command ~~ 'CONNECT'|'STOMP' }).tap: 
                    {
                        await $!conn.print: Stomp::Message.new:
                            command => 'CONNECTED',
                            headers => ( accept-version => '1.2' );
                        $connect-tap.close;
                    },
                    quit => {
                        when X::Stomp::MalformedMessage {
                            await $!conn.print: Stomp::Message.new:
                                command => 'ERROR',
                                body => .message;
                        }
                    };
        }


    }

    method listen() {
        supply {
            whenever self.socket-provider.listen($!host, $!port) -> $conn {
                my $connection = Connection.new(:$conn);
                emit $connection;
            }
        }
    }

    method socket-provider() {
        IO::Socket::Async
    }
}
