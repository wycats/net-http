This repo is an attempt to update the Net::HTTP code from Ruby 1.9 to
work in both Ruby 1.8 and 1.9.

It will also fix several issues with Net::HTTP and add tests for things
like gzip, where features exist but are not tested. In some cases,
adding testing exposes bugs that can be fixed.
