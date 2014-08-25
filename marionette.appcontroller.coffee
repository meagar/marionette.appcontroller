# Marionette.AppController
#
# 0.0.1
#
# A simple controller (as in MVC) for Marionette Applications

# Methods on the controller that we never consider routable actions
blacklistActionNames = ['initialize', 'flash']

# Figure out if a method is an action, meant to be routed to
isAction = (name, fn) ->
  $.isFunction(fn) and
    name[0] != '_' and
    !Marionette.Controller.prototype[name]? and
    !Marionette.AppController.prototype[name]? and
    name not in blacklistActionNames


class Marionette.AppController extends Marionette.Controller

  constructor: ->
    @content ?= App?.content
    @router ?= App?.router

    # Controllers should no longer use constructor, they should use initialize
    @_setupActionProxies()

    # Has to happen *after* our proxies are setup
    super()

  beforeFilter: (fn, options = {}) ->
    actions = @_extractActionNames(options)

    for action in actions
      @_actions[action].before.push fn

  _setupActionProxies: ->
    @_actions = {}
    for action,fn of @ when isAction(action, fn)
      @_actions[action] = { fn: fn, before: [], after: [] }
      @[action] = $.proxy @_invokeAction, @, action

  # Pulls only/except action names from options passed to before/after filters
  _extractActionNames: (options) ->
    actions = Object.keys(@_actions)

    if options.only?
      only = if $.isArray(options.only) then options.only else [options.only]
      actions = (action for action in actions when action in only)

    if options.except?
      except = if $.isArray(options.except) then options.except else [options.except]
      actions = (action for action in actions when action not in except)

    actions

  # Proxy an action on a controller, invoking before filters first, and conditionally bailing
  # if any before filter renders or redirects
  _invokeAction: (name, args...) =>
    @_rendered = @_redirected = false

    # Used in render/redirect to delay acting until after before filters
    @_before = true

    # First, invoke before filters
    for fn in @_actions[name].before
      fn = if $.isFunction(fn) then fn else @["_#{fn}"]
      fn.call(@, name, args)

      if @_redirected || @_rendered
        break

    @_before = false

    if @_redirected || @_rendered
      # Something rendered or redirected, abort
      # We need to delay the actual action so that we have a chance to exit this method
      # before @redirect trigger's a fresh round of routing
      @redirect(@_redirected...) if @_redirected
      @render(@_rendered...) if @_rendered

      return
    else
      # Second, invoke action
      @_actions[name].fn.apply(@, args)

    # Lastly, invoke any after-filters
    # TODO - do we even need this client-side?

  # Render the given view, with the gien arguments, into the App.content region
  render: (view, args...) ->
    # Not currently doing much with this, but it allows us to bail-out in a before filter
    @_rendered = arguments
    $ => @content.show(new view(args...)) unless @_before

  # Update the URL (let the current _invokeAction finish) and then trigger routing
  redirect: (path, options = {}) ->
    @_redirected = arguments

    # Delay redirection if we're currently in before filters
    # Necessary because trigger: true will cause the new method to invoke immediately,
    # via _invokeAction, before we've exited the old _invokeAction's before filter loop
    return if @_before

    options.trigger ?= true

    if options.error?
      flash = { type: 'error', message: options.error }
      delete options.error

    if options.notice?
      flash = { type: 'notice', message: options.notice }
      delete options.notice

    @router.navigate(path, options)

    @flash?(flash) if flash

  # Change the URL, without pushing state or triggering routing
  fixupUrl: (path, options = {}) ->
    options.replace ?= true
    @router.navigate(path, options)

  _getQueryString: ->
    window.location.search

  # Source: https://developer.mozilla.org/en-US/docs/Web/API/Window.location
  # Modified slightly to distinguish between variables which are present but blank, and
  # variables which are absent from the query string entirely.
  #
  # Given a query string like this...
  # ?name=bob&age=
  #   _loadPageVar('name') -> bob - value found
  #   _loadPageVar('age') -> "" - key present, but no value
  #   _laodPageVar('blah') -> null - key not present
  _loadPageVar: (name) ->
    # Matches name=value in [0], and value in [1]
    regex = new RegExp("^(?:.*[&\\?]" + encodeURI(name).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i")
    match = @_getQueryString().match(regex)

    if match[1]?
      decodeURI(match[1])
    else
      null

  # Return an integer, or null
  tidyIntParam: (name) ->
    value = @_loadPageVar(name)
    if value?
      value | 0
    else
      null

  # Return a value from values, or null
  tidyEnumParam: (name, values, options = {}) ->
    search = @_loadPageVar(name)
    if search?
      searches = if options.multiple
        search.split(',')
      else
        [search]

      valid_enums = []
      for search in searches
        if options.caseInsensitive
          search = search.toLowerCase()
          valid_enums.push(value) for value in values when value.toLowerCase() == search
        else
          valid_enums.push(value) for value in values when value == search

      if valid_enums.length > 0
        return (if options.multiple then valid_enums else valid_enums[0])

      # Value wasn't found
      return options.default if options.default?

    null

