
sources =
  sha512: "https://cdnjs.cloudflare.com/ajax/libs/js-sha512/0.7.1/sha512.js"
  sha1:   "https://cdnjs.cloudflare.com/ajax/libs/js-sha1/0.6.0/sha1.js"
  nacl:   "https://raw.githubusercontent.com/dchest/tweetnacl-js/master/nacl-fast.min.js"

@phase 'build:pre',0,=> unless @HasForge
  @script nacl:[[nacl]]
  @script sha1:[[sha1]]
  @script sha512:[[sha512]]
