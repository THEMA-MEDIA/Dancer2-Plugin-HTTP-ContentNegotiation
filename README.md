Dancer2::Plugin::HTTP::Accept
=============================

A Dancer2 plugin that does the right thing when it comes to Acceptable MIME-types and RFCs

Synopsis
========

    # return the ight content, based on the HTTP HEADER field: Accept
    get '/user/:id' => sub {
      my %user_data = retrieve_from_database( param('id') );
      http_choose_accept (
        'text/html'
            => sub { template 'user_profile_page' => { %user_data } },
        'application/json'
            => sub { return to_json \%user_data },
        [ 'image/png', 'image/jpeg' ]
            => sub {
              return user_thumbnail(
                user => param('id'),
                type => http_accept,
              )
            },
      )  
    };
    

Description
===========
A web server should be capable of content negotiation. This plugin goes way beyond the `Dancer2::Serializer::Mutable` which picks a wrong aproach on deciding what the requested type is. Also, this plugin is easy to extend with different 'serializers' for example `application/pdf` or `image/jpg`.

Dancer2::Plugin::HTTP::Accept will produce all the correct status message decribed in the latest RFCs.

Dancer2 Keywords
================
* http_choose_accept
the big switch statement

* http_accept
holds the value of the chosen HTTP Accept: header-field

Release Note
============
This is only for demonstration purpose.

- It should get an option to define what the default MIME-type should be in none is given.
- Not yet implemented: Statuscode 300 "Multiple Choises" when the request is not disambigues
- Not yet implemented: Response Header 'Varies', needed for proxies
- It does not yet have a return status code: 406 "Not Acceptable"
