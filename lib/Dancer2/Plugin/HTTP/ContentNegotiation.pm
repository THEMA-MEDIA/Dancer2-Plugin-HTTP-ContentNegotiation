package Dancer2::Plugin::HTTP::ContentNegotiation;

use warnings;
use strict;

use Carp;
use Dancer2::Plugin;

use HTTP::Headers::ActionPack;

# use List::MoreUtils 'first_index';

our $negotiator = HTTP::Headers::ActionPack->new->get_content_negotiator;
our %negotiation_choosers = (
    'accept'          => "choose_media_type",
    'accept-language' => "choose_language",
    'accept-charset'  => "choose_charset",
    'accept-encoding' => "choose_encoding",
);

register 'http_choose_accept' => sub {
    return http_choose ( @_, 'accept' );
};

register 'http_choose_accept_language' => sub {
    return http_choose ( @_, 'accept-language' );
};

register 'http_choose_accept_charset' => sub {
    return http_choose ( @_, 'accept-charset' );
};

register 'http_choose_accept_encoding' => sub {
    return http_choose ( @_, 'accept-encoding' );
};

sub http_choose {
    my $dsl     = shift;
    my $header  = pop; 
    my $options = (@_ % 2) ? pop : undef;
    
    my %choices = _parse_choices(@_);
    
    # prepare for default behaviour
    # default                ... if none match, pick first in definition list
    # default => 'MIME-type' ... takes this as response, must be defined!
    # default => undef       ... do not make assumptions, return 406
    my $choice_first = ref $_[0] eq 'ARRAY' ? $_[0]->[0] : $_[0];
    my $choice_default = $options->{'default'} if exists $options->{'default'};
    if ( $choice_default and not exists $choices{$choice_default} ) {
        $dsl->app->log ( warning =>
            qq|Invallid http_choose usage: |
        .   qq|'$choice_default' does not exist in choices|
        );
        $dsl->status(500);
        $dsl->halt;
    }
    
    # choose from the provided definition
    my $selected = undef;
    my $method = $negotiation_choosers{$header}; # this should be avoided
    if ( $dsl->request->header($header) ) {
        $selected = $negotiator->$method (
            [ keys %choices ],
            $dsl->request->header($header)
        );
    };
    # if nothing selected, use sensible default
    $selected ||= exists $options->{'default'} ? $options->{'default'} : $choice_first;
    
    # if still nothing selected, return 406 error
    unless ($selected) {
        $dsl->status(406); # Not Acceptable
        $dsl->halt;
    };
    
    my $variable_name = "http_$header" =~ y/ -/__/r;
    $dsl->vars->{$variable_name} = $selected;
    $dsl->header('Content-Type' => "$selected" );    
    $dsl->header('Vary' => join ', ', $header, $dsl->header('Vary') )
        if keys %choices > 1 ;
    return $choices{$selected}{coderef}->($dsl);
};

sub http_accept {
    # http_accept, returns the MIME-type being selected inside the route
    
    my $dsl = shift;
    
    unless ( exists $dsl->vars->{http_accept} ) {
        $dsl->app->log( warning =>
            qq|'http_accept' should only be used in an authenticated route|
        );
    }
    if (@_ >= 1) {
        $dsl->app->log ( error =>
            qq|'http_accept' can't set to new value 'shift'|
        );
    }
    
    return unless exists $dsl->vars->{http_accept};
    return $dsl->vars->{http_accept};
    
} # http_accept

register http_accept => \&http_accept;


on_plugin_import {
    my $dsl = shift;
    my $app = $dsl->app;
};

sub _parse_choices {
    # _parse_choices
    # unraffles a paired list into a hash of choices and associated coderefs
    # since the 'key' can be an arrayref too, these are added to the hash with
    # seperate values
    
    my %choices;
    while ( @_ ) {
        my ($choices, $coderef) = @{[ shift, shift ]};
        last unless $choices;
        # turn a single value into a ARRAY REF
        $choices = [ $choices ] unless ref $choices eq 'ARRAY';
        # so we only have ARRAY REFs to deal with
        foreach ( @$choices ) {
            if ( ref $coderef ne 'CODE' ) {
                die
                    qq{Invallid http_choose usage: }
                .   qq{'$_' needs a CODE ref};
            }
            if ( exists $choices{$_} ) {
                die
                    qq{Invallid http_choose usage: }
                .   qq{Duplicated choice '$_'};
            }
            $choices{$_} = {
                coderef => $coderef,
            };
        }
    }
    return %choices;
}; # _choices_hasref

register_plugin;

1;
