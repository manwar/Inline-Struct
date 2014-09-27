use strict;
use warnings;
use Test::More;

use Inline;
eval { Inline->bind(C => <<'END', structs => 1, force_build => 1, clean_after_build => 0) };
struct Foo {
   int src;
   int dst;
};
END

is $@, '', 'compiled without error';

done_testing;
