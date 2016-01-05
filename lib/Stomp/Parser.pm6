grammar Stomp::Parser {
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
