use strict;
use warnings;
use v5.10;

package App::JuiceCalc::EJMUParser;
use Moo;
use Carp;

has lines => (
  is => 'ro',
  required => 1,
);

has name => (
  is => 'rw',
  default => sub { "Unknown" },
);

sub BUILD {
  my $self = shift;

  # so the user doesn't have to do it themselves
  s/\r?\n// for @{ $self->lines };
}

sub new_from_file {
  my ($class, %args) = @_;

  my $file = delete $args{file};

  if (delete $args{autoname}) {
    require File::Basename;
    $args{name} = File::Basename::fileparse($file, '.rec');
  }

  # lazy man's slurp
  $class->new( lines => [ do { local @ARGV = $file; <> } ], %args );
}

has unknown => (
  is => 'lazy',
);

sub _build_unknown {
  my $self = shift;

  # don't know what these are even used for
  return [ @{ $self->lines }[16,17] ];
}

has misc => (
  is => 'lazy',
);

sub _build_misc {
  my $self = shift;

  my %m;

  # XXX not doing the /100 percent to fraction conversion here,
  # mostly because I have no real use for this information.

  $m{base} = {
    mg => $self->lines->[0],
    pg => $self->lines->[18],
    vg => $self->lines->[19],
  };

  $m{drops} = $self->lines->[30];
  $m{amount} = $self->lines->[2];

  return \%m;
}

has flavors => (
  is => 'lazy',
);

sub _build_flavors {
  my $self = shift;

  my %f;

  # flavor 1-5
  for my $fi (0..4) {
    my $n = $self->lines->[ 9 + $fi ];
    my $p = $self->lines->[ 4 + $fi ]/100;
    my $pg = $self->lines->[ 20 + $fi ]/100;
    my $vg = $self->lines->[ 25 + $fi ]/100;

    my $null;
    if ($self->version == 1) {
      $null = 0;
    }
    else {
      $null = $self->lines->[ 31 + $fi ];
    }

    if ($null) { $pg = 0, $vg = 0 }

    $f{$fi} = [
      $n, $p,
      (pg=>$pg)x!!$pg, (vg=>$vg)x!!$vg,
      (unk=>1)x$null
    ];
  }

  # flavor 6,7
  if ($self->version > 2) {
    for my $fi (0,1) {
      my $n = $self->lines->[ 37 + 5*$fi ];
      my $p = $self->lines->[ 36 + 5*$fi ]/100;
      my $pg = $self->lines->[ 38 + 5*$fi ]/100;
      my $vg = $self->lines->[ 39 + 5*$fi ]/100;
      my $null = $self->lines->[ 40 + 5*$fi ];

      if ($null) { $pg = 0, $vg = 0 }

      $f{ 5 + $fi } = [
        $n, $p,
        (pg=>$pg)x!!$pg, (vg=>$vg)x!!$vg,
        (unk=>1)x$null
      ];
    }
  }

  # treat the 'Water/Vodka/PGA' field as just another flavor of
  # unknown composition.

  $f{other} = [ 'DW/PGA', $self->lines->[3]/100, unk => 1 ];

  return \%f;
}

has target => (
  is => 'lazy',
);

sub _build_target {
  my $self = shift;

  return {
    pg => $self->lines->[14]/100,
    vg => $self->lines->[15]/100,
    mg => $self->lines->[1],
  };
}

has notes => (
  is => 'lazy',
);

sub _build_notes {
  my $self = shift;
  if ($self->version >= 3) {
    return [ splice @{ $self->lines }, 46 ];
  }
  return [];
}

has version => (
  is => 'lazy',
);

sub _build_version {
  my $self = shift;
  my $l   = @{ $self->lines };
  if    ( $l == 31 ) { return 1 }
  elsif ( $l == 36 ) { return 2 }
  elsif ( $l >= 46 ) { return 3 }
  else               { croak "Unknown EJMU selfipe file version." }
}

# remove empty flavors, maybe put them into the notes
sub sanitize {
  my $self = shift;

  my @to_notes;
  my @to_keep;

  for my $fi (0..6) {
    my $f = delete $self->flavors->{$fi} or next;

    if ($f->[1]) {  # has percentage
      push @to_keep, $f;
    }
    elsif ($f->[0]) {  # has something in flavor name field
      push @to_notes, $f->[0];
    }
    else {
      ; # drop it
    }
  }

  for my $fi (0..$#to_keep) {
    $self->flavors->{$fi} = $to_keep[$fi];
  }

  push @{ $self->notes }, @to_notes;

  return $self;
}

sub as_string {
  my $self = shift;
  join "\r\n", @{ $self->_to_lines }, '';  # get the trailing \r\n
}

# turn the object back into a bunch of lines
sub _to_lines {
  my $self = shift;

  my @lines;

  push @lines, $self->misc->{base}->{mg};
  push @lines, $self->target->{mg};
  push @lines, $self->misc->{amount};
  push @lines, $self->flavors->{other}->[1]*100;

  # flavor 1-5 percentages
  for my $fi (0..4) {
    if (exists $self->flavors->{$fi}) {
      push @lines, $self->flavors->{$fi}->[1]*100;
    } else {
      push @lines, 0;
    }
  }

  # flavor 1-5 names
  for my $fi (0..4) {
    if (exists $self->flavors->{$fi}) {
      push @lines, $self->flavors->{$fi}->[0];
    } else {
      push @lines, '';
    }
  }

  push @lines, $self->target->{pg}*100;
  push @lines, $self->target->{vg}*100;

  # unknown magic values
  push @lines, @{ $self->unknown };

  push @lines, $self->misc->{base}->{pg};
  push @lines, $self->misc->{base}->{vg};

  # flavor 1-5 pg
  for my $fi (0..4) {
    if (exists $self->flavors->{$fi}) {
      my @x = @{ $self->flavors->{$fi} };
      my %c = ( pg => 0, splice @x, 2 );
#warn "pg $fi @{[ %c ]}\n";
      push @lines, $c{pg}*100;
    } else {
      push @lines, 100;  # for round-trip-ish, default is 100/0 pg/vg
    }
  }

  # flavor 1-5 vg
  for my $fi (0..4) {
    if (exists $self->flavors->{$fi}) {
      my @x = @{ $self->flavors->{$fi} };
      my %c = ( vg => 0, splice @x, 2 );
#warn "vg $fi @{[ %c ]}\n";
      push @lines, $c{vg}*100;
    } else {
      push @lines, 0;
    }
  }

  push @lines, $self->misc->{drops};

  # flavor 1-5 zero pg/vg flag
  for my $fi (0..4) {
    if (exists $self->flavors->{$fi}) {
      my %c = ( unk => 0, splice @{ $self->flavors->{$fi} }, 2 );
      push @lines, $c{unk};
    } else {
      push @lines, 0;
    }
  }

  # flavor 5-6
  for my $fi (5,6) {
    if (exists $self->flavors->{$fi}) {
      my %c = ( pg => 0, vg => 0, unk => 0, splice @{ $self->flavors->{$fi} }, 2 );
      push @lines, $self->flavors->{$fi}->[1];
      push @lines, $self->flavors->{$fi}->[0];
      push @lines, $c{pg}*100;
      push @lines, $c{vg}*100;
      push @lines, $c{unk};
    } else {
      push @lines, 0;
      push @lines, '';
      push @lines, 100;
      push @lines, 0;
      push @lines, 0;
    }
  }

  push @lines, @{ $self->notes };

  return \@lines;
}

1;

main(@ARGV) unless caller;

sub main {

  my $filename = shift;
  my $dump_file = shift || 0;

  $filename && -f $filename
    || die "Usage: EJMUPARSER_VERBOSE=1 $0 original.rec [output.rec]\n";

  #use File::Basename;
  #my @lines = read_file($filename);
  #my $recipe_name = basename $filename, qw( .rec );
  #my $rec = App::JuiceCalc::EJMUParser->new(
  #  lines => \@lines,
  #  name => $recipe_name
  #)->sanitize;

  my $rec = App::JuiceCalc::EJMUParser->new_from_file(
    file => $filename,
    autoname => 1,
  )->sanitize;

  if ($ENV{EJMUPARSER_VERBOSE}) {
    require Data::Dump;
    Data::Dump::dd([
      name => $rec->name,
      version => $rec->version,
      notes => $rec->notes,
      target => $rec->target,
      flavors => $rec->flavors,
      misc => $rec->misc,
      unknown => $rec->unknown,
    ]);
  }

  if ($dump_file) {
    open my $fh, '>', $dump_file or die $!;
    print $fh $rec->as_string;
    close $fh;
  }

}

1;
