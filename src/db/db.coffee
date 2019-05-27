
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
    if ( not opts = specFields[fieldName] ) and ( access is 'w' )
      throw new Error 'InvalidField: ' + fieldName
    continue unless opts
    accessGroups = [opts.rw[accessType]]
    testSpec     = opts.t
    testSpecKeys = Object.keys testSpec
    # console.log fieldName.bold, value, accessGroups, hasGroups
    for testName in testSpecKeys
      try
        value = Database[testName].apply null, testSpec[testName].concat value
        if RequireGroupBare hasGroups, accessGroups
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
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  data

Database.Title = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  throw new Error 'Maformed' unless data.match /^[a-z0-9-+ _@.,\(\)\[\]]+$/i
  data

Database.URL = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'Maformed' unless data.match /^https?:\/\/[^'"<>]+$/i
  data

Database.CountryCode = (data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if 3 <= data.length
  throw new Error 'Maformed' unless data.match /^[a-z]+$/i
  data

Database.HTMLFormats = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO
  data

Database.TimeStamp = (data)->
  data = parseFloat data
  throw new Error 'Required' unless data?
  throw new Error "NoNumber: #{data}(#{t})" if 'number' isnt t =  typeof data
  throw new Error 'NoTimestamp' unless 0 <= data <= Number.MAX_SAFE_INTEGER
  data

Database.Number = (min=-1,max=-1,places=0,data)->
  data = parseFloat data
  throw new Error 'Required' unless data?
  throw new Error "NoNumber: #{data}(#{t})" if 'number' isnt t =  typeof data
  throw new Error 'FractionOverflow' if places is 0 and data.toString().split('.')[1]?
  data

Database.Array = (len,types,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO
  data
