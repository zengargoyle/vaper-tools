#!/usr/bin/env perl
use strict;
use warnings;
use utf8::all;

use v5.10;

package App::JuiceCalc;
our $VERSION = '0.01';
use Moo;
with 'MooX::Singleton';
use File::ShareDir;
use File::HomeDir;
use File::Slurp;

has emitter => (
  is => 'rw',
  default => sub { 'Default::default_table' },
);

has batch_size => (
  is => 'rw',
  default => sub { 10 },
);

has mix_mg => (
  is => 'rw',
  default => sub { 18 },
);

sub _coerce_split_array { [ split /\s*,\s*/, $_[0] ] }
sub _coerce_split_hash { +{ split /\s*,\s*/, $_[0] } }

has mix_ratio => (
  is => 'rw',
  default => sub { 'vg,.3,pg,1' },
  coerce => \&_coerce_split_array,
);

has base => (
  is => 'rw',
  default => sub { '100,pg,1' },
);

has base_mg => (
  is => 'rw',
  default => sub { 100 },
);

has base_carrier => (
  is => 'rw',
  default => sub { 'pg,1' },
  coerce => \&_coerce_split_hash,
);

has flavor_carrier => (
  is => 'rw',
  default => sub { 'pg,1' },
  coerce => \&_coerce_split_hash,
);
use Carp;
use Try::Tiny;
use Safe::Isa;
sub set_from_file {
  my $self = shift;
  my $path = shift;

  my %conf;

  my $err = try {
    %conf = map { /^(\w+)[\s=]+(.*)$/ ? ($1 => $2) : () }
    grep { /\S/ } map { s/#.*//; s/;\s*//; s/\s*$//; $_ }  ## no critic
    read_file($path, binmode => ':encoding(UTF-8)');
    0;
  }
  catch {
    (my $e = $_) =~ s/ at.*//;
    $e;
  };
  croak $err if $err;

  for my $k (keys %conf) {
    $self->$k( $conf{$k} ) if $self->$_can( $k );
  }
}

use File::Spec;
sub BUILD {
  my $self = shift;
  my $share;
  try {  # ./lib/auto/App/JuiceCalc - doesn't count for Travis CI
    $share = File::ShareDir::dist_dir('App-JuiceCalc');
  };
  my $home = File::HomeDir->my_home;
  for my $dir ( ($share)x!!$share, $home, '.' ) {
    for my $file (qw( juicecalc.config .juicecalc.config )) {
      my $path = File::Spec->catfile( $dir, $file );
      if ( -r -f $path ) {
        $self->set_from_file( $path );
        last;
      }
    }
  }
  my @env_keys = grep /^(?:APP_)?JUICECALC_[A-Z][A-Z_]*$/, keys %ENV;
  for my $k ( @env_keys ) {
    (my $meth = $k) =~ s/^(?:APP_)?JUICECALC_(.*)$/$1/;
    $meth = lc $meth;
    $self->$meth( $ENV{ $k } ) if $self->$_can( $meth );
  }
}

1;

package UnitHash;
use Moo;

use List::AllUtils qw( sum );

has normal => (
  is => 'ro',
  default => sub { {} },
);

has scale => (
  is => 'ro',
  default => sub { undef },
);

sub get { my $self = shift;  @{ $self->normal }{ @_ } }
sub get_scaled { my ($self,$scale)=(shift,shift);  @{ $self->scaled($scale) }{ @_ } }

sub BUILDARGS {
  my ($class, %args) = @_;
  return { normal => { %args } } unless exists $args{normal};
  return { %args };
}

sub BUILD {
  my $self = shift;
  if (!defined $self->scale) {
    $self->{scale} = 1;
    $self->set;
  }
}

sub set {
  my $self = shift;
  my %new = @_;
  my $old = $self->scaled;
  @$old{keys %new} = values %new;
  $self->_set( $old );
  return $self;
}

sub _set {
  my $self = shift;
  my $old = shift;
  my $normal = $self->normal;
  %$normal = ();
  my $sum = 0;
  $sum += $old->{$_} for keys %$old;
  $old->{$_} /= $sum for keys %$old;
  $self->{scale} = $sum;
  @{$normal}{keys %$old} = values %$old;
  return $self;
}

sub del {
  my $self = shift;
  my @rem = @_;
  my $old = $self->scaled;
  delete @$old{$_} for @rem;
  $self->_set( $old );
  return $self;
}

sub scaled {
  my $self = shift;
  my $by = shift // 1;
  my $scale = $self->scale;
  my $normal = $self->normal;
  return {
    map { $_ => $normal->{$_} * $scale * $by } keys %{ $normal }
  };
}

package Flavor;
use Moo;
use Safe::Isa;
use App::JuiceCalc::Util qw( describe_ratio );

has name => (
  is => 'rwp',
  default => sub { "Unknown" },
);

has vendor => (
  is => 'ro',
  lazy => 1,
  builder => '_build_vendor',
);

sub _build_vendor {
  my $self = shift;
  my $name = $self->name;
  if ($name =~ s/\s+\(\s*(\w+)\s*\)\s*$//) {
    $self->_set_name( $name );
    return uc($1);
  }
  return "UNK";
}

sub ratio {
  my $self = shift;
  describe_ratio( $self->carrier->normal );
}

sub as_string {
  my $self = shift;
  my %param = ( with_ratio => 0, @_ );

  my $txt;
  $txt .= $self->name;
  $txt .= ' (' . $self->vendor . ')' if $self->vendor ne 'UNK';
  if ($param{with_ratio}) {
    my $ratio = $self->ratio;
    $txt .= ' ' . $ratio unless $ratio eq $self->name;
  }
  return $txt;
}

has carrier => (
  is => 'ro',
  #isa => 'UnitHash',
  default => sub { UnitHash->new( normal => App::JuiceCalc->instance->flavor_carrier ) },
  coerce => sub { $_[0]->$_isa('UnitHash') ? $_[0] : UnitHash->new( %{ $_[0] } ) },
);

sub BUILD {
  my $self = shift;
  $self->vendor;  # force (VND) removal asap
}

package Nicotine;
use Moo;
extends 'Flavor';

has 'name' => (
  is => 'ro',
  default => sub { 'Nicotine' },
);

has 'mg' => (
  is => 'ro',
  required => 1,
);

around as_string => sub {
  my $orig = shift;
  my $self = shift;
  my $txt = $orig->($self, @_);
  $txt = $self->mg . ' mg/ml ' . $txt;
};

sub BUILDARGS {
  my ($class, @args) = @_;
  unless (@args == 1) {
    return { @args };
  }
  my ($mg, %con) = split /,/, $args[0];
  return { mg => $mg, carrier => \%con };
}

package FlavorBundle;
use Moo;
use Params::Util qw( _ARRAY );
use Safe::Isa;

has _flavor_frac => (
  is => 'ro',
  default => sub { UnitHash->new },
);

has _flavor_real => (
  is => 'ro',
  default => sub {[]},
);

has name => (
  is => 'rw',
  default => sub { "Unknown Flavor" },
);

#use Data::Dump;
sub add_flavor {
  my $self = shift;
  my @args = @_;
  if (!_ARRAY($args[0])) {
    @args = [ @args ];
  }
  for my $flavor (@args) {
    my ($name,$frac,@con) = @$flavor;
    my $f;
    if ($name->$_isa('Flavor')) {
      $f = $name;
    }
    else {
      $f = Flavor->new( name => $name, (carrier => { @con })x!!@con );
    }
    push @{ $self->_flavor_real }, $f;
    $self->_flavor_frac->set( $#{ $self->_flavor_real }, $frac );
  }
  return $self
}

sub flavors_scaled {
  my $self = shift;
  my $scale = shift // 1;
  my $i = 0;
  [ map { [ $_, $self->_flavor_frac->scaled($scale)->{ $i++ } ] } @{ $self->_flavor_real } ];
}

sub flavors_normal {
  my $self = shift;
  my $i = 0;
  [ map { [ $_, $self->_flavor_frac->normal->{ $i++ } ] } @{ $self->_flavor_real } ];
}

sub BUILDARGS {
  my ($class, %args) = @_;
  my $flavors = delete $args{flavors};
  #dd [ args => \%args ];
  if ($flavors) {
    my $tmp = $class->new(%args);
    #dd [ tmp => $tmp ];
    $tmp->add_flavor(@$flavors) if $flavors;
    return { name => $tmp->name, _flavor_frac => $tmp->_flavor_frac, _flavor_real => $tmp->_flavor_real };
  }
  return {%args};
};

package Mix;
use Moo;
use Carp;

use App::JuiceCalc::Util qw( in_epsilon );
use Safe::Isa;

has flavor => (
  is => 'ro',
  required => 1,
);

has base => (
  is => 'rw',
  coerce => \&_coerce_base,
  default => sub {
    Nicotine->new( App::JuiceCalc->instance->base,
      #mg => App::JuiceCalc->instance->base_mg,
      #carrier => App::JuiceCalc->instance->base_carrier,
    ),
  },
);

sub _coerce_base {
  my $try = shift;
  return $try if $try->$_isa('Nicotine');
  return Nicotine->new( $try );
}

has mg => (
  is => 'rw',
  default => sub { App::JuiceCalc->instance->mix_mg },
);

has ratio => (
  is => 'rw',
  default => sub { App::JuiceCalc->instance->mix_ratio },
);

#use Data::Dump;
use List::AllUtils qw( sum min max natatime );
sub generate {
  my $self = shift;

  my %rem = ( pg => 0, vg => 0 );
  my ( @mix, @mix_flav, $mix_nic, @mix_fill );

  for my $fs ( @{ $self->flavor->flavors_scaled } ) {
    my ($f, $s) = @{ $fs };
    my %c = %{ $f->carrier->scaled($s) };
    $rem{$_} += $c{$_} for keys %c;

    #dd [ f => $f->vendor ];
    push @mix_flav, [ $f, $s ];
  }
  croak "Bad mix flavor\n" if sum( values %rem ) > 1;

  my $actual_mg;
  {
    last unless $self->mg;    # want 0 nic, add no nic base
    my $rem = 1 - sum( values %rem );
    my $nic = $self->base->mg;
    $actual_mg = $self->mg;
    my $s = $self->mg / $nic;
    my $add = min $s, $rem;
    if ( !in_epsilon( $add, $s ) ) {
      $actual_mg = $nic * $add;
      warn sprintf "Only reached %.2f mg (desired: %.2f).\n",
        $actual_mg, $self->mg;
    }
    my %parts = %{ $self->base->carrier->scaled($add) };
    $rem{$_} += $parts{$_} for keys %parts;

    $mix_nic = [ $self->base, $add ];
  }
  croak "bad mix nic" if sum( values %rem ) > 1;

  my %fill = (
    pg => Flavor->new( name => 'PG', carrier => { pg => 1 } ),
    vg => Flavor->new( name => 'VG', carrier => { vg => 1 } ),
    dw => Flavor->new( name => 'DW', carrier => { dw => 1 } ),
    pga => Flavor->new( name => 'PGA', carrier => { pga => 1 } ),
  );

  my $it = natatime 2, @{ $self->ratio };
  while ( my ( $c, $f ) = $it->() ) {
    my $rem = 1 - sum( values %rem );
    unless ( $rem > 0 ) { warn "No room for adjusting ratio\n"; last }
    my $curr_c = exists $rem{$c} ? $rem{$c} : 0;  # avoid adding a 0 ratio
    my $add = max( 0, min( $f - $curr_c, $rem ) );
    warn sprintf "Only reached %.2f (desired: %.2f) of $c.\n", $add, $f
      if ( $add + $curr_c ) != $f and $f != 1.0;  # don't warn on max fill

    #dd [ c => $c, f => $f, rem => \%rem, rem => $rem, add => $add ];
    # if vg > desired, skip and fill with pg
    next if $add == 0;

    $rem{$c} += $add;
    push @mix_fill, [ $fill{$c}, $add ];
  }

  #dd [ \%rem, sum => sum(values %rem) ];
  croak "bad mix total" if !in_epsilon( sum( values %rem ), 1 );

  #croak "bad mix total2" if sum(values %rem) < 1;

  @mix_flav = sort {
    $b->[1] <=> $a->[1] || $a->[0]->as_string(with_ratio =>1) cmp $b->[0]->as_string(with_ratio=>1)
    } @mix_flav;

  @mix_fill = sort {
    $b->[1] <=> $a->[1] || $a->[0]->name cmp $b->[0]->name
    } @mix_fill;

  @mix = ( @mix_fill, ($mix_nic) x !!$mix_nic, @mix_flav );

  #dd [ rem => \%rem, mix => \@mix ];
  return { mix => \@mix, ratio => \%rem, mg => $actual_mg };
}

package Batch;
use Moo;
use App::JuiceCalc::Util qw( describe_ratio );
#use Data::Dump qw( pp dd );
use Module::Load;

has mix => (
  is => 'ro',
  required => 1,
);

has size => (
  is => 'rw',
  default => sub { App::JuiceCalc->instance->batch_size },
);

has emitter => (
  is => 'rw',
  default => sub { App::JuiceCalc->instance->emitter },
);

has emitter_args => (
  is => 'rw',
  default => sub { {} },
);

sub generate {
  my $self = shift;
  my $mix  = $self->mix->generate;

  #dd [ mix => $mix ];
  my $scaled =
    [ map { my @r = @$_; $r[1] *= $self->size; \@r } @{ $mix->{mix} } ];
  my $tabled =
    [ map { my @r = @$_; $r[0] = $r[0]->as_string( with_ratio => 1 ); \@r }
      @{$scaled} ];
  my $title = sprintf "%s %.0f mg/ml (%s)", $self->mix->flavor->name,
    $mix->{mg} // 0, describe_ratio( $mix->{ratio} );

  #dd [ title => $title, mix => $scaled, emitter => $self->emitter ];

  my ( $emit_name, %emit_args ) = split /,/, $self->emitter;

  my $emit = $self->get_emitter($emit_name);
  $emit->(
    title => $title,
    table => $tabled,
    batch => $self,
    emitter_args => \%emit_args,
  );

}

sub get_emitter {
  my ($self, $em) = @_;
  my $ems;
  my $emsub;
  my $pkg;
  if ($em =~ s/(.+):://) {
    $pkg = $1;
    Module::Load::load("App::JuiceCalc::Emitter::$pkg");
    no strict 'refs'; ## no critic
    $ems = \%{"App::JuiceCalc::Emitter::$pkg\::emitters"};
    $emsub = \&{"App::JuiceCalc::Emitter::$pkg\::$em"};
  }
  else {
    die "Please use SubPackage::name to choose emitter, ".
      "use list_emitters() or the jcalc-list-emitters sub-command ".
      "to list available emitters";
  }
  $ems->{$em} or die "Unnown emitter '$em'".
    ($pkg ? " in package App::JuiceCalc::Emitter::$pkg" : "");
  $emsub or die "Emitter '$em' not found".
    ($pkg ? " in package App::JuiceCalc::Emitter::$pkg" : "");
  return $emsub;
}

sub list_emitters {
  require Module::List;

  my ($self, $detail) = @_;
  state $all_emitters;

  if (!$all_emitters) {
    my $mods = Module::List::list_modules(
      "App::JuiceCalc::Emitter::", { list_modules => 1 }
    );

    no strict 'refs'; ## no critic
    $all_emitters = {};
    for my $mod (sort keys %$mods) {
      Module::Load::load($mod);
      my $em = \%{"$mod\::emitters"};
      for (keys %$em) {
        my $cutmod = $mod;
        $cutmod =~ s/^App::JuiceCalc::Emitter:://;
        my $name = "$cutmod\::$_";
        $em->{$_}{name} = $name;
        $all_emitters->{$name} = $em->{$_};
      }
    }
  }

  if ($detail) { return $all_emitters }
  my @ret = sort keys %$all_emitters;
  return @ret;
}

1;
