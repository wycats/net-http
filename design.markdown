Net::HTTP, as shipped with the Ruby standard library, is a robust,
battle-tested HTTP library. As it stands today (Ruby 1.9.2), it already
contains a number of very important, non-trivial features:

* Support for keepalive and proper handling of sockets that
  inadvertantly close when keepalive is expected
* Support for Transfer-Encoding: Chunked
* Support for streaming request bodies
* Support for gzip and deflate on GET request
* Support for threaded operation
* Proper handling of sockets: the normal Net::HTTP APIs make it
  extremely unlikely that a user of the API will leak sockets
* Support for streaming multipart/form-data request
* Support for application/x-www-form-urlencoded
* Support for SSL and SSPI
* Support for proxies
* Support for Basic Auth

In general, the API is more reasonable than most people think. Most
obviously, the block-based API that is the normal way of using Net::HTTP
ensures that resources are properly closed, while still allowing
multiple Keepalive'd requests on the same connection:

    # open a socket to the host and port passed in
    Net::HTTP.start(host, port) do |http|
      http.get(path) do |chunk| # use the socket held by the Net::HTTP instance
        # do something with chunks
      end # guarantees that the socket position is after the response body

      http.get(path) do |chunk| # use the same socket via keepalive
                                # note that if the server sent Connection: close
                                # or the socket inadvertantly got disconnected,
                                # Net::HTTP will reopen the socket for you
      end
    end
    # close the socket automatically via +ensure+

The API is roughly analogous to the File API, which provides a block API
in order to allow Ruby to automatically manage resources for you. It's
also why the API takes a host and port, rather than a full path (sockets
are opened to a particular host and port).

Net::HTTP also provides a convenience method (analogous to File.read) if
you just want to make a quick GET request a la curl:

    body = Net::HTTP.get(host, path, port)

    # if you want a response object:

    response = Net::HTTP.get_response(host, path, port)

Unfortunately, Net::HTTP does not support `Net::HTTP.get(string_url)`,
but that is easily remedied, and was one of the first things I did in
Net2::HTTP. I have a pending patch to Net::HTTP proper.

Additionally, if you use Net::HTTP without the block form, you get an
instance of Net::HTTP with a live socket that will stay open until you
manually close it. This allows you to distribute keepalive'd requests
across several methods, and not need to worry about manually checking
whether the socket stayed open. On the other hand, you will need to
manually close the socket once you're done with it.

This is the reason for the two APIs (block and no-block). Just like File
provides a `&block` version of File.open to handle resource cleanup for you
and a no-block version for when you want to manually manage the
resource, Net::HTTP provides APIs for each side of that same tradeoff.

# Deficiencies

With all of that said, there are a few deficiencies of Net::HTTP. Fixing
them would make it even better. In most cases, these deficiencies would
not be addressed by switching to another HTTP library, because they are
issues with features not fully supported in most other Ruby HTTP
clients.

In some cases, these issues could be readily addressed with a small
patch to Net::HTTP. In others, the patch would be larger or more
involved. When appropriate, I will submit small incremental patches back
to Ruby, and will also periodically submit the entire Net2::HTTP project
as a patch back against master. As you will see, some of the more
involved changes may be challenging for ruby-core to accept, and I
wanted to demonstrate their viability and make them available even if
they could not make it into the core.

## Problem 1: Ruby 1.8 Support

By definition, Net::HTTP is a library that is pinned to the version of
Ruby it ships with. As a result, API improvements that do not rely on
new Ruby features still do not make it into Ruby 1.8.

The way to solve this problem is the same way that normal Rubygems do;
ship a single version of the library that can support both Ruby 1.8 and
Ruby 1.9. In the case of Net::HTTP, that means shimming
encoding-specific changes and dealing with cases where Ruby 1.9 has much
better support for non-blocking IO.

That said, many of the changes between 1.8 and 1.9 are entangled with
code that uses new Ruby 1.9 syntax features (like the new `{foo: bar}`
Hash syntax), so reverting those changes is most of the necessary work.

**Status:** Net2::HTTP is a modified version of Ruby 1.9.2's Net::HTTP,
and passes all tests on Ruby 1.8.

**Patch Potential:** A patch like this would conflict with the way that
Ruby core handles the standard library in general. That said, Rubygems,
to some degree, has this property, so it's worth asking.

## Problem 2: GZip Support is Limited

Support for gzip in Net::HTTP was added between 1.8 and 1.9, and was
tacked on in one specific place. Instead of making Net::HTTP's response
object understand gzip, the code overrides `Net::HTTP#get` to modify the
request with the proper Accept-Encoding, then runs the request through
the stack and unzips the contents.

This has several problems:

1. It only works with `Net::HTTP#get`. Using `Net::HTTP#request`
   directly, passing `get` as a parameter will bypass this logic.
2. Since it's not part of the Response object, the code cannot support
   the block form (`http.get(path) { |chunk| ... }`). Net::HTTP
   internally creates an object called a `ReadAdapter`, which duck-types
   like `String` well enough to receive `<<`es and yield them to the
   block. It cannot, however, serve as an IO for `GzipReader`.
3. Since the user doesn't necessarily know that gzip is being used (the
   whole idea is that it's transparent and will "just work" when
   available), this means that using a perfectly normal Net::HTTP API
   will break when the server sends the data back in gzip format.

In solving this problem, ideally you would want to be able to use the
block form of `#get` and still receive chunks of ungzipped data as they
become available.

Making `Net::HTTP::Response` aware of compression solves both problems:
it makes all methods transparently compression-aware (because it would be
encapsulated in `Response`) and it would allow the block form of `get`
to work (because it would be wired tightly into the mechanics of `Response`
and not to the mechanics of the `#get` public API method).

Unfortunately, when I started working on wiring it into `Response`, I
ran into a bit of a sticky problem. Because of the semantics of chunked
encoding, it is not possible to simply pass the socket to `GzipReader`
to unzip the contents. The version that comes with Ruby 1.9 gets around
this problem by simply waiting for the entire body to be processed and
then performs a switcheroo from the `get` method. Unfortunately, it has
the problems outlined above.

What I needed was a version of `GzipReader` that behaved more like
`Zlib::Inflate`, which takes chunks as they become available and returns
the decompressed content for the chunk. It's almost possible to just use
`Zlib::Inflate`, except that gzip has a complex header that must be
stripped before inflating the chunks. Thankfully, the Rubinius
implementation of GzipReader implements the header parsing logic in
pure-Ruby, so I was able to extract it and implement an object with the
`Zlib::Inflate` API that knew how to handle headers.

Since `deflate` is also supported, having a gzip parser with the same
API as `Zlib::Inflate` also simplified the implementation in the
`Response` object.

**Status:** Done. Net2::HTTP includes gzip and deflate logic directly in
the `Response` object, so any response that indicates that it is
compressed will be properly decompressed. Additionally, since it's wired
into the mechanism that handles block arguments to the public-facing
API, consumers of the API will receive decompressed chunks as they
become available.

**Patch Potential**: It would probably be possible to implement this as
a standalone patch. It requires a new implementation of some gzip logic,
and it also causes a divergence in some of the other work I am doing. It
will be difficult to truly decompose all of the work in the area of
streaming responses so that ruby-core can pick and choose from them at
will. I will try.

## Problem 3: Forced Waiting on the Body

(Incidentally, this problem is what caused me to start working on
Net::HTTP in the first place).

In order to guarantee that the socket is always cleaned up, and that
keepalive'd connections can make new requests, the current Net::HTTP
always reads in the entire body before it returns. This means that it is
not possible to make a long-running request and move on until you
actually need the body, or pass along the response to another part of
the program that will handle it.

It is possible to work around this problem using threads, and this is
what we did at Strobe when we encountered this issue. Instead of making
the request in the current thread, spawn a thread to make the request
and have it communicate the body back on a Queue or other structure.
Howeer, requiring a thread is not an ideal solution.

Additionally, I plan to add support to Net::HTTP for non-blocking reads
(see below for a longer description of this problem), which is
incompatible with forcibly blocking on reading the entire request.

Unfortunately, there are some very good reasons for always reading the
entire body. The best reason is that it allows Net::HTTP to guarantee
that your program doesn't leak sockets. In my view, this problem is
handled extremely well by the `File` API, which uses a block form to
guarantee manual socket cleanup, and a non-block form to give you more
control but require you to clean up resources yourself.

Net::HTTP already provides the necessary APIs, but it still tries to
save you the cleanup cost by zealously reading in the body when it can.

My solution is to modify Net::HTTP to leave the socket open and unread
unless you use the block form:

    # don't use the block form so the connection will not be auto-closed
    http = Net::HTTP.new(host, port).start

    # don't use the block form so that the body will not be eagerly
    # read, and the socket will stay open
    response = http.get(path)

    something_else(response)

There are two caveats:

1. This is definitely a semantic change with existing Net::HTTP. I think
   it's a very reasonable one, but existing programs that don't use the
   block form would now rely on the garbage collector to close the
   socket.
2. A second connection on a keepalive'd socket needs to read the body of
   the previous connection in order to be able to reuse the socket. This
   isn't a major problem, but it's a logical limitation.

**Status:** Net2::HTTP has these semantics. I have not yet added a
non-blocking read API, but this change makes it possible to conceptually
add one.

**Patch Potential:** This is a significant semantic change that is also
a bit invasive. It would both be difficult to make it a standalone patch
and unlikely to be accepted. I will discuss it with ruby-core before
attmpting to extract a patch.

## Problem 4: Nonblocking Reads

The current design of Net::HTTP is a blocking design. You make a request
and it blocks until the full body has returned. Even with my solution to
problem 3 above, retrieving the body is a one-shot blocking operation.
This makes it difficult to wire up multiple Net::HTTP request to a select
loop or other non-blocking strategy for handling multiple concurrent
requests.

Of course, blocking operations can run concurrently in a transparent way
when using threads, so most of the time you can get decent concurrent
performance out of Net::HTTP. That said, Ruby 1.9 in general has moved
toward a more consistent non-blocking API for IO operations, and it
would be great if Net::HTTP was a part of that.

The biggest challenge is dealing with chunked encoding. With a normal
HTTP response, it is possible to essentially proxy a non-blocking read
to the underlying socket, limited to the size of the Content-Length.

In contrast, chunked encoding responses contain a number of chunks, each
of which starts with a line containing the number of bytes in the
chunks, followed by a `\r\n`. This means that parsing a chunked response
in a non-blocking way involves doing your own buffering and state
management.

The upside of this is that all kinds of responses, including responses
that use both chunked encoding and gzip, would have a single non-blocking
API for pulling decoded bytes off the stream.

This solution builds on the previous solutions that I have already
implemented, as it requires gzip support in the Response itself, as well
as not always blocking on reading the full response body.

**Status:** Next in the queue. All the groundwork is done.

**Patch Potential:** Assuming the previous patches were accepted, this
patch would be a pretty straight-forward one. That said, it will be
very difficult, if not impossible, to make this patch a standalone
patch, since it requires features introduced by earlier solutions.

## Problem 5: Project Structure

This problem is perhaps the thorniest. In the current version of Ruby,
Net::HTTP is a single 2,779 line file. When I first started working on
it, I planned to leave it structured this way so that it would be easy
to maintain my changes as patches to the original source.

Unfortunately, it was extremely difficult to work with code structured
this way, and I quickly succumbed to restructuring it into a number of
smaller files. I also didn't hold back as much as I could have in terms
of cleaning up stylistic issues, but those changes are rather minimal
(things like not using empty parens for method calls with no args and
using do/end rather than curlies for multiline blocks).

In general, I believe that these changes are the most innocuous of the
overall changes, and should pose a problem to be integrated, but large,
mostly-stylistic patches typically run up against resistance in open
source projects.

I should be clear that I don't think that these patches are particularly
important on a standalone basis, but (1) they made it significantly
easier for me to work on other improvements, and (2) accepting them
would make it a lot easier for me to submit the rest of my changes as
patches without needing to rewrite them against master.

**Status:** The most obvious changes are done, but I will probably
continue to restructure things and I get deeper into different parts of
the code.

**Patch Potential:** Ironically, this has the least potential to cause
problems and will probably be a very hard patch to get accepted. Like
the Ruby 1.8 support, the existence of these changes make extracting
other patches more difficult, but in both cases the patches improve the
code quality.

## Problem 6: Documentation

This problem is both related to overall documentation and documentation
of specific semantics. For instance, the specific behavior of sockets
and keepalive when using the various APIs is reasonably well ordered but
not very well described.

**Status:** I have been adding a lot of inline documentation to clarify
things, especially where I have made changes. I plan to spend some time
on overall documentation once I'm a bit further on.

**Patch Potential:** It would be possible for me to port the patches
that specifically apply to parts of the code back to trunk. The
improvements to overall code structure (see above) have done more for
making it easier to understand the code than trying to add documentation
for poorly structured code.

# Patches in General

I plan to maintain Net2::HTTP as a library, as well as try to port as
many of the changes as possible to patches. For the reasons I described,
many of the patches would be contingent on other patches, and as I go
deeper, more of the patches will rely on earlier work.

I am extremely interested in feedback about the work I'm doing, as my
ultimate goal is to propose that some of the more ambitious changes get
accepted.
