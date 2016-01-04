use Test;
use Stomp::Message;

plan 3;

my $msg = Stomp::Message.new(
    command => 'SEND',
    headers => ( destination => '/queue/stuff' ),
    body    => 'Much wow');
is $msg, qq:to/EXPECTED/, 'SEND message correctly formatted';
    SEND
    destination:/queue/stuff

    Much wow\0
    EXPECTED

dies-ok
    { Stomp::Message.new( headers => (foo => 'bar'), body => 'Much wow' ) },
    'Stomp::Message must be constructed with a command';

{
    my $msg = Stomp::Message.new(
        command => 'CONNECT',
        headers => ( accept-version => '1.2' ));
    is $msg, qq:to/EXPECTED/, 'CONNECT message with empty body correctly formatted';
        CONNECT
        accept-version:1.2

        \0
        EXPECTED
    CONTROL {
        when CX::Warn { flunk 'Should not warn over uninitialized body' }
    }
}
