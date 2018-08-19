#!/usr/bin/node
/*
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
*/

const fs = require('fs');
const path = require('path');

// bundinha will run from source as long as the src/ directory exists
if ( fs.existsSync( sourceFile = path.join(__dirname,'src','auth_invite.coffee'))){
  require('coffeescript/register'); }
// else it will use the bundle version
else sourceFile = path.join(__dirname,'build','auth_invite.js');

module.exports = require(sourceFile);
