
use Module::Build;
my $build = Module::Build->new(
  module_name => 'App::JuiceCalc',
  license => 'perl',
  dist_abstract => 'Vaper Tools',
  dist_author => 'zengargoyle <zengargoyle@gmail.com>',
  requires => {
    'perl' => '5.10.1',
    'Exporter::Lite' => '0',
    'utf8::all' => '0',
    'Moo' => '0',
    'List::AllUtils' => '0',
    'Safe::Isa' => '0',
    'Params::Util' => '0',
    'Getopt::Long::Descriptive' => '0',
    'Text::ASCIITable' => '0',
    'JSON' => '0',
    'Module::Load' => '0',
    'Module::List' => '0',
    'Try::Tiny' => '0',
    'File::HomeDir' => '0',
    'File::ShareDir' => '0',
    'File::Slurp' => '0',
    'MooX::Singleton' => '0',
  },
  build_requires => {
    'Test::More' => '0',
    'Capture::Tiny' => '0',
  },
);
$build->create_build_script;
