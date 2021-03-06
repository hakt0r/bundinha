# BUNDINHA

BUNDINHA is an open-source backend and webapp (PWA) bundler.
It's aim is to enable you to jump-start a self-contained
webapp within a few lines of code.

Yes, ATM you're forced to use CoffeeScript because I'm lazy and won't add
complexity when it's not requested :P

Please note that I had to make some funky language level compromises in order
to keep things as clean and simple (as possible)

### Quickstart

```ShellScript
  $ sudo npm i -g git+https://github.com/hakt0r/bundinha
  $ export MY_BUNDLE=myfancyapp
  $ mkdir ${MY_BUNDLE}
  $ cd    ${MY_BUNDLE}
  $ bundinha -init
  $ ls
```
Your source files willl be in src/, your entry point would be:

```ShellScript
  $ ${EDITOR} src/${MY_BUNDLE}.coffee
```

After writing a bit of skeleton code you can build your program:

```ShellScript
  $ bundinha
  $ ls build/
```

For testing purposes install the generated package:

```ShellScript
  $ cd build/; sudo npm -g i .; cd ..
```

If you used the unpriv backend (recommended) setup your installation:

```ShellScript
  $ sudo ${MY_BUNDLE}-backend install PORT=1234 DOMAIN=test CERT=ssl.cer KEY=ssl.key
```

This will setup a systemd service for the current user, and install the nginx configuration.

### Example entry point

This works for @client, @server or @shared API's

```CoffeeScript

# You would add more sources like this:
#   They are not included using node's require
#   Instead their @ will be your current Bundinha
#   -> @ stays the same on @require

@require 'bundinha/fontawesome'             # use the fontawesome module
@require 'bundinha/auth/invite'             # use the auth/invite module
@require 'bundinha/backend/unpriv'          # use the backend/unpriv module
@require 'MY_BUNDLE/my_other_source.coffee' # use your own extra source

# create global client / server API's like this
@server.SomeFunction = -> console.log "I'm server"
@client.SomeFunction = -> console.log "I'm client"

# Hooks are special functions
@server.init = ->
  SomeFunction()
  return

# classes are supported too
@client class AbstractApp
  andsoforth:->  console.log 'works'

@client class MyApp extends AbstractApp
  constructor:-> @andsoforth()

MyApp.staticMember = -> console.log 'works'
MyApp::member = -> console.log 'works'

MyApp::andsoforth = ->
  console.log 'works but in order to call super, you must do this:'
  AbstractApp::andsoforth.call @, 'arg1', 'arg2', '...'

# define a private backend api
@private 'some.function', (query, req, res)->
  # must be an object
  res.json result:'works'
  # fail by just throwing an error
  throw new Error 'ooops'

# call api from the client side
# -> add an init-hook on the frontend
@client.init ->
  result = await CALL 'some.function', some:true, args:[1,2,3]
  console.log 'some.function returned', result
  return # note the blank return (see below)

```

### A word about hooks

Hooks on an API are special, they will be unwrapped of the function you define,
and concatenated. Therefore:

  - hook functions **must** end with a blank return
  - hook functions **must not** have other return's

## Module-API
```CoffeeScript
@global ( object ofFunctions )
  # Add global constant

@shared ( object ofDeclarations )
  # Add add shared variable (global): can be a Function, Class or Constant

@plugin ( string moduleName, object ofFunctions )
  # Add plugins to a function defined with @client / @server / @shared
```

### Frontend

```CoffeeScript
@client ( optional object ofDeclarations ) return object ofDeclarations
# Add add frontend variable (global): can be a Function, Class or Constant

@script ( string path )
  #  path: source i.e. '/path/to/script.js'
  #             or URL 'https://cdn.for/script.js'
  #             of BARE JAVASCRIPT
  # Add javascript library to the client/webapp

@css ( string path )
#  path: source i.e. '/path/to/style.css'
#             or URL 'https://cdn.for/style.css'
#             of BARE CSS
# Add css to the client/webapp

@tpl ( optional boolean isglobal, object ofTemplates )
  # Add client side template
```

#### miqro
```CoffeeScript
$ query           # := document.querySelector(query)
$.all query       # := document.querySelectorAll(query)
$.map query       # := document.querySelectorAll(query).map
SmoothEvents spec # add on/off/emit/kill event-wrapper to spec
```

#### call a backend function
```CoffeeScript
CALL ( object ofJsonQueries )
yield  object ofJsonQueries
return promise
```

#### force AJAX query if you enabled WebSockets
```CoffeeScript
AJAX ( object ofJsonQueries )
yield  object ofJsonQueries
return promise
```

### Backend

```CoffeeScript
@server ( optional object ofDeclarations ) return object ofDeclarations
# Add add backend variable (global): can be a Function, Class or Constant

@config ( object ofDeclarations )
  # Add config handler

@get ( string path, optional array groups, function callback )
  # Add GET-handler

@private ( string path, optional array groups, function callback )
  # Add private (authenticated) API-handler

@public ( string path, function callback )
  # Add public API-handler
```

### Modules

The following modules should help you build and shape your project.

```CoffeeScript
bundinha/frontend          # minimal frontend, implies:
bundinha/miqro             #   - some jQuery-like shortcuts
bundinha/notification      #   - notification manager
bundinha/button            #   - navbar / button system
bundinha/editor            #   - minimal editor widgets
bundinha/service           # service worker (pwa)
bundinha/fontawesome       # fontawesome support
bundinha/googlefonts       # googlefonts support
bundinha/keyboard          # keyboard manager
bundinha/license           # license compilation
bundinha/qrcode            # qrcode generator (experimental)
bundinha/scanner           # qrcode scanner (experimental)
bundinha/crypto/light      # lightweight crypto: SHA1, SHA512, nacl
bundinha/db/db             # implied by one of the following db backends
bundinha/db/level          #   - leveldb backing
bundinha/auth/auth         # implied by one of the following auth backends
bundinha/auth/invite       #   - invite-key based auth
bundinha/auth/ssh          #   - ssh authentication (experimental)
bundinha/backend/unpriv    # recommended (nginx/sytemd --user)
bundinha/backend/systemd   # systemd     (deprecated)
bundinha/backend/acme      # ACME ssl certs
bundinha/backend/binary    # system binary deps (atm deb only)
bundinha/backend/nginx     # nginx autoconfig
bundinha/backend/web       # static & ajax api
bundinha/backend/websocket # websocket api
```

## Copyrights

   - **bundinha** c) 2018-2019 Sebastian Glaser <anx@hktr.de>
   - derived from **htx**: c) 2013 Sebastian Glaser <anx@hktr.de>

## GPL compiler exemption

   Although BUNDINHA is distributed under GNU GPLv3,
   the *resulting code* from included core-libs, (unless superseded by a package license)
   is exempt from  then GPL and instead licensed under a MIT 3-Clause license.

   The reasoning is: according to the FSF JavaScript (and other source languages)
   may trigger a clause where GPL-code runs in the same process as potential closed
   code, because scripting languages usually don't link - but concatenate the code.

   This would require you to license your code under the GPL as well, thus the exemption.

   So you **can** commercially publish the code BUNDINHA generates,
   but you **must** still share patches to the source tree.

## Licensed under GNU GPLv3

BUNDINHA is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

BUNDINHA is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this software; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
Boston, MA 02111-1307 USA

http://www.gnu.org/licenses/gpl.html

## Compiled fragments licensed under MIT

BUNDINHA will generate code fragments (aside from your own),
as this would force you to adapt GPLv3 for you code,
instead these fragments will be licensed under MIT 3-Clause License,
in order to give you back full freedom over your own code.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.

  3. Neither the name of the copyright holder nor the names of its contributors
     may be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Contributed libraries carry their own license

The licenses of depended-upon packages apply respectively.
In order to get a full list BUNDINHA provides tools (using npm:legally)
to verify the licenses of all bundled Packages.
