package App::winmaildat2tar;

use v5.14;
use warnings;
our $VERSION = "0.08";

my $default_format = $0 =~ /2(\w+)$/ ? $1 : 'tar';

use Moo;
has format => ( is => 'ro',
		default => $default_format );
no Moo;

sub run {
    my $app = shift;
    local @ARGV = @_;

    use Getopt::EX::Long qw(:DEFAULT Configure ExConfigure);
    ExConfigure BASECLASS => [ __PACKAGE__, "Getopt::EX" ];
    Configure "bundling";
    GetOptions($app, qw(format|f=s)) or usage();

    my $archive = App::winmaildat2tar::Archive->new($app->format);

    @ARGV or usage();
    for my $file (@ARGV) {
	use Convert::TNEF;
	my $tnef = Convert::TNEF->read_in($file, { output_to_core => 'ALL' })
	    or die $Convert::TNEF::errstr;
	for my $ent ($tnef->attachments) {
	    my $name = $ent->longname // $ent->name // unknown();
	    $archive->add($name, $ent->data);
	}
    }

    print $archive->write;

    exit;
}

sub usage {
    die sprintf "Usage: %s winmail.dat\n", $0 =~ s|.*/||r;
}

sub unknown {
    my $seq = (state $_seq)++;
    sprintf "unknown%s.dat", $seq ? "_$seq" : "";
}

1;

######################################################################

package App::winmaildat2tar::Archive {
    use v5.14;
    use warnings;
    use Data::Dumper;

    use Moo;
    has format  => ( is => 'ro', required => 1 );
    has archive => ( is => 'rw' );
    around BUILDARGS => sub {
	my ($orig, $class, $format) = @_;
	$format =~ s/^([a-z\d])([a-z\d]*)$/\u$1\L$2/i
	    or die "$format: invalid format.\n";
	$class->$orig(format => $format);
    };
    sub BUILD {
	my($obj, $args) = @_;
	my $class = ref $obj;
	my $format = $obj->format;
	my $subclass = "$class\::$format";
	bless $obj, $subclass;
	$obj->can('newarchive') or die "$format: unknown format.\n";
	$obj->newarchive or die;
    }
    no Moo;

    sub newarchive {
	my $obj = shift;
	$obj->archive($obj->module->new);
    }
    sub module {
	sprintf "Archive::%s", shift->format;
    }
    sub write {
	shift->archive->write;
    }
}

package App::winmaildat2tar::Archive::Tar {
    use v5.14;
    use warnings;
    use Archive::Tar;
    our @ISA = qw(App::winmaildat2tar::Archive);
    sub add {
	my $obj = shift;
	my($name, $data) = @_;
	my $option = { uname => 'nobody', gname => 'nogroup' };
	$obj->archive->add_data($name, $data, $option);
    }
}

package App::winmaildat2tar::Archive::Ar {
    use v5.14;
    use warnings;
    use Archive::Ar;
    our @ISA = qw(App::winmaildat2tar::Archive);
    sub add {
	my $obj = shift;
	my($name, $data) = @_;
	$obj->archive->add_data($name, $data);
    }
}

package App::winmaildat2tar::Archive::Zip {
    use v5.14;
    use warnings;
    use Archive::Zip;
    our @ISA = qw(App::winmaildat2tar::Archive);
    sub add {
	my $obj = shift;
	my($name, $data) = @_;
	$obj->archive->addString($data, $name);
    }
    sub write {
	my $obj = shift;
	open my $fh, ">", \(my $data) or die "open: $!";
	$obj->archive->writeToFileHandle($fh);
	close $fh;
	$data;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

winmaildat2tar - Convert winmail.dat (TNEF data) to tentative archive

=head1 SYNOPSIS

    winmaildat2tar file

=head1 DESCRIPTION

Document is inlcuded in executable script.

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2020 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

