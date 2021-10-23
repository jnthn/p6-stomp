use Stomp::Parser;
use Stomp::MessageStream;
need Stomp::Message;

class Stomp::Server {
    has Str $.host is required;
    has Int $.port is required;

    enum AckMode ( Auto => 'auto', Client => 'client', Individual => 'client-individual');

    class Subscription {
        has Str $.id            is required;
        has Str $.destination   is required;
        has AckMode $.ack = Auto;

        method ACCEPTS(Stomp::Message $mess) {
            $!destination eq $mess.headers<destination>;
        }
    }

    class Connection does Stomp::MessageStream[Stomp::Parser::ClientCommands] {
        has $.conn;
        has Supply $!messages;

        has  Subscription @.subscriptions;
        has  Lock::Async $!subscription-lock;

        has Supplier $!sent-message-supplier;
        has Promise $.connected;

        submethod TWEAK {
            $!messages = self!process-messages($!conn.Supply).share;

            $!subscription-lock = Lock::Async.new;

            $!connected = Promise.new;

            my &quit = {
                when X::Stomp::MalformedMessage {
                    await $!conn.print: Stomp::Message.new:
                                command => 'ERROR',
                                body => .message;
                }
            };

            my $connect-tap = $!messages.grep({ $_.command ~~ 'CONNECT'|'STOMP' }).tap:
                    {
                        await $!conn.print: Stomp::Message.new:
                            command => 'CONNECTED',
                            headers => ( version => '1.2' );
                        $!connected.keep: True;
                        $connect-tap.close;
                    }, :&quit;
            $!messages.grep({ $_.command ~~ 'SUBSCRIBE' }).tap: {
                $!subscription-lock.protect: {
                    @!subscriptions.push: Subscription.new( id          => $_.headers<id>,
                                                            destination => $_.headers<destination>,
                                                            ack         => $_.headers<ack> ?? AckMode($_.headers<ack>) !! Auto );
                };
            }, :&quit;
            $!messages.grep({ $_.command ~~ 'UNSUBSCRIBE' }).tap: {
                $!subscription-lock.protect: {
                    my $id = $_.headers<id>;
                    @!subscriptions = @!subscriptions.grep({ $_.id !~~ $id });
                };
            }, :&quit;

            $!sent-message-supplier = Supplier.new;
            $!messages.grep({ $_.command ~~ 'SEND' }).tap: {
                $!sent-message-supplier.emit: $_;
            }, :&quit;
        }

        method published-messages() returns Supply {
            $!sent-message-supplier.Supply;
        }

        method ACCEPTS(Stomp::Message $mess) {
            $!subscription-lock.protect({
                @!subscriptions.map(*.destination).any eq $mess.headers<destination>;
            });
        }

        method subscription-for-message(Stomp::Message $mess) {
            $!subscription-lock.protect({
                @!subscriptions.first({ $_.destination eq $mess.headers<destination>});
            });
        }

        method send(Stomp::Message $mess) {
            if self.subscription-for-message($mess) -> $sub {
                my $subscription = $sub.id;
                my $message-id = $mess.uuid;
                my $out = Stomp::Message.new(
                    command => 'MESSAGE',
                    body    => $mess.body,
                    headers => (|$mess.headers, :$message-id, :$subscription, )
                );
                $!conn.print: $out;
            }
            else {
                fail "Not subscribed to message";
            }
        }
    }

    method listen() {
        supply {
            whenever self.socket-provider.listen($!host, $!port) -> $conn {
                my $connection = Connection.new(:$conn);
                whenever $connection.connected {
                    emit $connection;
                }
            }
        }
    }

    method socket-provider() {
        IO::Socket::Async
    }
}
