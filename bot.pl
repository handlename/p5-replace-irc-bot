#!/usr/bin/env perl

use strict;
use warnings;

use AnySan;
use AnySan::Provider::IRC;
use Log::Minimal;

use App::Options(
    option => {
        host    => { type => 'string', required => 1 },
        port    => { type => 'string', default  => '6666' },
        ssl     => { type => 'bool',   default  => 0 },
        nick    => { type => 'string', required => 1 },
        channel => { type => 'string', required => 1 },
    },
);
my %opts = %App::options;

my $password = password();

my $messages = {};

my $irc = irc(
    $opts{host},
    port       => $opts{port},
    enable_ssl => $opts{ssl},
    password   => $password,
    key        => $opts{host},
    nickname   => $opts{nick},
    channels   => { $opts{channel} => {} },
);

AnySan->register_listener(
    replace => {
        cb => sub {
            my ($receive) = @_;

            if ($receive->message =~ qr!(s/[^/]+/[^/]*/[gi]*)! &&
                defined $messages->{$receive->from_nickname})
            {
                my $regex   = $1;
                my $message = $messages->{$receive->from_nickname};
                eval "\$message =~ $regex";
                $receive->send_replay($message);

                infof '%s: %s, %s -> %s',
                    $receive->from_nickname,
                    $receive->message,
                    $messages->{$receive->from_nickname},
                    $message;
            }
            else {
                $messages->{$receive->from_nickname} = $receive->message;
            }
        },
    },
);

AnySan->run();

sub password {
    print 'password []:';

    system 'stty -echo';
    my $password = <STDIN>;
    system 'stty echo';
    print "\n";

    chomp $password;

    return $password;
}
