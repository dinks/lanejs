#= require validators

## Namespace for Creation of new models
namespace "Lib.Model", ->

  # A Model is an abstraction over a business model, a data container with
  # logic. It provides:
  #
  #   - attribute setters and getters
  #   - validations
  #   - serialization as JSON
  #   - events
  #
  # It's expected that this class will be extended.
  #
  # It's a good idea to listen to changes in the model and trigger UI events
  # based on those changes.
  #
  # See LoudAccessors: https://github.com/lucaong/loud-accessors
  # See validators:    lib/assets/javascripts/validators.js.coffee
  #
  # Example:
  #
  #   class Product extends Lib.Model
  #     @attrAccessible 'title', 'description', 'price'
  #
  #     @validatesPresenceOf 'title'
  #     @validatesPresenceOf 'price'
  #
  #     formattedPrice: -> '$' + @get('price')
  #
  #   product = new Product(title: 'Dress', price: 21.99)
  #   product.on 'change:price', (event, attribute, value) ->
  #     alert("New price! #{value}")
  #
  # > Standard Model extends from Module which has extend and include similar to rails
  class Model extends Lib.Module

    # > For set and get methods for dynamic attributes. Use the prototype here
    @include LoudAccessors::

    # > Constructor
    constructor: ( attrs ) ->
      # > Dynamically add attributes, what is clean used for?
      @set name, value, { clean: true } for name, value of attrs
      # > EventSpitter is added by LoudAccessors, where to put the silent check?
      @emit "initialized", attrs

    # Class methods

    # > General method to add validations to array
    @addValidation: ( validation ) ->
      # > Initialize the array if it does not exist
      @::_validations ?= []
      # > Why?
      unless @::hasOwnProperty "_validations"
        # > Slice it to create a new object
        @::_validations = @::_validations[..]
      # > Push the new Validation Object
      @::_validations.push validation

    @validatesPresenceOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.PresenceValidator, attr, opts

    @validatesFormatOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.FormatValidator, attr, opts

    @validatesRangeOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.RangeValidator, attr, opts

    @validatesAcceptanceOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.AcceptanceValidator, attr, opts

    @validatesServerSideOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.ServerSideValidator, attr, opts

    @validatesConfirmationOf: ( attr, opts ) ->
      # > Call the generic validatesWith
      @validatesWith Lib.Validators.ConfirmationValidator, attr, opts

    # > Add a set of validations to an attribute
    @validates: ( attr, validations ) ->
      # > @validates format: { with: /abcd/ }, presence: true
      for type, opts of validations
        # > Format this correctly
        capitalized = type.charAt(0).toUpperCase() + type[1..]
        # > Call the correct method
        @["validates#{capitalized}Of"] attr, opts

    # > Add Custom Validator?
    @validatesWith: ( Validator, args... ) ->
      # > Create the new Validator with the set of args
      @addValidation new Validator args...

    @attrAccessible: ( attrs... ) ->
      # > Create the array if does not exist
      @::_attr_accessible ?= []
      # > Why?
      unless @::hasOwnProperty "_attr_accessible"
        # > Create a new Object
        @::_attr_accessible = @::_attr_accessible[..]
      for attr in attrs
        # > Push the attribute into the array
        @::_attr_accessible.push attr if attr not in @::_attr_accessible

    # Instance methods

    # > Validate the attributes returning a promise
    validate: ( opts ) ->
      @errors   = {}
      results   = []
      silent    = opts? and opts.silent
      dfd       = new $.Deferred
      @emit "validate" unless silent

      # > The result of the validation is either a number (the push into the errors array) or undefined
      # > In the case of a Custom validator, say EmailTakenValidator, it requires an ajax request to check
      # > This means that the return value will be a promise and `when` makes sure that the promise in complete
      # > before calling `done`
      for validation in @_validations || []
        results.push validation.validate(@)

      # > if it is not a Deferred will be done immediately
      $.when.apply($, results).done () =>
        unless silent
          valid = true
          # > After the call, @errors array gets filled with the validation errors
          for attr, errors of @errors
            @emit "invalid:#{attr}", errors
            valid = false
          @emit if valid then "valid" else "invalid"
        # > Why no `reject` if invalid?
        dfd.resolve()

      dfd.promise()

    # Should only be used when there is no
    # asynchronous validation
    # > Isnt it better to have only the validate method?
    isValid: ( opts ) ->
      @validate opts
      for error of @errors
        return false
      true

    # > Why? Isnt a validator enough? Is this to default?
    isBlank: (attribute_names...) ->
      if attribute_names.length > 0
        attributes = {}
        for k, v of @_attributes when k in attribute_names
          attributes[k] = v
      else
        attributes = @_attributes

      # > But if any of the attributes is empty, then it returns false. :|
      for k, v of attributes
        return false if v? and v isnt ''

      true

    # > Adds error message for the attribute to the errors hash
    addError: ( name, message ) ->
      # > Initialize if not exists
      @errors ?= {}
      # > A list of errors in case of multiple validations
      @errors[ name ] ?= []
      # > Add the message
      @errors[ name ].push message

    addErrorToBase: ( message ) ->
      # > Special case, but why?
      @addError "_base_", message

    # > Convert to JSON, but why not attrAccessible?
    toJSON: ->
      to_json = {}
      for key, value of @_attributes
        value = value.toJSON() if value?.toJSON?
        to_json[ key ] = value
      to_json

    reset: ( attribute ) ->
      # > Reset dirty
      @untouch attribute
      # Set to null
      @set attribute, null

    # > To make Dirty?
    touch: ( attribute ) ->
      @touched ?= {}
      @touched[attribute] = true
      @emit "touched:#{attribute}", attribute

    # > To remove Dirty?
    untouch: ( attribute ) ->
      @touched ?= {}
      @touched[attribute] = false
      @emit "untouched:#{attribute}", attribute

    # > Is Dirty?
    isTouched: ( attribute ) ->
      @touched ?= {}
      !!@touched[attribute]
