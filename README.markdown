This repo contains a number of experimental modifications to the version of Net::HTTP that ships with Ruby 1.9. TODOs:

* <del>Porting the code to work on Ruby 1.8</del>
* <del>Fix gzip in GET requests when using a block as iterator</del>
* <del>Add support for gzip and deflate responses from any request</del>
* <del>Add support for incremental gzip and deflate with chunked
  encoding</del>
* <del>Add support for leaving the socket open when making a request, so
  it's possible to make requests that do not block on the body being
  returned</del>
* <del>Clean up tests so that it's possible to combine tests for
  features, instead of using brittle checks for specific classes</del>
* <del>Add support for Net::HTTP.get(path), instead of needing to pass a
  URI or deconstruct the URL yourself</del>
* <del>In keepalive situations, make sure to read any remaining body from the
  socket before initiating a new connection.</del>
* Add support for partial reads from the response
* Document and clean up the semantics of when #body can be called after
  a request
* The body method should never return an Adapter. It should either
  return a String or nil (if well-defined semantics justify a nil)
* Other features as I think of them
