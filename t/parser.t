use Test;
use Stomp::Parser;

plan 46;

my @server-commands = < CONNECTED MESSAGE RECEIPT ERROR >;
my @client-commands = <
    SEND SUBSCRIBE UNSUBSCRIBE BEGIN COMMIT ABORT ACK NACK
    DISCONNECT CONNECT STOMP
>;
my @commands = flat @server-commands, @client-commands;

for @commands {
    ok Stomp::Parser.parse(qq:to/TEST/), "Can parse $_ command (no headers/body)";
        $_

        \0
        TEST
}

nok Stomp::Parser.parse(qq:to/TEST/), "Cannot parse unknown command FOO";
    FOO

    \0
    TEST

for @server-commands {
    ok Stomp::Parser::ServerCommands.parse(qq:to/TEST/), "Server parser accepts $_";
        $_

        \0
        TEST
    nok Stomp::Parser::ClientCommands.parse(qq:to/TEST/), "Client parser rejects $_";
        $_

        \0
        TEST
}

for @client-commands {
    ok Stomp::Parser::ClientCommands.parse(qq:to/TEST/), "Client parser accepts $_";
        $_

        \0
        TEST
    nok Stomp::Parser::ServerCommands.parse(qq:to/TEST/), "Server parser rejects $_";
        $_

        \0
        TEST
}
