class Stomp::Message {
    has $.command is required;
    has %.headers;
    has $.body = '';

    has $!uuid;

    method Str() {
        qq:to/END/
            $!command
            %!headers.fmt("%s:%s")

            $!body\0
            END
    }

    method uuid() returns Str {
        use UUID;
        $!uuid //= UUID.new.Str;
    }
}
