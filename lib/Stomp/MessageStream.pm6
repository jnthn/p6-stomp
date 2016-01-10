role Stomp::MessageStream[::MessageGrammar] {
    method !process-messages($incoming) {
        supply {
            my $buffer = '';
            whenever $incoming -> $data {
                $buffer ~= $data;
                while MessageGrammar.subparse($buffer) -> $/ {
                    given $/.made -> $message {
                        die $message.body if $message.command eq 'ERROR';
                        emit $message;
                    }
                    $buffer .= substr($/.chars);
                }
            }
        }
    }
}
