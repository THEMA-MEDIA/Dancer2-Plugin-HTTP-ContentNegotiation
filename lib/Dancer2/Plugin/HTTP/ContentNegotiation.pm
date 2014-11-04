package Dancer2::Plugin::HTTP::ContentNegotiation;

use warnings;
use strict;

use Carp;
use Dancer2::Plugin;

use HTTP::Headers::ActionPack;

use List::MoreUtils 'first_index';

our $negotiator = HTTP::Headers::ActionPack->new->get_content_negotiator;

sub http_choose_accept {
    my $dsl = shift;
    my $options = (@_ % 2) ? pop : undef;
    
    my ($selectors,$coderefs) = _split_selector_coderef(@_);
    
    my $selector;
    if ( $dsl->request->header('Accept') ) {
        $selector = $negotiator->choose_media_type (
            $selectors,
            $dsl->request->header('Accept')
        );
    };

    unless ($selector) {
        $dsl->status(406); # Not Acceptable
        halt;
    }

    my $index = first_index { $_ eq $selector } @$selectors;
    
    $dsl->vars->{http_accept} = $selector;
    $dsl->header('Content-Type' => "$selector" );    
    $dsl->header('Vary' => join ', ', 'Accept', $dsl->header('Vary') )
        if @$selectors > 1 ;
    return $coderefs->[$index]->($dsl);
};

register http_choose_accept => \&http_choose_accept;


sub http_accept {
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

sub _split_selector_coderef {
    
    my (@selectors, @coderefs);
    while ( my ($selectors, $coderef) = @{[ shift, shift ]} ) {
        last unless $selectors;
        $selectors = [ $selectors ] unless ref $selectors eq 'ARRAY';
        foreach ( @$selectors ) {
            if ( ref $coderef ne 'CODE' ) {
                die
                    qq{Invallid http_choose usage: }
                .   qq{'$_' needs a CODE ref};
            }
            push @selectors, $_;
            push @coderefs, $coderef;
        }
    }
    
    return (\@selectors, \@coderefs);
}; # _split_selector_coderef

register_plugin;

1;
