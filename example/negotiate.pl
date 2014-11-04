use Dancer2;
use lib '../lib';
use Dancer2::Plugin::HTTP::ContentNegotiation;

get '/' => sub { "Hello World" };

our $html = <<"EOT";
<HTML>
<HEAD>
    <TITLE>Hello WWW</TITLE>
</HEAD>
<BODY>
    <H1>Hello World Wide Web</H1>
</BODY>
</HTML>
EOT

my $data = {
    users => [
        {   name => "John",
            age  => "42",
            country => "Canada",
        },
        {   name => "Mary",
            age     => "46",
            country => "United Kingdom",
        },
    ]
};

get '/html' => sub {
    http_choose_accept (
        'text/html' => sub { $html },
    );
};

get '/some' => sub {
    http_choose_accept (
        'text/html'        => sub { $html },
        'application/json' => sub { to_json $data },
#       'application/xml ' => sub { to_xml $data },
    );
};

get '/more' => sub {
    http_choose_accept (
        [ 'image/png', 'image/jpeg', 'image' ]
            => sub { "Can't do images of type '" . http_accept . "' yet" },
    );
};

dance;
