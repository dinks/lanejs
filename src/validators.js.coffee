#= require dawanda/mixins/rate_limiter

# BaseValidator
#
# Validator with general options
# 'if' option runs in the context of the validated object

class BaseValidator extends Lib.Module

  # > Constructor
  constructor: ( attr, opts ) ->
    @options = {}
    # > Store all the options
    @options[ key ] = val for key, val of opts

  # > Generic call which checks for validity
  validate: ( obj ) ->
    # > If there is not condition involved, then execute the check WRT the object
    return @run( obj ) unless @options.if?
    # > validates 'a', if: 'b' where 'b' is a method in the object i.e custom validation method
    if typeof @options.if is "string"
      condition = obj[ @options.if ]
    else
      # > Inline function
      condition = @options.if
    # > If the condition satisfies, then execute the runner with the object
    @run( obj ) if condition.call( obj ) is true

  # > Implementation dependent
  run: ->
    throw "'run' method has to be implemented by BaseValidator subclasses"

# PresenceValidator
#
# Validates presence of an attribute. The error message can be configured using
# the 'message' option.
#
class PresenceValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    opts = {} if opts is true
    super attr, opts
    @attribute = attr
    @options.message ?= I18n.t("errors.messages.empty")

  run: ( obj ) ->
    # > Get the value
    value = obj.get( @attribute )
    # > If not present, then add the error
    unless value? and ( value + "" ).length > 0
      obj.addError @attribute, @options.message

# FormatValidator
#
# Validates format of an attribute, specified as a regular expression in the
# 'with' option. The error message can be configured using the 'message'
# option.
#
class FormatValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    super attr, opts
    @attribute = attr
    @options.message ?= I18n.t("errors.messages.invalid")

  run: ( obj ) ->
    # > Get the value
    value = obj.get @attribute
    # > `with` is the holder for the Regular Expression
    return unless value? and ( value + "" ).length > 0 and @options.with?
    obj.addError @attribute, @options.message unless @options.with.test value

# RangeValidator
#
# Validates the range of a number. Using 'min' and 'max' option. The error
# message can be configured using the 'message' option.
#
class RangeValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    super attr, opts
    @attribute = attr
    @options.message ?= I18n.t("errors.messages.not_in_range")

  run: ( obj ) ->
    # > Get the value
    value = obj.get @attribute
    # > `min` or `max` are required options else just return without any errors
    return unless value? and ( value + "" ).length > 0 and (@options.max? or @options.min?)
    if @options.min? and typeof @options.min is "function"
      @options.min = @options.min.call( obj )
    if @options.max? and typeof @options.max is "function"
      @options.max = @options.max.call( obj )
    # > Expects the value to be a Moment Object?
    # > `min` id **deprecated**
    if @options.min? and typeof @options.min is "object" and @options.min._isAMomentObject and !value.min(@options.min)
      obj.addError @attribute, @options.message
    # > Expects the value to be a Moment Object?
    # > `max` is **deprecated**
    else if @options.max? and typeof @options.max is "object" and @options.max._isAMomentObject and !value.max(@options.max)
      obj.addError @attribute, @options.message
    else if @options.min? and value < @options.min
      obj.addError @attribute, @options.message
    else if @options.max? and value > @options.max
      obj.addError @attribute, @options.message

# AcceptanceValidator
#
# Validates acceptance of an attribute. The acceptance value is '1' by default,
# and can be configured with the 'accept' option. The error message can be
# configured using the 'message' option.
#
class AcceptanceValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    super attr, opts
    @attribute = attr
    @options.message ?= I18n.t("errors.messages.accepted")
    @options.accept  ?= "1"

  run: ( obj ) ->
    # > Get the value and check if its the same. Good for "Accept Terms and Conditions"
    obj.addError @attribute, @options.message unless obj.get( @attribute ) is @options.accept

# LengthValidator
#
# Validates format of an attribute, specified as a regular expression in the
# 'with' option. The error message can be configured using the 'message'
# option.
#
class LengthValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    super attr, opts
    @attribute = attr
    @options.too_long ?= I18n.t("errors.messages.too_long.other")
    @options.too_short ?= I18n.t("errors.messages.too_short.other")
    @options.wrong_length ?= I18n.t("errors.messages.wrong_length.other")

  run: ( obj ) ->
    # > Smart way to only check for `.length`
    value = "#{obj.get @attribute}"
    # > This seems wrong, Length validation should Throw too_short in case of non existent value!
    return unless value?
    # > `max` check
    obj.addError @attribute, @options.too_long if @options.max? and value.length > @options.max
    # > `min` check
    obj.addError @attribute, @options.too_short if @options.min? and value.length < @options.min
    # > `is` check (Exact length)
    obj.addError @attribute, @options.wrong_length if @options.is? and value.length != @options.is

# ConfirmationValidator
#
# Validates confirmation of an attribute, checking that its value is equal to
# another attribute named the same, plus a '_confirmation' suffix.
#
class ConfirmationValidator extends BaseValidator

  constructor: ( attr, opts ) ->
    super attr, opts
    @attribute = attr
    @confirmed_attribute = @options.confirmed_attribute || @attribute + "_confirmation"
    @options.message ?= I18n.t("errors.messages.confirmed")

  run: ( obj ) ->
    value           = obj.get( @attribute )
    confirmed_value = obj.get( @confirmed_attribute )
    # > return if empty
    return unless value? and ( value + "" ).length > 0
    # > If both values are not the same, then error
    unless value is confirmed_value
      obj.addError @confirmed_attribute, @options.message

# > To extend this set, use the same namespace
namespace "Lib.Validators", ->
  # Export validators
  BaseValidator:         BaseValidator
  PresenceValidator:     PresenceValidator
  FormatValidator:       FormatValidator
  AcceptanceValidator:   AcceptanceValidator
  RangeValidator:        RangeValidator
  LengthValidator:       LengthValidator
  ConfirmationValidator: ConfirmationValidator
