package Dancer2::Plugin::HTTP::ContentNegotiation;

use warnings;
use strict;

use Carp;
use Dancer2::Plugin;

use HTTP::Headers::ActionPack;

# use List::MoreUtils 'first_index';

our $negotiator = HTTP::Headers::ActionPack->new->get_content_negotiator;
our %http_headers = (
    'media_type'    => "Accept",
    'language'      => "Accept-Language",
    'charset'       => "Accept-Charset",
    'encoding'      => "Accept-Encoding",
);

register 'http_choose_media_type' => sub {
    return _http_choose ( @_, 'media_type' );
};

register 'http_choose_language' => sub {
    return _http_choose ( @_, 'language' );
};

register 'http_choose_charset' => sub {
    return _http_choose ( @_, 'charset' );
};

register 'http_choose_encoding' => sub {
    return _http_choose ( @_, 'encoding' );
};

# compatabillity with the Accept header - it is not Accept-Media-Type
register 'http_choose' => sub {
    return _http_choose ( @_, 'media_type' );
};

sub _http_choose {
    my $dsl     = shift;
    my $switch  = pop; 
    my $options = (@_ % 2) ? pop : undef;
    
    my @choices = _parse_choices(@_);
    
    # prepare for default behaviour
    # default                ... if none match, pick first in definition list
    # default => 'choice'    ... takes this as response, must be defined!
    # default => undef       ... do not make assumptions, return 406
    my $choice_first = ref $_[0] eq 'ARRAY' ? $_[0]->[0] : $_[0];
    my $choice_default = $options->{'default'} if exists $options->{'default'};
    
#   # make sure that a 'default' is actually in the list of choices
#   
#   if ( $choice_default and not exists $choices{$choice_default} ) {
#       $dsl->app->log ( warning =>
#           qq|Invallid http_choose usage: |
#       .   qq|'$choice_default' does not exist in choices|
#       );
#       $dsl->status(500);
#       $dsl->halt;
#   }
    
    # choose from the provided definition
    my $selected = undef;
    my $method = 'choose' . '_' . $switch;
    if ( $dsl->request->header($http_headers{$switch}) ) {
        $selected = $negotiator->$method (
            [ map { $_->{selector} } @choices ],
            $dsl->request->header($http_headers{$switch})
        );
    };
    
    # if nothing selected, use sensible default
#   $selected ||= exists $options->{'default'} ? $options->{'default'} : $choice_first;
    unless ($selected) {
        $selected = $negotiator->$method (
            [ map { $_->{selector} }  @choices ],
            exists $options->{'default'} ? $options->{'default'} : $choice_first
        );
    };
    
    # if still nothing selected, return 406 error
    unless ($selected) {
        $dsl->status(406); # Not Acceptable
        $dsl->halt;
    };
    
    $dsl->vars->{"http_chosen_$switch"} = $selected;
    
    # set the apropriate headers for Content-Type and Content-Language
    # XXX Content-Type could consist of type PLUS charset if it's text-based
    if ($switch eq 'media_type') {
        $dsl->header('Content-Type' => "$selected" );
    };
    if ($switch eq 'language') {
        $dsl->header('Content-Language' => "$selected" );
    };
    
    $dsl->header('Vary' =>
        join ', ', $http_headers{$switch}, $dsl->header('Vary')
    ) if @choices > 1 ;
    
    my @coderefs = grep {$_->{selector} eq $selected} @choices;
    return $coderefs[0]{coderef}->($dsl);
};

register 'http_chosen_media_type' => sub {
    return _http_chosen ( @_, 'media_type' );
};

register 'http_chosen_language' => sub {
    return _http_chosen ( @_, 'language' );
};

register 'http_chosen_charset' => sub {
    return _http_chosen ( @_, 'charset' );
};

register 'http_chosen_encoding' => sub {
    return _http_chosen ( @_, 'encoding' );
};

# compatabillity with the Accept header - it is not Accept-Media-Type
register 'http_chosen' => sub {
    return _http_chosen ( @_, 'media_type' );
};

sub _http_chosen {
    my $dsl     = shift;
    my $switch  = pop;
    
    $dsl->app->log ( error =>
        "http_chosen_$switch does not exist"
    ) unless exists $dsl->vars->{"http_chosen_$switch"}; 
    
    $dsl->app->log( error =>
        "http_chosen_$switch is designed for read-only"
    ) if (@_ >= 1);
    
    return unless exists $dsl->vars->{"http_chosen_$switch"};
    return $dsl->vars->{"http_chosen_$switch"};
};

on_plugin_import {
    my $dsl = shift;
    my $app = $dsl->app;
};

sub _parse_choices {
    # _parse_choices
    # unraffles a paired list into a list of hashes,
    # each hash containin a 'selector' and associated coderef.
    # since the 'key' can be an arrayref too, these are added to the list with
    # seperate values
    
    my @choices;
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
#           if ( exists $choices{$_} ) {
#               die
#                   qq{Invallid http_choose usage: }
#               .   qq{Duplicated choice '$_'};
#           }
            push @choices,
            {
                selector => $_,
                coderef  => $coderef,
            };
        }
    }
    return @choices;
}; # _parse_choices

register_plugin;

1;
