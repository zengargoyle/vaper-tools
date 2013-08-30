requires 'Exporter::Lite';
requires 'File::HomeDir';
requires 'File::ShareDir';
requires 'File::Slurp';
requires 'Getopt::Long::Descriptive';
requires 'JSON';
requires 'List::AllUtils';
requires 'Module::List';
requires 'Module::Load';
requires 'Moo';
requires 'MooX::Singleton';
requires 'Params::Util';
requires 'Safe::Isa';
requires 'Text::ASCIITable';
requires 'Try::Tiny';
requires 'perl', 'v5.10.1';
requires 'utf8::all';
requires 'Number::Format';

on build => sub {
    requires 'Capture::Tiny';
    requires 'Test::More';
};
