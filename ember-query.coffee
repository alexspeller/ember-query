Em.QueryLocation = Em.HistoryLocation.extend
  initState: ->
    location = @get('location')
    state = location.pathname + location.search
    @set('history', window.history)
    @replaceState state

  queryString: (url) ->
    url.split("?")[1] or ""

  queryHash: ->
    url = @newURL || @get('location.search')
    $.deparam @queryString(url)

  willChangeURL: (url) ->
    @set 'fullURL', url
    @newURL = url

  alreadyHasParams: (params) ->
    @toQueryString(@queryHash()) is @toQueryString(params)

  toQueryString: (params) ->
    $.param(params)
      .replace(/%5B/g, "[")
      .replace(/%5D/g, "]")
      .replace(/%2C/g, ",")

  getURL: ->
    @_super() + window.location.search

  setURL: (url) ->
    @_super(url)
    @set 'fullURL', url
    @newURL = undefined

  replaceURL: (url) ->
    @_super(url)
    @set 'fullURL', url
    @newURL = undefined

  replaceQueryParams: (params) ->
    @doUpdateQueryParams params, @replaceURL.bind(@)

  setQueryParams: (params) ->
    @doUpdateQueryParams params, @setURL.bind(@)

  doUpdateQueryParams: (params, callback) ->
    newPath = @get('location.pathname')
    query = @toQueryString(params)

    newPath += "?#{query}" unless Em.isEmpty(query)
    callback newPath

Em.Location.registerImplementation('query', Em.QueryLocation)

Em.ControllerMixin.reopen
  transitionParams: (newParams) ->
    @get('target').transitionParams(newParams)

  transitionToRouteWithParams: (args...) ->
    @get('target').transitionToRouteWithParams args...

  transitionAllParams: (args...) ->
    @get('target').transitionAllParams args...

  replaceQueryParams: (args...) ->
    @get('target').replaceQueryParams args...

  currentParams: ->
    @container.lookup('router:main').paramsFromRoutes()

  init: (args...) ->
    @_super(args...)

    if @observeParams?
      for param in @observeParams
        @addObserver param, =>
          Em.run.once =>
            @container.lookup('router:main').serializeParams()

Em.Router.reopen
  # Hijacking updateUrl is used because redefining
  # doTransition is not possible as it's a function in
  # a closure and not available to any accessible
  # object. This in fact applies to all of the overrides in
  # the startRouting method below, which just exist to
  # override some functions after they have been defined
  init: (args...) ->
    Ember.assert("You are using a version of ember that is too old for ember-query to work with.", @_setupRouter)
    @_super(args...)

  hijackUpdateUrlParams: null
  _setupRouter: (router, location) ->
    @_super(router, location)

    defaultUpdateURL = router.updateURL
    @router.updateURL = (url) =>
      if @hijackUpdateUrlParams?
        qs = @location.toQueryString(@hijackUpdateUrlParams)
        url += "?#{qs}" unless Em.isEmpty qs
        @hijackUpdateUrlParams = null

      defaultUpdateURL url
      @location.willChangeURL url

    defaultHandleURL = @router.handleURL
    @router.handleURL = (url) =>
      @location.willChangeURL url

      defaultHandleURL.call(@router, url).then =>
        @router.currentHandlerInfos.forEach (handlerInfo) =>
          handlerInfo.handler.deserializeParams(@queryParams())

    defaultRecognize = @router.recognizer.recognize
    @router.recognizer.recognize = (path) =>
      if /\?/.test path
        path = path.split("?")[0]
      defaultRecognize.call @router.recognizer, path


  fullURLBinding: 'location.fullURL'

  didTransition: (infos) ->
    @_super(infos)
    Em.run.next =>
      @replaceQueryParams @paramsFromRoutes()
      @notifyPropertyChange('url')

  currentRoute: ->
    @router.currentHandlerInfos.get('lastObject').handler

  queryParams: ->
    @get('location').queryHash()


  # Merge passed params into current params
  transitionParams: (newParams) ->
    params = @location.queryHash()

    for own key, value of newParams
      if value?
        params[key] = value
      else
        delete params[key]

    @transitionAllParams params

  # replace all current params with passed params
  transitionAllParams: (params) ->
    return if @router.isLoading
    return if @location.alreadyHasParams params

    @location.setQueryParams params

    if @get('namespace').LOG_TRANSITIONS
      Em.Logger.log 'Transitioned query params', params

    # call deserialize for all routes in current tree
    @router.currentHandlerInfos.forEach (info) =>
      info.handler.deserializeParams params, info.handler.defaultController()

    # call setupController for bottom route
    controller = @currentRoute().defaultController()
    model = @currentRoute().currentModel
    @currentRoute().setupController controller, model, params
    @notifyPropertyChange 'url'

  # update the current query params without adding
  # a state to the history
  replaceQueryParams: (params) ->
    @location.replaceQueryParams params

  transitionToRouteWithParams: (args...) ->
    name = args[0]
    unless @router.hasRoute(name)
      name = args[0] = args[0] + '.index'

    @hijackUpdateUrlParams = args.pop()
    @replaceQueryParams @hijackUpdateUrlParams

    Ember.assert "The route #{name} was not found",
      @router.hasRoute(name)

    @router.transitionTo args...

  isLoaded: ->
    @router.currentHandlerInfos?

  serializeParams: ->
    return unless @isLoaded()
    @transitionAllParams @paramsFromRoutes()

  queryStringFromRoutes: ->
    @get('location').toQueryString @paramsFromRoutes()

  paramsFromRoutes: ->
    params = {}
    @router.currentHandlerInfos.forEach (info) ->
      handler = info.handler
      newParams = handler.serializeParams handler.defaultController()
      Em.merge params, newParams
    params


Em.Route.reopen
  deserializeParams: Em.K
  serializeParams: -> {}

  queryParams: ->
    @get('router').queryParams()

  transitionParams: (newParams) ->
    @get('router').transitionParams(newParams)

  transitionToRouteWithParams: (args...) ->
    @get('router').transitionToRouteWithParams args...

  replaceQueryParams: (params) ->
    @get('router').replaceQueryParams params

  defaultController: -> @controllerFor @routeName

  setup: (context) ->
    controllerName = @controllerName or @routeName
    controller = @controllerFor(controllerName, true)
    controller = @generateController(controllerName, context)  unless controller

    # Assign the route's controller so that it can more easily be
    # referenced in event handlers
    @controller = controller
    if @setupControllers
      Ember.deprecate "Ember.Route.setupControllers is deprecated. Please use Ember.Route.setupController(controller, model) instead."
      @setupControllers controller, context, @queryParams()
    else
      @setupController controller, context, @queryParams()

    @deserializeParams @queryParams(), controller

    if @renderTemplates
      Ember.deprecate "Ember.Route.renderTemplates is deprecated. Please use Ember.Route.renderTemplate(controller, model) instead."
      @renderTemplates context
    else
      @renderTemplate controller, context

Em.LinkView.reopen
  _invoke: (event) ->
    return @_super(event) unless @get('query')?
    return true unless Em.ViewUtils.isSimpleClick(event)

    event.preventDefault()
    event.stopPropagation() if @bubbles is false

    return false if @get('_isDisabled')

    if @get "loading"
      Ember.Logger.warn "This linkTo is in an inactive loading state because at least one of its parameters' presently has a null/undefined value, or the provided route name is invalid."
      return false

    router      = @get "router"
    routeArgs   = @get "routeArgs"

    if @get("replace")
      throw "replace not implemented with query params"
    else
      params = $.deparam @get('query')
      route  = @get 'namedRoute'
      router.transitionToRouteWithParams routeArgs.concat(params)...

  href: (->
    return @_super() unless @get('query')?
    router = @get('router')
    routeArgs = @get('routeArgs')
    path = if routeArgs?
      router.generate.apply(router, routeArgs)
    else
      get(this, 'loadingHref');
    "#{path}?#{@get('query')}"
  ).property()
