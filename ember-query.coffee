Em.QueryLocation = Em.HistoryLocation.extend
  initState: ->
    location = @get('location')
    state = location.pathname + location.search
    @replaceState state
    @set('history', window.history)

  queryString: (url) ->
    url.split("?")[1] or ""

  queryHash: ->
    url = @newURL || @get('location.search')
    $.deparam @queryString(url)

  willChangeURL: (url) ->
    @newURL = url

  alreadyHasParams: (params) ->
    @toQueryString(@queryHash()) is @toQueryString(params)

  toQueryString: (params) ->
    $.param(params)
      .replace(/%5B/g, "[")
      .replace(/%5D/g, "]")

  setURL: (url) ->
    @_super(url)
    @newURL = undefined

  replaceURL: (url) ->
    @_super(url)
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
  hijackUpdateUrlParams: null
  startRouting: ->
    @_super()

    defaultUpdateURL = @router.updateURL
    @router.updateURL = (url) =>
      if @hijackUpdateUrlParams?
        qs = @location.toQueryString(@hijackUpdateUrlParams)
        url += "?#{qs}" unless Em.isEmpty qs
        @hijackUpdateUrlParams = null

      defaultUpdateURL url
      @location.willChangeURL url

  didTransition: (infos) ->
    @_super(infos)
    return if infos.someProperty('handler.redirected')
    Em.run.next =>
      @replaceQueryParams @paramsFromRoutes()

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

    Ember.assert "The route #{name} was not found",
      @router.hasRoute(name)

    @router.transitionTo(args...)
    @notifyPropertyChange 'url'

  isLoaded: ->
    @router.currentHandlerInfos?

  serializeParams: ->
    return unless @isLoaded()
    @transitionAllParams @paramsFromRoutes()

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
    @redirected = true if @_checkingRedirect
    @get('router').transitionParams(newParams)

  transitionToRouteWithParams: (args...) ->
    @redirected = true if @_checkingRedirect
    @get('router').transitionToRouteWithParams args...

  replaceQueryParams: (params) ->
    @redirected = true if @_checkingRedirect
    @get('router').replaceQueryParams params

  defaultController: -> @controllerFor @routeName

  deserialize: (params) ->
    paramsWithQuery = {}
    Em.merge paramsWithQuery, @queryParams()
    Em.merge paramsWithQuery, params
    model = @model paramsWithQuery
    @deserializeParams @queryParams(), @defaultController()
    @currentModel = model

  setup: (context) ->
    @redirected = false
    @_checkingRedirect = true
    @redirect context
    @_checkingRedirect = false
    return false  if @redirected
    controller = @controllerFor(@routeName, context)
    if controller
      @controller = controller
      controller.set "model", context
    if @setupControllers
      Ember.deprecate "Ember.Route.setupControllers is deprecated. Please use Ember.Route.setupController(controller, model) instead."
      @setupControllers controller, context, @queryParams()
    else
      @setupController controller, context, @queryParams()
    if @renderTemplates
      Ember.deprecate "Ember.Route.renderTemplates is deprecated. Please use Ember.Route.renderTemplate(controller, model) instead."
      @renderTemplates context
    else
      @renderTemplate controller, context

