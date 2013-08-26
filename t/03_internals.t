use strict;
use warnings;

use Test::More;

use App::JuiceCalc;

subtest unithash => sub {
my $h = UnitHash->new;
$h->set( pg => 1, vg => 1 );
is_deeply $h->normal, { pg => .5, vg => .5 }, 'auto scaled';
is $h->scale, 2, 'with scale';
$h->set( alc => 1 );
is_deeply $h->normal, { pg => 1/3, vg => 1/3, alc => 1/3 }, 'auto scaled';
is $h->scale, 3, 'with scale';
is_deeply $h->scaled, { pg => 1, vg => 1, alc => 1 }, 'scaled back out';
is_deeply $h->scaled(4), { pg => 4, vg => 4, alc => 4 }, 'scaled back out and more';
is $h->get('pg'), 1/3, 'get scalar';
is_deeply [ $h->get('pg','vg') ], [ 1/3, 1/3 ], 'get list';
is_deeply [ $h->get_scaled( 1, 'pg','vg') ], [ 1, 1 ], 'get list';
is_deeply [ $h->get_scaled( 3, 'pg','vg') ], [ 3, 3 ], 'get list';
};

subtest unithashnew => sub {
my $h = UnitHash->new( pg => 1, vg => 1 );
is_deeply $h->normal, { pg => .5, vg => .5 }, 'auto scaled';
is $h->scale, 2, 'with scale';
$h->set( alc => 1 );
is_deeply $h->normal, { pg => 1/3, vg => 1/3, alc => 1/3 }, 'auto scaled';
};

subtest unithashcomplex => sub {
my $h = UnitHash->new( normal => { pg => 1/3, vg => 1/3, alc => 1/3 }, scale => 3 );
is_deeply $h->scaled, { pg => 1, vg => 1, alc => 1 }, 'scaled back out';
$h->del('alc');
is_deeply $h->scaled, { pg => 1, vg => 1 }, 'deleted';
is $h->scale, 2, 'scale is 2';
is_deeply $h->normal, { pg => 1/2, vg => 1/2 }, 'and normal';
};

subtest flavor => sub {
my $f = Flavor->new( name => 'Absinthe', vendor => 'TFA', carrier => { pg => 1, vg => 1 } );
is $f->carrier->normal->{pg}, .5, 'woot';
$f = Flavor->new( name => 'Absinthe', vendor => 'TFA', carrier => UnitHash->new(pg => 1, vg => 1, alc => 1 ) );
is $f->carrier->normal->{pg}, 1/3, 'woot direct';
};

subtest nicotine => sub {
{
my $n = Nicotine->new('100,pg,1');
isa_ok $n, 'Nicotine', 'got nic from string';
is $n->mg, 100, 'with 100 mg/ml';
is $n->carrier->normal->{pg}, 1, 'all pg';
}
{
my $n = Nicotine->new(mg => 100, carrier => {pg=>1,vg=>1});
isa_ok $n, 'Nicotine', 'got nic from args';
is $n->mg, 100, 'with 100 mg/ml';
is_deeply $n->carrier->normal, { pg => .5, vg => .5 }, '50/50';
}

};

subtest flavorbundle => sub {
my $fb = FlavorBundle->new(flavors => [ [ 'Absinthe', .1, vg => 1], [ 'Kiwi', .05 ] ]);
is_deeply $fb->_flavor_frac->normal, { 0 => 2/3, 1 => 1/3 }, 'woot fb';
my ($r,$f) = @{ $fb->flavors_scaled->[0] };
is $r->name, 'Absinthe', 'first flavor';
is $f, .1, 'first scaled fractional';
is_deeply [ map { [ $_->[0]->name, $_->[1] ] } @{$fb->flavors_normal} ],
  [ [ 'Absinthe', 2/3 ], [ 'Kiwi', 1/3 ] ], 'normals';
is_deeply [ map { [ $_->[0]->name, $_->[1] ] } @{$fb->flavors_scaled(10)} ],
  [ [ 'Absinthe', 1 ], [ 'Kiwi', .5 ] ], 'normals';
};

subtest mix => sub {
  plan skip_all => 'this test does nothing';
my $fb = FlavorBundle->new(flavors => [[ 'Absinthe', .1, vg => 1], [ 'Kiwi', .05 ]]);
my $mix = Mix->new( flavor => $fb );
$mix->generate;
pass;
};

subtest batch => sub {
  plan skip_all => 'this test does nothing';
my $fb = FlavorBundle->new(flavors=>[[ 'Absinthe', .1, vg => 1], [ 'Kiwi', .05 ]]);
my $mix = Mix->new( flavor => $fb );
my $batch = Batch->new(mix => $mix, size => 10);
$batch->generate;
pass;
};

subtest fuzzycustard => sub {
  plan skip_all => 'this test does nothing';
    my $fb = FlavorBundle->new(
        name    => 'Fuzzy Custard',
        flavors => [
            [ 'Vanilla Custard (TFA)', .13 ],
            [ 'Juicy Peach (TFA)',     .03 ],
            [ 'Butterscotch (TFA)',    .01 ]
        ]
    );
    my $nic = Nicotine->new(
        carrier => UnitHash->new(
            normal => { pg => .5, vg => .5, mg => 100 },
            scale  => 1
        )
    );
    my $mix = Mix->new( flavor => $fb, mg => 13, base => $nic );
    my $batch = Batch->new( mix => $mix, size => 32 );
    $batch->generate;
    pass;
};
pass;
done_testing;
