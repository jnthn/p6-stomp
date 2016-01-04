use Stomp::Message;

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

    method send($topic, $body) {
        self!ensure-connected;
        $!connection.print: Stomp::Message.new:
            command => 'SEND',
            headers => (
                destination  => "/queue/$topic",
                content-type => "text/plain"
            ),
            body => $body;
    }

    method subscribe($topic) {
        self!ensure-connected;
        state $next-id = 0;
        supply {
            my $id = $next-id++;

            $!connection.print: Stomp::Message.new:
                command => 'SUBSCRIBE',
                headers => (
                    destination => "/queue/$topic",
                    id => $id
                );

            whenever $!incoming {
                if .command eq 'MESSAGE' && .headers<subscription> == $id {
                    emit .body;
                }
            }
        }
    }

    method !ensure-connected() {
        die X::Stomp::Client::NotConnected.new
            unless $!connection
    }

    method !process-messages($incoming) {
        my grammar StompMessage {
            token TOP {
                <command> \n
                [<header> \n]*
                \n
                <body>
                \n*
            }
            token command {
                < CONNECTED MESSAGE RECEIPT ERROR >
            }
            token header {
                <header-name> ":" <header-value>
            }
            token header-name {
                <-[:\r\n]>+
            }
            token header-value {
                <-[:\r\n]>*
            }
            token body {
                <-[\x0]>* )> \x0
            }
        }

        supply {
            my $buffer = '';
            whenever $incoming -> $data {
                $buffer ~= $data;
                while StompMessage.subparse($buffer) -> $/ {
                    $buffer .= substr($/.chars);
                    if $<command> eq 'ERROR' {
                        die ~$<body>;
                    }
                    else {
                        emit Stomp::Message.new(
                            command => ~$<command>,
                            headers => $<header>
                                .map({ ~.<header-name> => ~.<header-value> })
                                .hash,
                            body => ~$<body>
                        );
                    }
                }
            }
        }
    }
}
