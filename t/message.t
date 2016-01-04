use Test;
use Stomp::Message;

plan 1;

my $msg = Stomp::Message.new(
    command => 'SEND',
    headers => ( destination => '/queue/stuff' ),
    body    => 'Much wow');
is $msg, qq:to/EXPECTED/, 'SEND message correctly formatted';
    SEND
    destination:/queue/stuff

    Much wow\0
    EXPECTED
