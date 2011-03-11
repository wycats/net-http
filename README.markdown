This repo contains a number of experimental modifications to the version of Net::HTTP that ships with Ruby 1.9. TODOs:

* -Porting the code to work on Ruby 1.8-
* Add missing tests for features, including gzip
* Fixing gzip when using requests that a block as an iterator
* Adding support for getting the response as a stream, rather than having to read the entire body at once.
* Other features as I think of them
