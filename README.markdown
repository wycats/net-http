This repo contains a number of experimental modifications to the version of Net::HTTP that ships with Ruby 1.9. TODOs:

* <del>Porting the code to work on Ruby 1.8</del>
* <del>Fixed gzip in GET requests when using a block as iterator</del>
* <del>Support for gzip and deflate responses from any request</del>
* <del>Support for incremental gzip and deflate with chunked encoding</del>
* <del>Support for leaving the socket open when making a request, so
  it's possible to make requests that do not block on the body being
  returned</del>
* <del>Cleaned up tests so that it's possible to combine tests for
  features, instead of using brittle checks for specific classes</del>
* <del>Support for Net::HTTP.get(path), instead of needing to pass a
  URI or deconstruct the URL yourself</del>
* <del>In keepalive situations, make sure to read any remaining body from the
  socket before initiating a new connection.</del>
* Support for partial reads from the response
* Clean up the semantics of when #body can be called after a request.
  Specifically, if a block form is used, decide whether to buffer the
  outputted String and make it available as #body or to leave it up
  to the consumer to store a String if they want one. Either way,
  fomalize and document the semantics.
* The body method should never return an Adapter. It should either
  return a String or nil (if well-defined semantics justify a nil)
* Support for `read_nonblock ` to BufferedIO. This simply proxies to the
  underlying `read_nonblock` and make it easy to support HTTP-level
  `read_nonblock`
* Support for `read_nonblock` on Net2::HTTP::Response
* Other features as I think of them
