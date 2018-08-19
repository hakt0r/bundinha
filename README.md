# BUNDINHA

BUNDINHA is an open-source backend and webapp bundler.
It's aim is to enable you to jump-start a self-contained
webapp within a few lines of code.

## Usage example

First begin a regular NodeJS project :) Yes, ATM you're forced to use CoffeeScript because I'm lazy and won't add complexity when it's not requested :P It should look roughly like this.

  - myApp/
    - package.json
    - index.js
      - *require("bundinha")*
    - src/
       - myApp.coffee : **entry Point**

The reason is the packaging process in which code and assets
are being bundled into the *build/* directory.

Your entry Point could look like this.

```CoffeeScript
require 'bundinha/auth_invite'
# this will give you basic SHA512 / challenge-response
# with seed, server and transaction salts
# the inviteKey can be configured in *config/inviteKey.txt*

shared = APP.global()
shared.SomeGlobal = true
# client/server wide global

tpl = APP.tpl()
tpl.hr = '<hr/>' # a client side template

client = APP.client()

client.init = ->
  # your client side init code

client.SomeFunction = (args)->
  # a client side function

#  █████  ██████  ██
# ██   ██ ██   ██ ██
# ███████ ██████  ██
# ██   ██ ██      ██
# ██   ██ ██      ██

APP.client( optional api-object ) returns api-object
  # Add client side functions
APP.config( fnConfigHandler )
  # Add config handler
APP.global
# Add global constant
APP.headers
# Add headers
APP.plugin
# Add plugin to a fucntion defined with APP.client
APP.postPrivate
# Add private (authenticated) post handler
APP.postPublic
# Add public post handler
APP.script
# Add javascript library to the client/webapp
APP.shared
# Add add shared function
APP.tpl
# Add client side template

```

## Copyrights

  * c) 2018 Sebastian Glaser <anx@hakt0r.de>

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
