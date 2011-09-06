use strict;
use warnings;
package Plack::Middleware::Cleanup;
# ABSTRACT: Run cleanup code after request completion

use parent 'Plack::Middleware';

=head1 SYNOPSIS

    my $app = sub {
        my $env = shift;
        $env->{'cleanup.register'}->(sub {
            # do some long running task
            # careful not to reference $env!
            ...
        });
        ...
    };

    builder {
        enable 'Cleanup';
        $app;
    };

=head1 DESCRIPTION

This middleware makes it possible to run code after the request cycle is
complete and the client has received the response.

Your application will see a callback in C<< $env->{'cleanup.register'} >>.
Call this callback with any number of coderefs that you want to be invoked
after the request is complete.

Make sure your coderefs do not accidentally refer to C<< $env >>, or you will
have a circular reference and leak memory (also, your coderefs will never run).

=cut

sub _guard (&) {
    bless $_[0], 'Plack::Middleware::Cleanup::Guard';
}

sub call {
    my ($self, $env) = @_;
    my @queue;
    $env->{'cleanup.register'} = sub { push @queue, @_ };
    $env->{'cleanup.guard'} = _guard {
        for my $item (@queue) { $item->() }
    };
    return $self->app->($env);
}

=head1 SEE ALSO

L<Catalyst::Plugin::RunAfterRequest>

=cut

package Plack::Middleware::Cleanup::Guard;

sub DESTROY { $_[0]->() }

1;
