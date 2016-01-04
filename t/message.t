use Test;
use Stomp::Message;

plan 2;

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
