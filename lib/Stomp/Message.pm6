class Stomp::Message {
    has $.command;
    has %.headers;
    has $.body;

    method Str() {
        qq:to/END/
            $!command
            %!headers.fmt("%s:%s")

            $!body\0
            END
    }
}
