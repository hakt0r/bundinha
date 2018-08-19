#!/usr/bin/node
/*
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
*/

const fs = require('fs');
const path = require('path');
const coffee = require('coffeescript/register');

const sourceFile = path.join(__dirname,'src','server.coffee');
const releaseFile = path.join(__dirname,'build','server.js');
const bundinha = require( fs.existsSync(sourceFile) ? sourceFile : releaseFile);
