package Koha::Plugin::Wa;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;
use Koha::DateUtils qw(dt_from_string);

use HTTP::Request::Common;
use LWP::UserAgent;
use Mojo::JSON qw(encode_json decode_json);
use YAML::XS qw(Load);

## Here we set our plugin version
our $VERSION         = "1.0";
our $MINIMUM_VERSION = "23.05";

our $metadata = {
    name            => 'WhatsApp Plugin using Gupshup API',
    author          => 'Abhishek Nagar',
    date_authored   => '2026-01-18',
    date_updated    => "2026-01-18",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description =>
      'Plugin to forward Notices to an Endpoint which can process and send via WhatsApp',
};

=head3 new

=cut

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

=head3 configure

=cut

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            api_key => $self->retrieve_data('api_key'),
            api_endpoint => $self->retrieve_data('api_endpoint'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                api_key => $cgi->param('api_key'),
                api_endpoint => $cgi->param('api_endpoint'),
            }
        );
        $self->go_home();
    }
}

=head3 install

This is the 'install' method. Any database tables or other setup that should
be done when the plugin if first installed should be executed in this method.
The installation method should always return true if the installation succeeded
or false if it failed.

=cut

sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

=head3 upgrade

This is the 'upgrade' method. It will be triggered when a newer version of a
plugin is installed over an existing older version of a plugin

=cut

sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

=head3 uninstall

This method will be run just before the plugin files are deleted
when a plugin is uninstalled. It is good practice to clean up
after ourselves!

=cut

sub uninstall() {
    my ( $self, $args ) = @_;

    return 1;
}

=head3 before_send_messages

Plugin hook that runs right before the message queue is processed
in process_message_queue.pl

=cut

sub before_send_messages {
    my ( $self, $params ) = @_;

    my $api_key = $self->retrieve_data('api_key');
    unless ($api_key) {
        warn "Failed to load API Key!";
    }

    my $api_endpoint =  $self->retrieve_data('api_endpoint');

    my $messages = Koha::Notice::Messages->search(
        {
            status                 => 'pending',
            message_transport_type => 'sms',
        }
    );

    my $patrons = {};
    while ( my $m = $messages->next ) {
        $patrons->{ $m->borrowernumber } //=
          Koha::Patrons->find( $m->borrowernumber );
        my $patron = $patrons->{ $m->borrowernumber };
        unless ($patron) {
            warn
              sprintf( "WA: Skipping message %s, no borrowernumber found!",
                $m->id );
            next;
        }

        my $json = encode_json(
            {
                "api_key"        => $api_key,
                "customerFirstName" => $patron->firstname,
                "customerLastName"  => $patron->surname,
                "phone"             => $patron->smsalertnumber || $patron->phone,
                "code"              => $m->letter_code,
                "messageBody"       => $m->content,
            }
        );

        my $req = HTTP::Request->new( 'POST', $api_endpoint );
        $req->header( 'Content-Type' => 'application/json' );
        $req->content($json);

        my $lwp = LWP::UserAgent->new;
        my $res = $lwp->request($req);

        if ( $res->is_success ) {
            $m->status('sent')->store();
        }
        else {
            warn "WA response indicates failure: " . $res->status_line;
            $m->status('failed')->store();
        }
    }
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'wa';
}
1;
