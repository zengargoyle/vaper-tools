use strict;
use warnings;
use v5.10;

package App::JuiceCalc::Emitter::Default;
use Moo;

use Text::ASCIITable;
use List::AllUtils qw(firstidx);
use JSON;


our %emitters = (
  default_table => {
    summary => 'A simple ASCII graphics table (Default for terminals)',
    description => <<'_',

Looks something like:
.-----------------------------------------------.
|      Fuzzy Custard 13 mg/ml (70/30 PG/VG)     |
+--------------------------------+------+-------+
| Flavor                         |   ml | Total |
+--------------------------------+------+-------+
| PG                             | 4.65 |  4.65 |
+--------------------------------+------+-------+
| VG                             | 2.35 |  7.00 |
+--------------------------------+------+-------+
| 100 mg/ml Nicotine 50/50 PG/VG | 1.30 |  8.30 |
+--------------------------------+------+-------+
| Vanilla Custard (TFA) PG       | 1.30 |  9.60 |
+--------------------------------+------+-------+
| Juicy Peach (TFA) PG           | 0.30 |  9.90 |
+--------------------------------+------+-------+
| Butterscotch (TFA) PG          | 0.10 | 10.00 |
'--------------------------------+------+-------'

_

  },
  default_oneline => {
    summary => 'A simpe one line output suitable for e.g.: chat',
    description => <<'_',

Looks something like:
Fuzzy Custard 13 mg/ml (70/30 PG/VG) | Flavor(ml) Total | PG(4.65) 4.65 | VG(2.35) 7.00 | 100 mg/ml Nicotine 50/50 PG/VG(1.30) 8.30 | Vanilla Custard (TFA) PG(1.30) 9.60 | Juicy Peach (TFA) PG(0.30) 9.90 | Butterscotch (TFA) PG(0.10) 10.00

_

  },
  default_simple_json => {
    summary => 'A simple JSON dump',
    description => <<'_',

Looks something like:

_

  },
  default_complex_json => {
    summary => 'A simple JSON dump',
    description => <<'_',

Looks something like:

_

  },
  default_ejmu => {
    summary => 'Dump in "eJuice Me Up" (EJMU) .rec format',
    description => <<'_',

Looks something like:

_

  },
  default_unit => {
    summary => 'Dump back out as a App::JuiceCalc recipe',
    description => <<'_',

This dumps the batch as a sequence of lines that can be used to recreate
the batch.  That is... it does *nothing*.  This is mostly useful for
converting wildly different input to a standard format.

Looks something like:

name 'Unknown Flavor';
flav 'Licorice (LA)' => 0.14, pg => 1.00;
flav 'Wintergreen (LA)' => 0.03, pg => 1.00;
flav 'Sweet Cream (TFA)' => 0.02, pg => 1.00;
flav 'Sweetener' => 0.01, pg => 1.00;
nic 12.00, 36.00, pg => 1.00;
fill vg => 0.30, pg => 1.00;
size 1.00;

_

  },
);

use Number::Format qw( :subs );
sub default_unit {
  my %args = @_;
  my $batch = delete $args{batch} // die "no batch\n";
  my $mix = $batch->mix;
  my $fl = $batch->mix->flavor;
  printf qq{name '%s';\n}, $fl->name;
  for my $f ( @{ $fl->flavors_scaled } ) {
    my %n = %{ $f->[0]->carrier->normal };
    printf qq{flav '%s' => %0.2f, %s;\n},
      $f->[0]->as_string(with_ratio=>0),
      $f->[1],
      join(', ', map { sprintf "$_ => %s", round($n{$_},2) } sort keys %n);
  }
  {
    my %n = %{ $mix->base->carrier->normal };
    printf qq{nic %s, %s, %s;\n},
      round($mix->mg,2), round($mix->base->mg,2),
      join(', ', map { sprintf "$_ => %s", round($n{$_},2) } sort keys %n);
  }
  {
    use List::AllUtils qw( natatime );
    my $it = natatime 2, @{ $mix->ratio };
    my @n;
    while (my ($k, $v) = $it->()) {
      push @n, sprintf "$k => %s", round($v,2);
    }
    printf qq{fill %s;\n}, join ', ', @n;
  }
  printf qq{size %s;\n}, round($batch->size,2);

}

sub default_ejmu {
  my %args = @_;
  my $title = delete $args{title} // '';
  my $table = delete $args{table} // die "no table\n";
  my $batch = delete $args{batch} // die "no batch\n";

  require App::JuiceCalc::EJMUParser;
  my %flav;
  for (my $fi = 0; $fi < 7; $fi++) {
    my $bmf = $batch->mix->flavor;
    my $fr = $bmf->_flavor_real->[$fi];
    if (!$fr) {
      $flav{"$fi"} = [ "Flavor ".($fi+1), 0, pg => 1, vg => 0, unk => 0 ];
      next;
    }
    my $name = $fr->as_string;
    my $pc = $bmf->_flavor_frac->scaled->{ $fi };
    my %r = %{ $fr->carrier->normal };
    my %rr;
    if (exists $r{pg}) {
      %rr = ( pg => $r{pg}, vg => (1 - $r{pg}), unk => 0 );
    }
    elsif (exists $r{vg}) {
      %rr = ( vg => $r{vg}, pg => (1 - $r{vg}), unk => 0 );
    }
    else {
      %rr = ( vg => 0, pg => 0, unk => 1 );
    }
    $flav{"$fi"} = [ $fr->name . (($fr->vendor eq 'UNK') ? '' : ' (' . $fr->vendor . ')'), $pc, %rr ];
  }
    #use Data::Dump; dd [ flav => \%flav ];
  my %ratio;
  {
    my %r = @{ $batch->mix->ratio };
    my $vg = $r{vg};
    %ratio = ( vg => $vg, pg => (1 - $vg) );
  }
  sub to_pc { int(($_[0]*100)+.5) }  ## no critic
  my $ejmu = App::JuiceCalc::EJMUParser->new(
    lines => [],
    misc => {
      base => {
        mg => $batch->mix->base->mg,
        map({
          $_ => to_pc($batch->mix->base->carrier->normal->{$_})
        } qw( pg vg )),
      },
      amount => $batch->size,
      drops => 20,
    },
    notes => [ $batch->mix->flavor->name ],
    # XXX
    unknown => [ 1, 0 ],
    target => {
      mg => $batch->mix->mg,
      %ratio,
    },
    flavors => {
      # XXX
      %flav,
      other => [ 'unused', 0 ],
    },
  );
  print $ejmu->as_string;
}


sub default_complex_json {
  my %args = @_;
  #my $title = delete $args{title} // '';
  #my $table = delete $args{table} // die "no table\n";
  my ($title,$table,$raw,$extra) = @_;
  my $json = JSON->new;
  my $i = { meta => $extra, flavors => [] };
  for my $fi (0 .. @$raw-1) {
    my $f = $raw->[$fi];
    push @{ $i->{flavors} }, {
      name => $f->[0]->name,
      vendor => $f->[0]->vendor,
      makeup => $f->[0]->carrier->scaled,
      volume => $f->[1],
    };
  }
  my $fix = firstidx { $_->{name} =~ /Nicotine/i } @{ $i->{flavors} };
  if (defined $fix) {
    my $mg = delete $i->{flavors}[$fix]{makeup}{mg};
    $i->{flavors}[$fix]{name} = "$mg mg/ml " . $i->{flavors}[$fix]{name};
  }
  print $json->pretty->encode( $i );
}

sub default_simple_json {
  my %args = @_;
  my $title = delete $args{title} // '';
  my $table = delete $args{table} // die "no table\n";
  my $json = JSON->new;
  my $i = { title => $title, flavors => [] };
  for my $f (@$table) {
    push @{ $i->{flavors} }, { name => $f->[0], volume => $f->[1] };
  }
  print $json->pretty->encode( $i );
}

sub default_table {
  my %args = @_;
  my $title = delete $args{title} // '';
  my $table = delete $args{table} // die "no table\n";
  my $tb = Text::ASCIITable->new({
      headingText => $title,
      drawRowLine => 1,
  });
  $tb->setCols("Flavor", "ml", "Total");
  $tb->alignColName('ml', 'right');
  $tb->alignColName('Total', 'right');
  my $t = 0;
  for my $f (@$table) {
    my @f = @$f;
    $t += $f[1];
    $tb->addRow($f[0], map sprintf("%0.2f", $_), $f[1], $t);
  }
  print $tb;
}

sub default_oneline {
  my %args = @_;
  my $title = delete $args{title} // '';
  my $table = delete $args{table} // die "no table\n";
  my $t = 0;
  printf "$title | Flavor(ml) Total ";
  for my $f (@$table) {
    my @f = @$f;
    $t += $f[1];
    printf "| %s(%0.2f) %04.2f ", $f[0], $f[1], $t;
  }
  print "\n";
}

1;
__END__
=pod

=encoding utf-8

=head1 NAME

App::JuiceCalc::Emitter::Default - Default emitters (output formatters)

=head1 VERSION

version 0.01

=head1 DESCRIPTION

=head1 INCLUDED EMITTERS

=over

=item * default_table (Default)

A simple ASCII table.

=item * default_oneline

A simple single line format suitable for things like pasting into
IRC chats or similar places where formatting is likely to be lost.

=back

=cut
