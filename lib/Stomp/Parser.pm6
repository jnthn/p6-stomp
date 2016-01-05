use Stomp::Message;

grammar Stomp::Parser {
    token TOP {
        <command> \n
        [<header> \n]*
        \n
        <body>
        \n*
    }
    token command {
        <
            SEND SUBSCRIBE UNSUBSCRIBE BEGIN COMMIT ABORT ACK NACK
            DISCONNECT CONNECT STOMP CONNECTED MESSAGE RECEIPT ERROR
        >
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

    class Actions {
        method TOP($/) {
            make Stomp::Message.new(
                command => ~$<command>,
                headers => $<header>.map(*.made),
                body    => ~$<body>
            );
        }
        method header($/) {
            make ~$<header-name> => ~$<header-value>;
        }
    }

    method parse(|c) { nextwith(actions => Actions, |c); }
    method subparse(|c) { nextwith(actions => Actions, |c); }
}

grammar Stomp::Parser::ClientCommands is Stomp::Parser {
    token command {
        <
            SEND SUBSCRIBE UNSUBSCRIBE BEGIN COMMIT ABORT ACK NACK
            DISCONNECT CONNECT STOMP
        >
    }
}

grammar Stomp::Parser::ServerCommands is Stomp::Parser {
    token command {
        < CONNECTED MESSAGE RECEIPT ERROR >
    }
}
