use Dancer2;
use lib '../lib';
use Dancer2::Plugin::HTTP::ContentNegotiation;

get '/greetings' => sub { http_choose_language (
    'nl'    => sub { 'Hallo Amsterdam' },
    'de'    => sub { 'Hallo Berlin' },
    'en'    => sub { 'Hello World' }, # any other english if acceptable
    'en-GB' => sub { 'Hello London' },
    'en-US' => sub { 'Hello Washington' },
    'en-*'  => sub { 'Hello ?' },
    # default is first in the list
);
};
dance;
