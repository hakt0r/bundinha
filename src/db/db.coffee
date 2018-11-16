
@require 'bundinha/backend/backend'

@scope.db = (name,opts)->
  if 'string' is typeof name
    @dbScope[name] = opts || {}
  else for typeName, opts of name
    opts.typeName = typeName
    opts.file = opts.file || typeName
    opts.fields = opts.fields || $$[typeName].fields || {}
    @dbScope[opts.file] = opts

@server class Database
  @extend:(Spec)->
    Spec.verify     = Database.verify.bind Spec
    Spec::verify    = Database.verify.bind Spec
    Spec.createFrom = Database.createFrom.bind Spec
    Spec.get        = Database.get.bind Spec
    Spec::toJSON    = Database.toJSON = (req)-> @verify @record,req,'r'
    Spec::toString  = Database.toString = (req)-> JSON.stringify @toJSON req
    Spec

Database.verify = (data,req,access)->
  verified   = {}
  errors     = {}
  hadError   = false
  specFields = @fields
  hasGroups  = req.USER.group
  accessType = if access is 'r' then 0 else 1
  for fieldName, value of data
    throw new Error 'InvalidField: ' + fieldName unless opts = specFields[fieldName]
    accessGroups = opts.rw[accessType]
    testSpec     = opts.t
    testSpecKeys = Object.keys testSpec
    console.log fieldName.bold, value, accessGroups, hasGroups
    for testName in testSpecKeys
      try
        Database[testName].apply null, testSpec[testName].concat value
        if RequireGroupBare hasGroups, [accessGroups]
          verified[fieldName] = value
        else if access is 'w'
          DenyAuth ': cannot write to: ' + fieldName;
      catch e
        errors[fieldName] = errors[fieldName] || {}
        errors[fieldName][testName] = e
        hadError = true
  if hadError
    console.error 'access'.red.bold, req.ID, errors
    throw ( e = new Error 'VerificationError'; e.data = errors; e )
  verified

Database.String = (len,data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'TooLong'  if len < data.length

Database.StringTitle = (len,data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'TooLong'  if len < data.length
  throw new Error 'Maformed' unless data.match /^[a-z0-9-+_@.,\(\)\[\]]+$/i

Database.String.URL = (data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'Maformed' unless data.match /^https?:\/\/[^'"<>]+$/i

Database.StringCountryCode = (data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'TooLong'  if 3 <= data.length
  throw new Error 'Maformed' unless data.match /^[a-z]+$/i

Database.StringHTMLFormats = (data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO

Database.NumberTimeStamp = (data)->
  throw new Error 'NoNumber' if 'number' isnt typeof data
  throw new Error 'NoTimestamp' if 0 <= data < Number.MAX_SAFE_INTEGER

Database.Number = (min=-1,max=-1,places=0,data)->
  throw new Error 'NoNumber' if 'number' isnt typeof data
  throw new Error 'FractionOverflow' if places isnt -1 and data istn

Database.Array = (data)->
  throw new Error 'NoString' if 'string' isnt typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO
