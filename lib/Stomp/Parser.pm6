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
