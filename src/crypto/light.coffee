
return if @crypto is 'heavy'

@crypto = 'light'

@phase 'build:filter',0,=>
  @npm 'tweetnacl'
  @npm 'sha1'
  @npm 'sha512'

@phase 'build:pre',0,=>
  @script nacl:[[nacl]]
  @script sha1:[[sha1]]
  @script sha512:[[sha512]]
